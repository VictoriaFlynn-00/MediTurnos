import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import '../../core/fechas.dart';
import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/turno.dart';
import 'remote_data_source.dart';

/// Cliente de la API REST de MediTurnos (Azure App Service + MySQL).
///
/// Regla de oro: todo fallo de red, timeout o servidor caído se traduce a
/// [SinConexionException]. Así el SyncManager deja la operación en la cola y la
/// reintenta, en lugar de marcar el turno como "rechazado".
class HttpRemoteDataSource implements RemoteDataSource {
  HttpRemoteDataSource(
    this._base,
    this._leerToken, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _timeout = timeout;

  final String _base;
  final Future<String?> Function() _leerToken;
  final http.Client _client;
  final Duration _timeout;

  // ---------------- infraestructura HTTP ----------------

  Future<http.Response> _llamar(
    String metodo,
    String ruta, {
    Object? cuerpo,
    bool conToken = true,
  }) async {
    final base = _base.endsWith('/') ? _base.substring(0, _base.length - 1) : _base;
    final uri = Uri.parse('$base$ruta');
    try {
      final token = conToken ? await _leerToken() : null;
      final req = http.Request(metodo, uri);
      req.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }
      if (cuerpo != null) {
        req.headers['Content-Type'] = 'application/json; charset=utf-8';
        req.body = jsonEncode(cuerpo);
      }
      final streamed = await _client.send(req).timeout(_timeout);
      return await http.Response.fromStream(streamed).timeout(_timeout);
    } on SocketException {
      throw const SinConexionException();
    } on TimeoutException {
      throw const SinConexionException('El servidor tardó demasiado en responder');
    } on HandshakeException {
      throw const AppException('No se pudo establecer una conexión segura con el servidor');
    } on http.ClientException {
      throw const SinConexionException();
    }
  }

  http.Response _ok(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return r;
    throw _error(r);
  }

