import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local_db.dart';
import '../datasources/remote_data_source.dart';

abstract class TokenStorage {
  Future<String?> leer();
  Future<void> guardar(String token);
  Future<void> borrar();
}

/// El JWT se guarda cifrado (Keychain en iOS / EncryptedSharedPreferences en Android).
class SecureTokenStorage implements TokenStorage {
  static const _k = 'jwt';
  final _s = const FlutterSecureStorage();
  @override
  Future<String?> leer() => _s.read(key: _k);
  @override
  Future<void> guardar(String token) => _s.write(key: _k, value: token);
  @override
  Future<void> borrar() => _s.delete(key: _k);
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._local, this._tokens);
  final RemoteDataSource _remote;
  final LocalDb _local;
  final TokenStorage _tokens;

  static const _kUsuario = 'user:usuario';
  static const _kPaciente = 'user:paciente';

  Future<Session> _guardar(Session s) async {
    await _tokens.guardar(s.token);
    await _local.putCache(_kUsuario, jsonEncode(s.usuario.toJson()));
    if (s.paciente != null) {
      await _local.putCache(_kPaciente, jsonEncode(s.paciente!.toJson()));
    }
    return s;
  }

  /// Offline-first: reabrir la app recupera la sesión sin necesitar red.
  @override
  Future<Session?> restaurarSesion() async {
    final token = await _tokens.leer();
    final u = await _local.getCache(_kUsuario);
    if (token == null || u == null) return null;
    final p = await _local.getCache(_kPaciente);
    return Session(
      token: token,
      usuario: Usuario.fromJson(jsonDecode(u) as Map<String, dynamic>),
      paciente: p == null
          ? null
          : Paciente.fromJson(jsonDecode(p) as Map<String, dynamic>),
    );
  }

  @override
  Future<Session> iniciarSesion(String usuario, String password) async =>
      _guardar(await _remote.login(usuario, password));

  @override
  Future<Paciente?> buscarPacientePorDni(String dni) => _remote.buscarPaciente(dni);

  @override
  Future<Session> registrar(
          {required String usuario,
          required String password,
          required Paciente datos}) async =>
      _guardar(await _remote.registrar(usuario, password, datos));

  @override
  Future<Paciente> actualizarPaciente(Paciente p) async {
    final nuevo = await _remote.actualizarPaciente(p);
    await _local.putCache(_kPaciente, jsonEncode(nuevo.toJson()));
    return nuevo;
  }

  @override
  Future<void> cerrarSesion() async {
    await _tokens.borrar();
    await _local.limpiarDatosUsuario();
  }
}
