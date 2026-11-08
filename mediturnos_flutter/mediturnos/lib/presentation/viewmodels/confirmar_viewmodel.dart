import '../../core/errors.dart';
import '../../core/safe_notifier.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/turno.dart';
import '../../domain/usecases/turno_usecases.dart';

class ConfirmarViewModel extends SafeNotifier {
  ConfirmarViewModel(this._solicitar, this.borrador);
  final SolicitarTurnoUseCase _solicitar;
  final BorradorTurnoUseCase borrador;

  bool enviando = false;
  String? error;

  Future<Turno?> confirmar(Especialista e, DateTime fecha, String hora, Paciente datos) async {
    enviando = true;
    error = null;
    notifyListeners();
    try {
      final t = await _solicitar(especialista: e, fecha: fecha, hora: hora, datos: datos);
      await borrador.borrar();
      return t;
    } on AppException catch (ex) {
      error = ex.mensaje;
    } catch (_) {
      error = 'No se pudo registrar el turno. Intentá de nuevo.';
    } finally {
      enviando = false;
      notifyListeners();
    }
    return null;
  }
}
