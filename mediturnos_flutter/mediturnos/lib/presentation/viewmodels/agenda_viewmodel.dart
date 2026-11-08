import '../../core/errors.dart';
import '../../core/fechas.dart';
import '../../core/safe_notifier.dart';
import '../../domain/entities/disponibilidad.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/usecases/turno_usecases.dart';

class AgendaViewModel extends SafeNotifier {
  AgendaViewModel(this.especialista, this._disp) {
    final h = Fechas.hoy();
    mes = DateTime(h.year, h.month);
  }
  final Especialista especialista;
  final ConsultarDisponibilidadUseCase _disp;

  late DateTime mes;
  Disponibilidad disp = const Disponibilidad(libres: {});
  bool cargando = false;
  String? error;
  String? fechaSel; // yyyy-MM-dd
  String? horaSel;

  DateTime? get fechaSeleccionada =>
      fechaSel == null ? null : Fechas.parse(fechaSel!);
  List<String> get horarios => fechaSel == null ? const [] : disp.horariosDe(fechaSel!);

  bool get puedeIrAtras {
    final h = Fechas.hoy();
    return mes.isAfter(DateTime(h.year, h.month));
  }

  bool get puedeIrAdelante {
    final h = Fechas.hoy();
    return mes.isBefore(DateTime(h.year, h.month + 3));
  }

  Future<void> cargarMes() async {
    cargando = true;
    error = null;
    fechaSel = null;
    horaSel = null;
    notifyListeners();
    try {
      disp = await _disp(especialista.id, mes.year, mes.month);
    } on AppException catch (e) {
      error = e.mensaje;
      disp = const Disponibilidad(libres: {});
    }
    cargando = false;
    notifyListeners();
  }

  Future<void> mesAnterior() async {
    if (!puedeIrAtras) return;
    mes = DateTime(mes.year, mes.month - 1);
    await cargarMes();
  }

  Future<void> mesSiguiente() async {
    if (!puedeIrAdelante) return;
    mes = DateTime(mes.year, mes.month + 1);
    await cargarMes();
  }

  void seleccionarFecha(String iso) {
    fechaSel = iso;
    horaSel = null;
    notifyListeners();
  }

  void seleccionarHora(String h) {
    horaSel = h;
    notifyListeners();
  }
}
