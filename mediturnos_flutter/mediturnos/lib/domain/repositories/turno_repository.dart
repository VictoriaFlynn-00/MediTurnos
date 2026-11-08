import '../entities/disponibilidad.dart';
import '../entities/especialista.dart';
import '../entities/paciente.dart';
import '../entities/turno.dart';

abstract class TurnoRepository {
  Future<List<Especialidad>> especialidades();
  Future<List<Especialista>> especialistas();
  Future<Disponibilidad> disponibilidadMes(int especialistaId, int anio, int mes);

  /// Devuelve el turno con estado `activo` (online) o `pendienteSync` (offline).
  Future<Turno> solicitar({
    required Especialista especialista,
    required DateTime fecha,
    required String hora,
    required Paciente datos,
  });

  Future<Turno> cancelar(Turno turno);

  /// Intenta refrescar desde el servidor (si hay red) y devuelve lo local.
  Future<List<Turno>> historial(String dni);
  Future<List<Turno>> turnosLocales(String dni);

  Future<List<SyncResultado>> sincronizar();
  Stream<List<SyncResultado>> get resultadosSync;

  // Borrador del formulario de turno (sobrevive a llamadas / cierre del SO).
  Future<void> guardarBorrador(Map<String, dynamic> datos);
  Future<Map<String, dynamic>?> cargarBorrador();
  Future<void> borrarBorrador();
}
