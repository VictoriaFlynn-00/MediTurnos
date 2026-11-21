import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../../core/connectivity_service.dart';
import '../../core/errors.dart';
import '../../core/fechas.dart';
import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/reserva_temporal.dart';
import '../../domain/entities/turno.dart';
import '../../domain/repositories/turno_repository.dart';
import '../datasources/local_db.dart';
import '../datasources/remote_data_source.dart';
import 'sync_manager.dart';

/// Único componente que decide si un dato sale de SQLite o de la API
/// (según haya o no conexión) y que delega en el SyncManager la cola.
class TurnoRepositoryImpl implements TurnoRepository {
  TurnoRepositoryImpl(this._local, this._remote, this._conn, this._sync,
      {Future<String?> Function()? vinculoInvitado})
      : _vinculoInvitado = vinculoInvitado;
  final LocalDb _local;
  final RemoteDataSource _remote;
  final ConnectivityService _conn;
  final SyncManager _sync;
  final Future<String?> Function()? _vinculoInvitado;

  static const _kBorrador = 'draft:confirmar';
  static final _azar = Random.secure();

  static String _nuevoId() => List.generate(
      32, (_) => _azar.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

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
        await _local.putCache(key, jsonEncode(r.toJson()));
        return await _ajustarDisponibilidad(r, espId, desdeCache: false);
      } on SinConexionException {
        // cae a la caché
      }
    }
    final raw = await _local.getCache(key);
    if (raw == null) return const Disponibilidad(desdeCache: true);
    final cache = Disponibilidad.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _ajustarDisponibilidad(cache, espId, desdeCache: true);
  }

  Future<Disponibilidad> _ajustarDisponibilidad(
    Disponibilidad disp, int espId, {required bool desdeCache}
  ) async {
    final propios = await _local.turnosActivosDeEspecialista(espId);
    final ocupados = propios
        .where((t) => desdeCache || t.estado == EstadoTurno.pendienteSync)
        .map((t) => '${Fechas.iso(t.fecha)} ${t.hora}')
        .toSet();
    final ahora = DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ');
    return Disponibilidad(
      desdeCache: desdeCache,
      horarios: disp.horarios.map((dia, slots) => MapEntry(dia, slots.map((h) {
        final clave = '$dia ${h.hora}';
        if (desdeCache && clave.compareTo(ahora) <= 0) {
          return HorarioAgenda(h.hora, EstadoHorario.pasado);
        }
        if (h.libre && ocupados.contains(clave)) {
          return HorarioAgenda(h.hora, EstadoHorario.ocupado);
        }
        return h;
      }).toList())),
    );
  }

  Future<bool> _libreSegunLocal(int espId, DateTime fecha, String hora, ReservaTemporal? reserva) async {
    final propios = await _local.turnosActivosDeEspecialista(espId);
    if (propios.any((t) => Fechas.iso(t.fecha) == Fechas.iso(fecha) && t.hora == hora)) {
      return false;
    }
    if (reserva != null) return true;
    final raw = await _local.getCache('disp:$espId:${fecha.year}-${fecha.month}');
    if (raw == null) return true; // sin datos: se validará en el servidor
    final disp = Disponibilidad.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return disp.horariosDe(Fechas.iso(fecha)).any((h) => h.hora == hora && h.libre);
  }

  @override
  Future<ReservaTemporal?> reservarHorario(int espId, DateTime fecha, String hora) async {
    if (!_conn.online) return null;
    final token = _nuevoId();
    try {
      final vinculo = await _vinculoInvitado?.call();
      final venceEn = await _remote.reservarHorario(
          espId, Fechas.iso(fecha), hora, token, avisoVinculo: vinculo);
      return ReservaTemporal(token, venceEn);
    } on SinConexionException {
      // El servidor pudo recibir el pedido aunque se perdiera la respuesta.
      return ReservaTemporal(token, null);
    }
  }

  @override
  Future<void> liberarHorario(int espId, DateTime fecha, String hora, ReservaTemporal reserva) async {
    final iso = Fechas.iso(fecha);
    if (reserva.venceEn?.isBefore(DateTime.now()) ?? false) return;
    if (_conn.online) {
      try {
        await _remote.liberarHorario(espId, iso, hora, reserva.token);
        return;
      } on SinConexionException {
        // Se vuelve a intentar si regresa la conexión antes del vencimiento.
      }
    }
    await _local.encolar('liberar', null, {
      'especialistaId': espId,
      'fecha': iso,
      'hora': hora,
      'reservaToken': reserva.token,
      'venceEn': reserva.venceEn?.toIso8601String(),
    });
    if (_conn.online) unawaited(_sync.procesarCola());
  }

  // ---------- Solicitar ----------
  @override
  Future<Turno> solicitar({
    required Especialista especialista,
    required DateTime fecha,
    required String hora,
    required Paciente datos,
    ReservaTemporal? reserva,
  }) async {
    final operacionId = _nuevoId();
    final avisoVinculo = await _vinculoInvitado?.call();
    final base = Turno(
      id: 'L$operacionId',
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
            paciente: datos,
            reservaToken: reserva?.token,
            reservaTentativa: reserva?.tentativa ?? false,
            operacionId: operacionId,
            avisoVinculo: avisoVinculo);
        final t = base.copyWith(remoteId: rid, estado: EstadoTurno.activo);
        await _local.upsertTurno(t);
        return t;
      } on SinConexionException {
        // Se perdió la conexión a mitad de la solicitud -> flujo offline.
      }
    }

    if (!await _libreSegunLocal(especialista.id, fecha, hora, reserva)) {
      throw const HorarioNoDisponibleException();
    }
    await _local.guardarSolicitudPendiente(base, {
      'especialistaId': especialista.id,
      'fecha': Fechas.iso(fecha),
      'hora': hora,
      'paciente': datos.toJson(),
      'operacionId': operacionId,
      if (avisoVinculo != null) 'avisoVinculo': avisoVinculo,
      'reservaToken': reserva?.token,
      'reservaTentativa': reserva?.tentativa ?? false,
    });
    if (_conn.online) unawaited(_sync.procesarCola());
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
