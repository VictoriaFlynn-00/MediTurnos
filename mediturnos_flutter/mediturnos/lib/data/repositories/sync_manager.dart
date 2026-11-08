import 'dart:async';
import '../../core/connectivity_service.dart';
import '../../core/errors.dart';
import '../../core/fechas.dart';
import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/turno.dart';
import '../datasources/local_db.dart';
import '../datasources/remote_data_source.dart';

/// Administra la cola de operaciones pendientes (solicitar/cancelar turno
/// hechas sin conexión) y las reenvía al servidor al recuperar conectividad.
/// - Reintentos con backoff exponencial ante fallas de red.
/// - Conflicto de doble reserva: si el horario ya fue tomado, el turno local
///   pasa a "rechazado" y se informa al paciente.
class SyncManager {
  SyncManager(this._local, this._remote, this._conn) {
    _sub = _conn.onChange.listen((online) {
      if (online) procesarCola();
    });
  }

  final LocalDb _local;
  final RemoteDataSource _remote;
  final ConnectivityService _conn;
  final _ctrl = StreamController<List<SyncResultado>>.broadcast();
  StreamSubscription<bool>? _sub;
  bool _corriendo = false;

  Stream<List<SyncResultado>> get resultados => _ctrl.stream;

  Future<List<SyncResultado>> procesarCola() async {
    if (_corriendo || !_conn.online) return const [];
    _corriendo = true;
    final out = <SyncResultado>[];
    try {
      for (final item in await _local.cola()) {
        try {
          if (item.tipo == 'solicitar') {
            out.add(await _enviarSolicitud(item));
          } else if (item.tipo == 'cancelar') {
            await _conReintentos(
                () => _remote.cancelarTurno(item.payload['remoteId'] as int));
          }
          await _local.borrarCola(item.id);
        } on SinConexionException {
          break; // quedan en cola hasta la próxima conexión
        } on AppException {
          await _local.sumarIntento(item.id);
        }
      }
    } finally {
      _corriendo = false;
    }
    if (out.isNotEmpty) _ctrl.add(out);
    return out;
  }

  Future<SyncResultado> _enviarSolicitud(ColaItem item) async {
    final pl = item.payload;
    final localId = item.localId!;
    final fecha = pl['fecha'] as String;
    final hora = pl['hora'] as String;
    try {
      final remoteId = await _conReintentos(() => _remote.solicitarTurno(
            especialistaId: pl['especialistaId'] as int,
            fecha: fecha,
            hora: hora,
            paciente: Paciente.fromJson(Map<String, dynamic>.from(pl['paciente'] as Map)),
          ));
      await _local.actualizarEstado(localId, EstadoTurno.activo, remoteId: remoteId);
      return SyncResultado(
          turnoId: localId,
          exito: true,
          mensaje: 'Turno confirmado: ${Fechas.larga(Fechas.parse(fecha), hora)}');
    } on SinConexionException {
      rethrow;
    } on AppException catch (e) {
      await _local.actualizarEstado(localId, EstadoTurno.rechazado);
      final msg = e is HorarioNoDisponibleException
          ? 'El horario del $fecha a las $hora ya no está disponible, elegí otro'
          : e.mensaje;
      return SyncResultado(turnoId: localId, exito: false, mensaje: msg);
    }
  }

  Future<T> _conReintentos<T>(Future<T> Function() op, {int max = 3}) async {
    for (var i = 0;; i++) {
      try {
        return await op();
      } on SinConexionException {
        if (i >= max - 1 || !_conn.online) rethrow;
        await Future.delayed(Duration(seconds: 1 << i)); // 1s, 2s, 4s...
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _ctrl.close();
  }
}
