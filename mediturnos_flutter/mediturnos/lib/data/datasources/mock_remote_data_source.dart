import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/errors.dart';
import '../../core/fechas.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/turno.dart';
import 'remote_data_source.dart';

class _Cuenta {
  final int id;
  final String usuario;
  final String hash;
  final String dni;
  _Cuenta(this.id, this.usuario, this.hash, this.dni);
}

class _RTurno {
  final int id;
  final String dni;
  final int espId;
  final String fecha;
  final String hora;
  String estado;
  _RTurno(this.id, this.dni, this.espId, this.fecha, this.hora, this.estado);
}

/// Servidor simulado en memoria. Respeta la conectividad de la app
/// (lanza SinConexionException cuando está offline) para poder demostrar
/// offline-first, cola de sincronización y conflictos de doble reserva.
///
/// Usuario de prueba: camilaf_99 / 12345678 (DNI 34123456).
/// DNI sin usuario (para probar el registro): 40111222.
class MockRemoteDataSource implements RemoteDataSource {
  MockRemoteDataSource(this._online) {
    _sembrar();
  }

  final bool Function() _online;

  static const _horarios = ['09:00', '09:30', '10:15', '11:00', '15:30', '16:00'];

  final _especialidades = const [
    Especialidad(id: 1, nombre: 'Cardiología'),
    Especialidad(id: 2, nombre: 'Clínica Médica'),
    Especialidad(id: 3, nombre: 'Pediatría'),
  ];

  final _docs = const [
    Especialista(id: 1, prefijo: 'Dr.', nombre: 'Alberto', apellido: 'Fernández', especialidadId: 2, especialidad: 'Clínica Médica'),
    Especialista(id: 2, prefijo: 'Dr.', nombre: 'Juan', apellido: 'Pérez', especialidadId: 1, especialidad: 'Cardiología'),
    Especialista(id: 3, prefijo: 'Dra.', nombre: 'María', apellido: 'Ríos', especialidadId: 3, especialidad: 'Pediatría'),
    Especialista(id: 4, prefijo: 'Dra.', nombre: 'Laura', apellido: 'Gómez', especialidadId: 1, especialidad: 'Cardiología'),
    Especialista(id: 5, prefijo: 'Dr.', nombre: 'Pablo', apellido: 'Sosa', especialidadId: 3, especialidad: 'Pediatría'),
  ];

  // Días de atención por especialista (DateTime.weekday: 1=lunes ... 7=domingo).
  final _dias = const <int, Set<int>>{
    1: {1, 2, 3, 4, 5},
    2: {2, 4, 5},
    3: {1, 3, 5},
    4: {1, 3},
    5: {2, 4},
  };

  final _pacientes = <String, Paciente>{};
  final _cuentas = <_Cuenta>[];
  final _turnos = <_RTurno>[];
  int _seq = 100;

  void _sembrar() {
    _pacientes['34123456'] = const Paciente(
      dni: '34123456', nombre: 'Camila', apellido: 'Fernández',
      fechaNacimiento: '1995-08-14', email: 'camila.f@ejemplo.com',
      telefono: '385 555 1234',
      domicilio: 'Av. Belgrano Sur 1234, Santiago del Estero',
      obraSocial: 'OSDE', plan: '210', nroAfiliado: '123456789', usuarioId: 1,
    );
    _cuentas.add(_Cuenta(1, 'camilaf_99', _hash('12345678'), '34123456'));
    _pacientes['40111222'] = const Paciente(
      dni: '40111222', nombre: 'Lucía', apellido: 'Gómez',
      fechaNacimiento: '2001-03-02', email: 'lucia.g@ejemplo.com',
      telefono: '385 444 9876', domicilio: 'Independencia 450',
    );

    final hoy = Fechas.hoy();
    var prox = hoy.add(const Duration(days: 3));
    while (!_dias[3]!.contains(prox.weekday)) {
      prox = prox.add(const Duration(days: 1));
    }
    _turnos.add(_RTurno(1, '34123456', 3, Fechas.iso(prox), '16:00', 'activo'));
    _turnos.add(_RTurno(2, '34123456', 2,
        Fechas.iso(hoy.subtract(const Duration(days: 40))), '10:15', 'activo'));
  }

  // ---- utilidades ----
  String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

  Future<void> _red() async {
    if (!_online()) throw const SinConexionException();
    await Future.delayed(const Duration(milliseconds: 350));
  }

