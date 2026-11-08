import 'dart:async';
import 'dart:convert';
import '../../core/connectivity_service.dart';
import '../../core/errors.dart';
import '../../core/fechas.dart';
import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/turno.dart';
import '../../domain/repositories/turno_repository.dart';
import '../datasources/local_db.dart';
import '../datasources/remote_data_source.dart';
import 'sync_manager.dart';

/// Único componente que decide si un dato sale de SQLite o de la API
/// (según haya o no conexión) y que delega en el SyncManager la cola.
class TurnoRepositoryImpl implements TurnoRepository {
  TurnoRepositoryImpl(this._local, this._remote, this._conn, this._sync);
  final LocalDb _local;
  final RemoteDataSource _remote;
  final ConnectivityService _conn;
  final SyncManager _sync;

  static const _kBorrador = 'draft:confirmar';

  // ---------- Catálogo (con caché) ----------
  Future<List<T>> _conCache<T>(
    String key,
    Future<List<T>> Function() fetch,
    Map<String, dynamic> Function(T) enc,
    T Function(Map<String, dynamic>) dec,
  ) async {
    if (_conn.online) {
      try {
        final r = await fetch();
        await _local.putCache(key, jsonEncode(r.map(enc).toList()));
        return r;
      } on SinConexionException {
        // cae a la caché
      }
    }
    final raw = await _local.getCache(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => dec(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<Especialidad>> especialidades() => _conCache('cat:especialidades',
      _remote.especialidades, (e) => e.toJson(), Especialidad.fromJson);

  @override
  Future<List<Especialista>> especialistas() => _conCache('cat:especialistas',
      _remote.especialistas, (e) => e.toJson(), Especialista.fromJson);

  // ---------- Disponibilidad ----------
  @override
  Future<Disponibilidad> disponibilidadMes(int espId, int anio, int mes) async {
    final key = 'disp:$espId:$anio-$mes';
    if (_conn.online) {
      try {
        final r = await _remote.disponibilidadMes(espId, anio, mes);
        await _local.putCache(key, jsonEncode(r));
        return Disponibilidad(libres: r);
      } on SinConexionException {
        // cae a la caché
      }
    }
    final raw = await _local.getCache(key);
    if (raw == null) return const Disponibilidad(libres: {}, desdeCache: true);
    final cache = (jsonDecode(raw) as Map).map((k, v) =>
        MapEntry(k as String, (v as List).map((e) => e as String).toList()));

    // Descontar lo que el propio dispositivo ya reservó (incluye pendientes).
    final propios = await _local.turnosActivosDeEspecialista(espId);
    final ocupados = propios.map((t) => '${Fechas.iso(t.fecha)} ${t.hora}').toSet();
    final libres = <String, List<String>>{};
    cache.forEach((dia, horas) {
      final f = horas.where((h) => !ocupados.contains('$dia $h')).toList();
      if (f.isNotEmpty) libres[dia] = f;
    });
    return Disponibilidad(libres: libres, desdeCache: true);
  }

  Future<bool> _libreSegunLocal(int espId, DateTime fecha, String hora) async {
    final propios = await _local.turnosActivosDeEspecialista(espId);
    if (propios.any((t) => Fechas.iso(t.fecha) == Fechas.iso(fecha) && t.hora == hora)) {
      return false;
    }
    final raw = await _local.getCache('disp:$espId:${fecha.year}-${fecha.month}');
    if (raw == null) return true; // sin datos: se validará en el servidor
    final m = jsonDecode(raw) as Map;
    final horas = (m[Fechas.iso(fecha)] as List?)?.cast<String>() ?? const [];
    return horas.contains(hora);
  }

  // ---------- Solicitar ----------
  @override
  Future<Turno> solicitar({
    required Especialista especialista,
    required DateTime fecha,
    required String hora,
    required Paciente datos,
  }) async {
    final base = Turno(
      id: 'L${DateTime.now().microsecondsSinceEpoch}',
      pacienteDni: datos.dni,
      especialistaId: especialista.id,
      especialistaNombre: especialista.nombreCompleto,
      especialidad: especialista.especialidad,
      fecha: fecha,
      hora: hora,
      estado: EstadoTurno.pendienteSync,
    );

    if (_conn.online) {
      try {
        final rid = await _remote.solicitarTurno(
            especialistaId: especialista.id,
            fecha: Fechas.iso(fecha),
            hora: hora,
            paciente: datos);
        final t = base.copyWith(remoteId: rid, estado: EstadoTurno.activo);
        await _local.upsertTurno(t);
        return t;
      } on SinConexionException {
        // Se perdió la conexión a mitad de la solicitud -> flujo offline.
      }
    }

    if (!await _libreSegunLocal(especialista.id, fecha, hora)) {
      throw const HorarioNoDisponibleException();
    }
    await _local.upsertTurno(base);
    await _local.encolar('solicitar', base.id, {
      'especialistaId': especialista.id,
      'fecha': Fechas.iso(fecha),
      'hora': hora,
      'paciente': datos.toJson(),
    });
    return base;
  }

  // ---------- Cancelar ----------
  @override
  Future<Turno> cancelar(Turno t) async {
    // Turno que nunca llegó al servidor: se descarta de la cola.
    if (t.remoteId == null) {
      await _local.borrarColaDeTurno(t.id);
      await _local.actualizarEstado(t.id, EstadoTurno.cancelado);
      return t.copyWith(estado: EstadoTurno.cancelado);
    }
    var enviado = false;
    if (_conn.online) {
      try {
        await _remote.cancelarTurno(t.remoteId!);
        enviado = true;
      } on SinConexionException {
        // se encola
      }
    }
    if (!enviado) {
      await _local.encolar('cancelar', t.id, {'remoteId': t.remoteId});
    }
    await _local.actualizarEstado(t.id, EstadoTurno.cancelado);
    return t.copyWith(estado: EstadoTurno.cancelado);
  }

  // ---------- Historial ----------
  @override
  Future<List<Turno>> turnosLocales(String dni) => _local.turnosDe(dni);

  @override
  Future<List<Turno>> historial(String dni) async {
    if (_conn.online) {
      try {
        await _sync.procesarCola(); // primero lo pendiente, para no pisarlo
        final remotos = await _remote.turnosPaciente(dni);
        await _local.reemplazarSincronizados(dni, remotos);
      } on SinConexionException {
        // se muestra lo local
      }
    }
    return _local.turnosDe(dni);
  }

  // ---------- Sync ----------
  @override
  Future<List<SyncResultado>> sincronizar() => _sync.procesarCola();

  @override
  Stream<List<SyncResultado>> get resultadosSync => _sync.resultados;

  // ---------- Borrador del formulario ----------
  @override
  Future<void> guardarBorrador(Map<String, dynamic> datos) =>
      _local.putCache(_kBorrador, jsonEncode(datos));

  @override
  Future<Map<String, dynamic>?> cargarBorrador() async {
    final raw = await _local.getCache(_kBorrador);
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> borrarBorrador() => _local.borrarCache(_kBorrador);
}
