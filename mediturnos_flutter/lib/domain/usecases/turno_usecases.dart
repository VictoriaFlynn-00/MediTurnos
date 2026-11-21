import '../../core/errors.dart';
import '../entities/disponibilidad.dart';
import '../entities/especialista.dart';
import '../entities/paciente.dart';
import '../entities/reserva_temporal.dart';
import '../entities/turno.dart';
import '../repositories/turno_repository.dart';

class ConsultarEspecialistasUseCase {
  final TurnoRepository _repo;
  ConsultarEspecialistasUseCase(this._repo);
  Future<List<Especialista>> call() => _repo.especialistas();
}

class ConsultarEspecialidadesUseCase {
  final TurnoRepository _repo;
  ConsultarEspecialidadesUseCase(this._repo);
  Future<List<Especialidad>> call() => _repo.especialidades();
}

class ConsultarDisponibilidadUseCase {
  final TurnoRepository _repo;
  ConsultarDisponibilidadUseCase(this._repo);
  Future<Disponibilidad> call(int especialistaId, int anio, int mes) =>
      _repo.disponibilidadMes(especialistaId, anio, mes);
}

class SolicitarTurnoUseCase {
  final TurnoRepository _repo;
  SolicitarTurnoUseCase(this._repo);

  Future<ReservaTemporal?> reservar(int especialistaId, DateTime fecha, String hora) =>
      _repo.reservarHorario(especialistaId, fecha, hora);

  Future<void> liberar(int especialistaId, DateTime fecha, String hora, ReservaTemporal reserva) =>
      _repo.liberarHorario(especialistaId, fecha, hora, reserva);

  Future<Turno> call({
    required Especialista especialista,
    required DateTime fecha,
    required String hora,
    required Paciente datos,
    ReservaTemporal? reserva,
  }) async {
    if (datos.dni.trim().length < 6) {
      throw const ValidacionException('Ingresá un DNI válido');
    }
    if (datos.nombre.trim().isEmpty) {
      throw const ValidacionException('Ingresá tu nombre y apellido');
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(datos.email.trim())) {
      throw const ValidacionException(
          'El correo electrónico es obligatorio para confirmar');
    }

    final p = hora.split(':');
    final fh = DateTime(fecha.year, fecha.month, fecha.day, int.parse(p[0]),
        int.parse(p[1]));
    if (!fh.isAfter(DateTime.now())) {
      throw const ValidacionException('No se puede pedir un turno en el pasado');
    }

    // Regla de negocio: el paciente no puede tener dos turnos solapados.
    final existentes = await _repo.turnosLocales(datos.dni);
    final solapado = existentes.any((t) =>
        (t.estado == EstadoTurno.activo ||
            t.estado == EstadoTurno.pendienteSync) &&
        t.fechaHora == fh);
    if (solapado) {
      throw const ValidacionException(
          'Ya tenés un turno en ese día y horario');
    }

    return _repo.solicitar(
        especialista: especialista, fecha: fecha, hora: hora, datos: datos, reserva: reserva);
  }
}

class CancelarTurnoUseCase {
  final TurnoRepository _repo;
  CancelarTurnoUseCase(this._repo);

  Future<Turno> call(Turno t) async {
    if (t.estado != EstadoTurno.activo &&
        t.estado != EstadoTurno.pendienteSync) {
      throw const ValidacionException('Este turno ya no se puede cancelar');
    }
    return _repo.cancelar(t);
  }
}

class ConsultarHistorialUseCase {
  final TurnoRepository _repo;
  ConsultarHistorialUseCase(this._repo);
  Future<List<Turno>> call(String dni) => _repo.historial(dni);
}

class SincronizarTurnosUseCase {
  final TurnoRepository _repo;
  SincronizarTurnosUseCase(this._repo);
  Future<List<SyncResultado>> call() => _repo.sincronizar();
}

class BorradorTurnoUseCase {
  final TurnoRepository _repo;
  BorradorTurnoUseCase(this._repo);
  Future<void> guardar(Map<String, dynamic> d) => _repo.guardarBorrador(d);
  Future<Map<String, dynamic>?> cargar() => _repo.cargarBorrador();
  Future<void> borrar() => _repo.borrarBorrador();
}
