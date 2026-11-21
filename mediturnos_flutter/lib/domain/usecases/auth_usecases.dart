import 'dart:convert';

import '../../core/errors.dart';
import '../entities/paciente.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class IniciarSesionUseCase {
  final AuthRepository _repo;
  IniciarSesionUseCase(this._repo);

  Future<Session> call(String usuario, String password) async {
    if (usuario.trim().isEmpty || password.isEmpty) {
      throw const ValidacionException('Ingresá tu usuario y contraseña');
    }
    return _repo.iniciarSesion(usuario.trim(), password);
  }
}

class RegistrarPacienteUseCase {
  final AuthRepository _repo;
  RegistrarPacienteUseCase(this._repo);

  Future<void> verificarCredenciales({
    required String usuario,
    required String password,
    required String confirmacion,
  }) async {
    final nombre = _validarUsuario(usuario);
    _validarClaveConfirmada(password, confirmacion);
    await _repo.verificarUsuarioDisponible(nombre);
  }

  Future<Session> call(
      {required String usuario,
      required String password,
      required String confirmacion,
      required Paciente datos}) async {
    final nombre = _validarUsuario(usuario);
    _validarClaveConfirmada(password, confirmacion);
    if (datos.dni.trim().length < 6) {
      throw const ValidacionException('Ingresá un DNI válido');
    }
    if (datos.nombre.trim().isEmpty) {
      throw const ValidacionException('Ingresá tu nombre y apellido');
    }
    final email = datos.email.trim();
    if (email.length > 150 || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const ValidacionException('Ingresá un correo electrónico válido');
    }
    return _repo.registrar(usuario: nombre, password: password, datos: datos);
  }
}

class RecuperarClaveUseCase {
  final AuthRepository _repo;
  RecuperarClaveUseCase(this._repo);

  Future<void> solicitar(String usuarioODni) async {
    final usuario = usuarioODni.trim();
    if (usuario.isEmpty || usuario.length > 100) {
      throw const ValidacionException('Ingresá tu usuario o DNI');
    }
    await _repo.solicitarRecuperacion(usuario);
  }

  Future<void> restablecer({
    required String codigo,
    required String password,
    required String confirmacion,
  }) async {
    final token = codigo.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw const ValidacionException('Copiá el código completo del correo');
    }
    _validarClaveConfirmada(password, confirmacion);
    await _repo.restablecerClave(token, password);
  }
}

String _validarUsuario(String usuario) {
  final nombre = usuario.trim();
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9._-]{2,29}$').hasMatch(nombre)) {
    throw const ValidacionException(
      'El usuario debe empezar con una letra y tener de 3 a 30 caracteres (letras, números, . _ -)',
    );
  }
  return nombre;
}

void _validarClaveConfirmada(String clave, String confirmacion) {
  if (clave.length < 8 || utf8.encode(clave).length > 72) {
    throw const ValidacionException('La contraseña debe tener entre 8 y 72 caracteres');
  }
  if (clave != confirmacion) {
    throw const ValidacionException('Las contraseñas no coinciden');
  }
}

class BuscarPacienteUseCase {
  final AuthRepository _repo;
  BuscarPacienteUseCase(this._repo);
  Future<Paciente?> call(String dni) => _repo.buscarPacientePorDni(dni.trim());
}

class ActualizarPerfilUseCase {
  final AuthRepository _repo;
  ActualizarPerfilUseCase(this._repo);

  Future<Paciente> call(Paciente p) async {
    if (p.nombre.trim().isEmpty) {
      throw const ValidacionException('El nombre no puede estar vacío');
    }
    if (!p.email.contains('@')) {
      throw const ValidacionException('Ingresá un correo electrónico válido');
    }
    return _repo.actualizarPaciente(p);
  }
}

class RestaurarSesionUseCase {
  final AuthRepository _repo;
  RestaurarSesionUseCase(this._repo);
  Future<Session?> call() => _repo.restaurarSesion();
}

class CerrarSesionUseCase {
  final AuthRepository _repo;
  CerrarSesionUseCase(this._repo);
  Future<void> call() => _repo.cerrarSesion();
}
