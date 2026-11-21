import 'dart:async';
import '../../core/errors.dart';
import '../../core/safe_notifier.dart';
import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/turno.dart';
import '../../domain/usecases/turno_usecases.dart';

enum TabTurnos { proximos, historial }

class TurnosViewModel extends SafeNotifier {
  TurnosViewModel(this._historial, this._cancelar, this._paciente,
      Stream<List<SyncResultado>> sync) {
    // Cuando se sincroniza la cola, se refresca la lista.
    _sub = sync.listen((_) => cargar());
  }
  final ConsultarHistorialUseCase _historial;
  final CancelarTurnoUseCase _cancelar;
  final Paciente? Function() _paciente;
  StreamSubscription<List<SyncResultado>>? _sub;

  List<Turno> turnos = [];
  bool cargando = false;
  String? error;
  TabTurnos tab = TabTurnos.proximos;

  List<Turno> get proximos =>
      turnos.where((t) => t.esProximo).toList()
        ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

  List<Turno> get historial =>
      turnos.where((t) => !t.esProximo).toList()
        ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

  void setTab(TabTurnos t) {
    tab = t;
    notifyListeners();
  }

  Future<void> cargar() async {
    final p = _paciente();
    if (p == null) return;
    cargando = true;
    notifyListeners();
    try {
      turnos = await _historial(p.dni);
      error = null;
    } on AppException catch (e) {
      error = e.mensaje;
    }
    cargando = false;
    notifyListeners();
  }

  /// Devuelve null si salió bien, o el mensaje de error.
  Future<String?> cancelar(Turno t) async {
    try {
      await _cancelar(t);
      await cargar();
      return null;
    } on AppException catch (e) {
      return e.mensaje;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