  AppException _error(http.Response r) {
    String? code;
    String? msg;
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map) {
        code = j['code'] as String?;
        msg = j['error'] as String?;
      }
    } catch (_) {
      // cuerpo que no es JSON (por ejemplo una página de error del proxy)
    }
    switch (code) {
      case 'CREDENCIALES_INVALIDAS':
        return const CredencialesInvalidasException();
      case 'HORARIO_NO_DISPONIBLE':
        return const HorarioNoDisponibleException();
      case 'USUARIO_EXISTENTE':
        return UsuarioExistenteException(msg ?? 'El usuario ya existe');
      case 'VALIDACION':
        return ValidacionException(msg ?? 'Datos inválidos');
      case 'CORREO_NO_DISPONIBLE':
        return AppException(msg ?? 'La recuperación por correo no está disponible en este momento');
      case 'TOKEN_INVALIDO':
        return const SesionExpiradaException();
      case 'DEMASIADOS_INTENTOS':
        return SinConexionException(msg ?? 'Demasiados intentos, esperá unos minutos');
    }
    if (r.statusCode >= 500 || r.statusCode == 408) {
      return const SinConexionException('El servidor no está disponible, reintentá en unos minutos');
    }
    return AppException(msg ?? 'Error inesperado (${r.statusCode})');
  }

  dynamic _json(http.Response r) {
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      // Respuesta que no es JSON: casi seguro un intermediario (wifi con portal, proxy).
      throw const SinConexionException('No se pudo comunicar con el servidor');
    }
  }

  Session _sesion(Map<String, dynamic> j) => Session(
        token: j['token'] as String,
        usuario: Usuario.fromJson(j['usuario'] as Map<String, dynamic>),
        paciente: j['paciente'] == null
            ? null
            : Paciente.fromJson(j['paciente'] as Map<String, dynamic>),
      );

  // ---------------- Auth / pacientes ----------------

  @override
  Future<Session> login(String usuarioODni, String password) async {
    final r = await _llamar('POST', '/auth/login',
        cuerpo: {'usuario': usuarioODni.trim(), 'password': password}, conToken: false);
    return _sesion(_json(_ok(r)) as Map<String, dynamic>);
  }

  @override
  Future<void> verificarUsuarioDisponible(String usuario) async {
    _ok(await _llamar('POST', '/auth/usuario-disponible',
        cuerpo: {'usuario': usuario}, conToken: false));
  }

  @override
  Future<void> solicitarRecuperacion(String usuarioODni) async {
    _ok(await _llamar('POST', '/auth/recuperacion',
        cuerpo: {'usuario': usuarioODni}, conToken: false));
  }

  @override
  Future<void> restablecerClave(String codigo, String password) async {
    _ok(await _llamar('POST', '/auth/restablecer',
        cuerpo: {'codigo': codigo, 'password': password}, conToken: false));
  }

  @override
  Future<Paciente?> buscarPaciente(String dni) async {
    final r = await _llamar('GET', '/pacientes/$dni');
    if (r.statusCode == 404) return null;
    return Paciente.fromJson(_json(_ok(r)) as Map<String, dynamic>);
  }

  @override
  Future<Session> registrar(String usuario, String password, Paciente datos) async {
    final r = await _llamar('POST', '/auth/registro',
        cuerpo: {'usuario': usuario, 'password': password, 'paciente': datos.toJson()},
        conToken: false);
    return _sesion(_json(_ok(r)) as Map<String, dynamic>);
  }

  @override
  Future<Paciente> actualizarPaciente(Paciente p) async {
    final r = await _llamar('PUT', '/pacientes/${p.dni}', cuerpo: p.toJson());
    return Paciente.fromJson(_json(_ok(r)) as Map<String, dynamic>);
  }

  // ---------------- Catálogo / agenda ----------------

  @override
  Future<List<Especialidad>> especialidades() async {
    final r = await _llamar('GET', '/especialidades');
    return (_json(_ok(r)) as List)
        .map((e) => Especialidad.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Especialista>> especialistas() async {
    final r = await _llamar('GET', '/especialistas');
    return (_json(_ok(r)) as List)
        .map((e) => Especialista.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Disponibilidad> disponibilidadMes(int espId, int anio, int mes) async {
    final r = await _llamar('GET', '/especialistas/$espId/disponibilidad?anio=$anio&mes=$mes&detalle=1');
    return Disponibilidad.fromJson(_json(_ok(r)) as Map<String, dynamic>);
  }

  // ---------------- Turnos ----------------

  Map<String, dynamic> _bodyReserva(int espId, String fecha, String hora, String token) => {
        'especialistaId': espId,
        'fecha': fecha,
        'hora': hora,
        'reservaToken': token,
      };

  @override
  Future<DateTime> reservarHorario(int espId, String fecha, String hora, String token,
      {String? avisoVinculo}) async {
    final r = await _llamar('POST', '/turnos/reservas', cuerpo: {
      ..._bodyReserva(espId, fecha, hora, token),
      if (avisoVinculo != null) 'avisoVinculo': avisoVinculo,
    });
    final json = _json(_ok(r)) as Map<String, dynamic>;
    return DateTime.parse(json['venceEn'] as String);
  }

  @override
  Future<void> liberarHorario(int espId, String fecha, String hora, String token) async {
    _ok(await _llamar('POST', '/turnos/reservas/liberar', cuerpo: _bodyReserva(espId, fecha, hora, token)));
  }

  @override
  Future<int> solicitarTurno({
    required int especialistaId,
    required String fecha,
    required String hora,
    required Paciente paciente,
    String? reservaToken,
    bool reservaTentativa = false,
    String? operacionId,
    String? avisoVinculo,
  }) async {
    final r = await _llamar('POST', '/turnos', cuerpo: {
      'especialistaId': especialistaId,
      'fecha': fecha,
      'hora': hora,
      'paciente': paciente.toJson(),
      if (reservaToken != null) 'reservaToken': reservaToken,
      if (reservaTentativa) 'reservaTentativa': true,
      if (operacionId != null) 'operacionId': operacionId,
      if (avisoVinculo != null) 'avisoVinculo': avisoVinculo,
    });
    return (_json(_ok(r)) as Map<String, dynamic>)['id'] as int;
  }

  @override
  Future<void> cancelarTurno(int remoteId) async {
    _ok(await _llamar('PATCH', '/turnos/$remoteId/cancelar'));
  }

  @override
  Future<List<Turno>> turnosPaciente(String dni) async {
    final r = await _llamar('GET', '/pacientes/$dni/turnos');
    return (_json(_ok(r)) as List).map((e) {
      final m = e as Map<String, dynamic>;
      final id = m['id'] as int;
      return Turno(
        id: 'r$id',
        remoteId: id,
        pacienteDni: dni,
        especialistaId: m['especialistaId'] as int,
        especialistaNombre: m['especialistaNombre'] as String,
        especialidad: m['especialidad'] as String,
        fecha: Fechas.parse(m['fecha'] as String),
        hora: m['hora'] as String,
        estado: EstadoTurno.desde(m['estado'] as String),
      );
    }).toList();
  }
}
