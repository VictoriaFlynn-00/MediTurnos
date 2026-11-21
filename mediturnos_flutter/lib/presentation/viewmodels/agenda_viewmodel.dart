import 'dart:async';

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
    _actualizacion = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!reservando && !cargando) unawaited(_actualizarMes());
    });
  }
  final Especialista especialista;
  final ConsultarDisponibilidadUseCase _disp;
  late final Timer _actualizacion;
  int _consulta = 0;

  late DateTime mes;
  Disponibilidad disp = const Disponibilidad();
  bool cargando = false;
  bool reservando = false;
  String? error;
  String? fechaSel; // yyyy-MM-dd
  String? horaSel;

  DateTime? get fechaSeleccionada =>
      fechaSel == null ? null : Fechas.parse(fechaSel!);
  List<HorarioAgenda> get horarios => fechaSel == null ? const [] : disp.horariosDe(fechaSel!);

  bool get puedeIrAtras {
    final h = Fechas.hoy();
    return !cargando && !reservando && mes.isAfter(DateTime(h.year, h.month));
  }

  bool get puedeIrAdelante {
    final h = Fechas.hoy();
    return !cargando && !reservando && mes.isBefore(DateTime(h.year, h.month + 3));
  }

  Future<void> cargarMes({bool conservarFecha = false}) async {
    ++_consulta;
    cargando = true;
    error = null;
    if (!conservarFecha) fechaSel = null;
    horaSel = null;
    notifyListeners();
    try {
      disp = await _disp(especialista.id, mes.year, mes.month);
      _ajustarSeleccion();
    } on AppException catch (e) {
      error = e.mensaje;
      disp = const Disponibilidad();
      fechaSel = null;
    }
    cargando = false;
    notifyListeners();
  }

  Future<void> _actualizarMes() async {
    final consulta = ++_consulta;
    try {
      final reciente = await _disp(especialista.id, mes.year, mes.month);
      if (muerto || reservando || consulta != _consulta) return;
      disp = reciente;
      error = null;
      _ajustarSeleccion();
      notifyListeners();
    } on AppException {
      // La próxima actualización vuelve a intentar sin vaciar la agenda.
    }
  }

  void _ajustarSeleccion() {
    if (fechaSel != null && !disp.tieneDia(fechaSel!)) fechaSel = null;
    if (!horarios.any((h) => h.hora == horaSel && h.libre)) horaSel = null;
  }

  @override
  void dispose() {
    _actualizacion.cancel();
    super.dispose();
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
    if (cargando || reservando || !disp.tieneDia(iso)) return;
    fechaSel = iso;
    horaSel = null;
    notifyListeners();
  }

  void seleccionarHora(String h) {
    if (cargando || reservando || !horarios.any((s) => s.hora == h && s.libre)) return;
    horaSel = h;
    notifyListeners();
  }

  void cambiarReserva(bool valor) {
    reservando = valor;
    notifyListeners();
  }
}
