import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../domain/entities/session.dart';
import 'config.dart';

enum AvisoPush { confirmacion, conflicto }

typedef _Registro = ({String cuenta, String vinculo, String? token});

/// Vincula una instalación de FCM a la cuenta activa o a una sesión invitada.
class PushService {
  PushService(this._apiBase, this._online);

  final String _apiBase;
  final bool Function() _online;
  final _storage = const FlutterSecureStorage();
  final _avisos = StreamController<AvisoPush>.broadcast();
  final _mostrados = <String>{};

  static const _claveRegistro = 'push_registro';
  static const _claveBaja = 'push_baja_pendiente';
  static const _clavePermiso = 'push_permiso_solicitado';
  static const _invitado = 'invitado';

  Future<void> _pendiente = Future.value();
  Future<void>? _preparado;
  Future<FirebaseMessaging?>? _firebase;
  _Registro? _registro;
  DateTime? _ultimoRegistro;
  RemoteMessage? _mensajeInicial;
  String? _cuenta;
  String? _jwt;
  Timer? _reintentoApns;
  int _intentosApns = 0;

  bool get _habilitado =>
      kPushHabilitado &&
      !kUsarMock &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Stream<AvisoPush> get avisos => _avisos.stream;

  void iniciar() {
    if (_habilitado) _firebase ??= _iniciarFirebase();
  }

