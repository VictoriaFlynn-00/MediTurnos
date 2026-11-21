import 'dart:async';

import '../../core/errors.dart';
import '../../core/safe_notifier.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/reserva_temporal.dart';
import '../../domain/entities/turno.dart';
import '../../domain/usecases/turno_usecases.dart';

class ConfirmarViewModel extends SafeNotifier {
  ConfirmarViewModel(this._solicitar, this.borrador, this.reserva) {
    if (reserva?.venceEn != null && !vencida) {
      _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
        if (vencida) t.cancel();
        notifyListeners();
      });
    }
  }
  final SolicitarTurnoUseCase _solicitar;
  final BorradorTurnoUseCase borrador;
  final ReservaTemporal? reserva;
  Timer? _reloj;

  bool enviando = false;
  String? error;
  bool _sinHorario = false;

  int? get segundosRestantes {
    final venceEn = reserva?.venceEn;
    if (venceEn == null) return null;
    final ms = venceEn.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  bool get vencida => segundosRestantes == 0;
  bool get horarioDisponible => !_sinHorario && !vencida;

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<Turno?> confirmar(Especialista e, DateTime fecha, String hora, Paciente datos) async {
    if (enviando || !horarioDisponible) return null;
    enviando = true;
    error = null;
    notifyListeners();
    try {
      final t = await _solicitar(especialista: e, fecha: fecha, hora: hora, datos: datos, reserva: reserva);
      await borrador.borrar();
      return t;
    } on HorarioNoDisponibleException catch (ex) {
      _sinHorario = true;
      error = ex.mensaje;
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
