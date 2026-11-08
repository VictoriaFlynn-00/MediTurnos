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

  Future<Session> call(
      {required String usuario,
      required String password,
      required Paciente datos}) async {
    if (usuario.trim().length < 4) {
      throw const ValidacionException('El usuario debe tener al menos 4 caracteres');
    }
    if (password.length < 6) {
      throw const ValidacionException('La contraseña debe tener al menos 6 caracteres');
    }
    if (datos.dni.trim().length < 6) {
      throw const ValidacionException('Ingresá un DNI válido');
    }
    if (datos.nombre.trim().isEmpty) {
      throw const ValidacionException('Ingresá tu nombre y apellido');
    }
    if (!datos.email.contains('@')) {
      throw const ValidacionException('Ingresá un correo electrónico válido');
    }
    return _repo.registrar(
        usuario: usuario.trim(), password: password, datos: datos);
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