  Future<FirebaseMessaging?> _iniciarFirebase() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onMessage.listen(_recibir);
      FirebaseMessaging.onMessageOpenedApp.listen(_recibir);
      messaging.onTokenRefresh.listen((_) {
        _ultimoRegistro = null;
        reintentar();
      }, onError: (Object _) {});
      _mensajeInicial = await messaging.getInitialMessage();
      _mostrarInicial();
      return messaging;
    } catch (_) {
      debugPrint(
          'MediTurnos: Firebase no está disponible en esta instalación.');
      return null;
    }
  }

  void actualizarAcceso(Session? sesion, {required bool invitado}) {
    if (!_habilitado) return;
    final cuenta = sesion?.usuario.rol == Rol.paciente
        ? 'paciente:${sesion!.usuario.id}'
        : (invitado ? _invitado : null);
    final jwt = sesion?.token;
    if (_cuenta == cuenta && _jwt == jwt) return;
    _jwt = jwt;
    if (_cuenta == cuenta) {
      _ultimoRegistro = null;
      reintentar();
      return;
    }
    _cuenta = cuenta;
    _registro = null;
    _ultimoRegistro = null;
    _mostrados.clear();
    if (cuenta == null) return;
    iniciar();
    _preparado = _serializar(() async {
      final anterior = await _leerRegistro();
      if (_cuenta != cuenta) return;
      if (anterior?.cuenta == cuenta) {
        _registro = anterior;
      } else {
        if (anterior != null) await _storage.write(key: _claveBaja, value: '1');
        final random = Random.secure();
        _registro = (
          cuenta: cuenta,
          vinculo: List.generate(16,
                  (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
              .join(),
          token: null,
        );
        await _guardarRegistro(_registro!);
      }
      _mostrarInicial();
    });
    reintentar();
  }

  /// El turno invitado guarda su vínculo original también al quedar en cola local.
  Future<String?> vinculoInvitado() async {
    if (_cuenta != _invitado) return null;
    await _preparado;
    try {
      final messaging = await _firebase;
      final permiso = await messaging?.getNotificationSettings();
      return _cuenta == _invitado && _permiteAvisos(permiso)
          ? _registro?.vinculo
          : null;
    } catch (_) {
      return null;
    }
  }

  bool _permiteAvisos(NotificationSettings? permiso) =>
      permiso?.authorizationStatus == AuthorizationStatus.authorized ||
      permiso?.authorizationStatus == AuthorizationStatus.provisional;

  void reintentar() {
    _intentosApns = 0;
    if (_habilitado) unawaited(_serializar(_registrar));
  }

  Future<void> _registrar() async {
    final messaging = await _firebase;
    if (messaging == null) return;
    if (_online() && await _storage.read(key: _claveBaja) == '1') {
      await _borrarToken(messaging);
    }
    final registro = _registro;
    if (registro == null || registro.cuenta != _cuenta) return;
    final jwt = _jwt;

    var permiso = await messaging.getNotificationSettings();
    final androidSinConsultar =
        defaultTargetPlatform == TargetPlatform.android &&
            permiso.authorizationStatus == AuthorizationStatus.denied &&
            await _storage.read(key: _clavePermiso) == null;
    if (permiso.authorizationStatus == AuthorizationStatus.notDetermined ||
        androidSinConsultar) {
      await _storage.write(key: _clavePermiso, value: '1');
      permiso = await messaging.requestPermission();
    }
    if (_registro?.vinculo != registro.vinculo || !_online()) return;
    if (!_permiteAvisos(permiso)) {
      if (registro.token != null) {
        await _llamar('DELETE', registro, jwt);
        final revocado = (
          cuenta: registro.cuenta,
          vinculo: registro.vinculo,
          token: null as String?
        );
        if (_registro?.vinculo == registro.vinculo) _registro = revocado;
        await _guardarRegistro(revocado);
        _ultimoRegistro = null;
      }
      return;
    }
    final ultimo = _ultimoRegistro;
    if (ultimo != null &&
        DateTime.now().difference(ultimo) < const Duration(days: 1)) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await messaging.getAPNSToken() == null) {
      // El permiso puede resolverse antes de que APNs entregue su token.
      if (_reintentoApns == null && _intentosApns < 5) {
        _intentosApns++;
        _reintentoApns = Timer(const Duration(seconds: 4), () {
          _reintentoApns = null;
          unawaited(_serializar(_registrar));
        });
      }
      return;
    }
    final token =
        await messaging.getToken().timeout(const Duration(seconds: 5));
    if (token == null || _registro?.vinculo != registro.vinculo) return;
    final nuevo =
        (cuenta: registro.cuenta, vinculo: registro.vinculo, token: token);
    await _guardarRegistro(nuevo);
    if (_registro?.vinculo == registro.vinculo) _registro = nuevo;
    await _llamar('PUT', nuevo, jwt);
    if (_registro?.vinculo == registro.vinculo) {
      _registro = nuevo;
      _ultimoRegistro = DateTime.now();
    }
  }

  /// Quita el vínculo local de inmediato y revoca el registro mientras quede el JWT.
  Future<void> cerrarSesion(String? jwt) async {
    if (!_habilitado) return;
    final cuenta = _cuenta;
    _cuenta = null;
    _jwt = null;
    _registro = null;
    _mensajeInicial = null;
    _mostrados.clear();
    _reintentoApns?.cancel();
    _reintentoApns = null;
    await _serializar(() async {
      final registro = await _leerRegistro();
      if (registro == null || registro.cuenta != cuenta) return;
      await _storage.write(key: _claveBaja, value: '1');
      await _storage.delete(key: _claveRegistro);
      if (!_online()) return;
      final messaging = await _firebase;
      await Future.wait([
        if (registro.token != null) _llamar('DELETE', registro, jwt),
        if (messaging != null) _borrarToken(messaging),
      ]);
    });
  }

  Future<void> _borrarToken(FirebaseMessaging messaging) async {
    await messaging.deleteToken().timeout(const Duration(seconds: 4));
    await _storage.delete(key: _claveBaja);
  }

  Future<void> _llamar(String metodo, _Registro registro, String? jwt) async {
    final base = _apiBase.replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/avisos/dispositivos');
    final cliente = http.Client();
    try {
      final request = http.Request(metodo, uri)
        ..headers['Content-Type'] = 'application/json'
        ..body =
            jsonEncode({'token': registro.token, 'vinculo': registro.vinculo});
      if (jwt != null) request.headers['Authorization'] = 'Bearer $jwt';
      final respuesta =
          await cliente.send(request).timeout(const Duration(seconds: 4));
      if (respuesta.statusCode == 409 && metodo == 'PUT') {
        // Un registro anterior puede seguir vigente tras una reinstalación.
        await _storage.write(key: _claveBaja, value: '1');
      }
      if (respuesta.statusCode != 204) {
        throw StateError('Registro push rechazado');
      }
    } finally {
      cliente.close();
    }
  }

  Future<_Registro?> _leerRegistro() async {
    final raw = await _storage.read(key: _claveRegistro);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return (
      cuenta: j['cuenta'] as String,
      vinculo: j['vinculo'] as String,
      token: j['token'] as String?
    );
  }

  Future<void> _guardarRegistro(_Registro registro) => _storage.write(
        key: _claveRegistro,
        value: jsonEncode({
          'cuenta': registro.cuenta,
          'vinculo': registro.vinculo,
          'token': registro.token
        }),
      );

  Future<void> _serializar(Future<void> Function() tarea) {
    return _pendiente = _pendiente.then((_) => tarea()).catchError((Object _) {
      debugPrint('MediTurnos: no se pudo actualizar el registro push.');
    });
  }

  void _mostrarInicial() {
    final mensaje = _mensajeInicial;
    if (mensaje == null || _registro == null) return;
    _mensajeInicial = null;
    _recibir(mensaje);
  }

  void _recibir(RemoteMessage mensaje) {
    final id = mensaje.data['aviso'];
    final registro = _registro;
    if (id is! String ||
        registro == null ||
        mensaje.data['vinculo'] != registro.vinculo) {
      return;
    }
    final aviso = switch (mensaje.data['tipo']) {
      'confirmacion' => AvisoPush.confirmacion,
      'conflicto' => AvisoPush.conflicto,
      _ => null,
    };
    if (aviso == null || !_mostrados.add(id)) return;
    if (_mostrados.length > 100) _mostrados.remove(_mostrados.first);
    _avisos.add(aviso);
  }
}
