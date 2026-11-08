import '../entities/paciente.dart';
import '../entities/session.dart';

abstract class AuthRepository {
  Future<Session?> restaurarSesion();
  Future<Session> iniciarSesion(String usuario, String password);
  Future<Paciente?> buscarPacientePorDni(String dni);
  Future<Session> registrar(
      {required String usuario,
      required String password,
      required Paciente datos});
  Future<Paciente> actualizarPaciente(Paciente p);
  Future<void> cerrarSesion();
}
