import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/turno.dart';

/// Contrato con la API REST (Azure App Service). Toda implementación debe
/// lanzar SinConexionException ante fallas de red.
abstract class RemoteDataSource {
  Future<Session> login(String usuarioODni, String password);
  Future<Paciente?> buscarPaciente(String dni);
  Future<Session> registrar(String usuario, String password, Paciente datos);
  Future<Paciente> actualizarPaciente(Paciente p);

  Future<List<Especialidad>> especialidades();
  Future<List<Especialista>> especialistas();
  Future<Map<String, List<String>>> disponibilidadMes(int espId, int anio, int mes);

  /// Valida disponibilidad dentro de una transacción en el servidor.
  /// Lanza HorarioNoDisponibleException si ya fue tomado. Devuelve id remoto.
  Future<int> solicitarTurno({
    required int especialistaId,
    required String fecha,
    required String hora,
    required Paciente paciente,
  });

  Future<void> cancelarTurno(int remoteId);
  Future<List<Turno>> turnosPaciente(String dni);
}