  String _jwt(Usuario u) {
    String b(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final exp = DateTime.now().add(const Duration(hours: 8)).millisecondsSinceEpoch ~/ 1000;
    return '${b({'alg': 'HS256', 'typ': 'JWT'})}.${b({'sub': u.id, 'rol': u.rol.name, 'exp': exp})}.mock-signature';
  }

  /// Ocupación "natural" determinística para que el calendario no esté vacío.
  bool _ocupadoSemilla(int espId, DateTime d, int i) =>
      (d.day * 7 + espId * 3 + i * 5) % 4 == 0;

  Especialista _doc(int id) => _docs.firstWhere((d) => d.id == id);

  // ---- Auth ----
  @override
  Future<Session> login(String usuarioODni, String password) async {
    await _red();
    final q = usuarioODni.trim().toLowerCase();
    final c = _cuentas
        .where((c) => c.usuario.toLowerCase() == q || c.dni == q)
        .firstOrNull;
    if (c == null || c.hash != _hash(password)) {
      throw const CredencialesInvalidasException();
    }
    final u = Usuario(id: c.id, usuario: c.usuario, rol: Rol.paciente);
    return Session(token: _jwt(u), usuario: u, paciente: _pacientes[c.dni]);
  }

  @override
  Future<Paciente?> buscarPaciente(String dni) async {
    await _red();
    return _pacientes[dni];
  }

  @override
  Future<Session> registrar(String usuario, String password, Paciente datos) async {
    await _red();
    final existente = _pacientes[datos.dni];
    if (existente != null && existente.usuarioId != null) {
      throw const UsuarioExistenteException('Ese DNI ya tiene un usuario registrado');
    }
    if (_cuentas.any((c) => c.usuario.toLowerCase() == usuario.toLowerCase())) {
      throw const UsuarioExistenteException('Ese nombre de usuario ya está en uso');
    }
    final id = ++_seq;
    _cuentas.add(_Cuenta(id, usuario, _hash(password), datos.dni));
    final p = datos.copyWith(usuarioId: id);
    _pacientes[datos.dni] = p;
    final u = Usuario(id: id, usuario: usuario, rol: Rol.paciente);
    return Session(token: _jwt(u), usuario: u, paciente: p);
  }

  @override
  Future<Paciente> actualizarPaciente(Paciente p) async {
    await _red();
    final actual = _pacientes[p.dni];
    final nuevo = p.copyWith(usuarioId: actual?.usuarioId ?? p.usuarioId);
    _pacientes[p.dni] = nuevo;
    return nuevo;
  }

  // ---- Catálogo / agenda ----
  @override
  Future<List<Especialidad>> especialidades() async {
    await _red();
    return _especialidades;
  }

  @override
  Future<List<Especialista>> especialistas() async {
    await _red();
    return _docs;
  }

  @override
  Future<Map<String, List<String>>> disponibilidadMes(int espId, int anio, int mes) async {
    await _red();
    final hoy = Fechas.hoy();
    final out = <String, List<String>>{};
    final n = DateTime(anio, mes + 1, 0).day;
    for (var d = 1; d <= n; d++) {
      final f = DateTime(anio, mes, d);
      if (f.isBefore(hoy)) continue;
      if (!(_dias[espId] ?? const {}).contains(f.weekday)) continue;
      final iso = Fechas.iso(f);
      final libres = <String>[];
      for (var i = 0; i < _horarios.length; i++) {
        final h = _horarios[i];
        if (_ocupadoSemilla(espId, f, i)) continue;
        if (_turnos.any((t) =>
            t.espId == espId && t.fecha == iso && t.hora == h && t.estado == 'activo')) {
          continue;
        }
        libres.add(h);
      }
      if (libres.isNotEmpty) out[iso] = libres;
    }
    return out;
  }

  // ---- Turnos ----
  @override
  Future<int> solicitarTurno({
    required int especialistaId,
    required String fecha,
    required String hora,
    required Paciente paciente,
  }) async {
    await _red();
    // "Transacción": revalida que el horario siga libre.
    final f = Fechas.parse(fecha);
    final i = _horarios.indexOf(hora);
    final ocupadoSeed = i >= 0 && _ocupadoSemilla(especialistaId, f, i);
    final tomado = _turnos.any((t) =>
        t.espId == especialistaId && t.fecha == fecha && t.hora == hora && t.estado == 'activo');
    if (ocupadoSeed || tomado || i < 0) throw const HorarioNoDisponibleException();

    // Alta/actualización de la ficha del paciente (también para invitados).
    final previo = _pacientes[paciente.dni];
    _pacientes[paciente.dni] = paciente.copyWith(usuarioId: previo?.usuarioId);

    final id = ++_seq;
    _turnos.add(_RTurno(id, paciente.dni, especialistaId, fecha, hora, 'activo'));
    return id;
  }

  /// Solo para pruebas: simula que OTRO paciente reservó ese horario.
  void simularReservaAjena(int espId, String fecha, String hora) {
    _turnos.add(_RTurno(++_seq, '99999999', espId, fecha, hora, 'activo'));
  }

  @override
  Future<void> cancelarTurno(int remoteId) async {
    await _red();
    for (final t in _turnos) {
      if (t.id == remoteId) t.estado = 'cancelado';
    }
  }

  @override
  Future<List<Turno>> turnosPaciente(String dni) async {
    await _red();
    return _turnos.where((t) => t.dni == dni).map((t) {
      final d = _doc(t.espId);
      return Turno(
        id: 'r${t.id}',
        remoteId: t.id,
        pacienteDni: dni,
        especialistaId: d.id,
        especialistaNombre: d.nombreCompleto,
        especialidad: d.especialidad,
        fecha: Fechas.parse(t.fecha),
        hora: t.hora,
        estado: EstadoTurno.desde(t.estado),
      );
    }).toList();
  }
}
