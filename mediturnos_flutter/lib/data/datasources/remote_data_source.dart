import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/turno.dart';

/// Contrato con la API REST (Azure App Service). Toda implementación debe
/// lanzar SinConexionException ante fallas de red.
abstract class RemoteDataSource {
  Future<Session> login(String usuarioODni, String password);
  Future<void> verificarUsuarioDisponible(String usuario);
  Future<void> solicitarRecuperacion(String usuarioODni);
  Future<void> restablecerClave(String codigo, String password);
  Future<Paciente?> buscarPaciente(String dni);
  Future<Session> registrar(String usuario, String password, Paciente datos);
  Future<Paciente> actualizarPaciente(Paciente p);

  Future<List<Especialidad>> especialidades();
  Future<List<Especialista>> especialistas();
  Future<Disponibilidad> disponibilidadMes(int espId, int anio, int mes);

  Future<DateTime> reservarHorario(int espId, String fecha, String hora, String token,
      {String? avisoVinculo});
  Future<void> liberarHorario(int espId, String fecha, String hora, String token);

  /// Valida disponibilidad dentro de una transacción en el servidor.
  /// Lanza HorarioNoDisponibleException si ya fue tomado. Devuelve id remoto.
  Future<int> solicitarTurno({
    required int especialistaId,
    required String fecha,
    required String hora,
    required Paciente paciente,
    String? reservaToken,
    bool reservaTentativa = false,
    String? operacionId,
    String? avisoVinculo,
  });

  Future<void> cancelarTurno(int remoteId);
  Future<List<Turno>> turnosPaciente(String dni);
}
