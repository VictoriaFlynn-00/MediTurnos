import '../../core/di.dart';
import '../../core/safe_notifier.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';

enum FiltroInicio { misMedicos, profesionales, especialidades }

class InicioViewModel extends SafeNotifier {
  InicioViewModel(this._di, this._paciente);
  final Di _di;
  final Paciente? Function() _paciente;

  List<Especialista> todos = [];
  List<Especialidad> especialidades = [];
  Set<int> misMedicosIds = {};
  bool cargando = false;
  String query = '';
  int? especialidadId;
  late FiltroInicio filtro =
      _paciente() != null ? FiltroInicio.misMedicos : FiltroInicio.profesionales;

  bool get esRegistrado => _paciente() != null;

  Future<void> cargar() async {
    cargando = true;
    notifyListeners();
    todos = await _di.especialistas();
    especialidades = await _di.especialidades();
    final p = _paciente();
    if (p != null) {
      final turnos = await _di.historial(p.dni);
      misMedicosIds = turnos.map((t) => t.especialistaId).toSet();
    }
    cargando = false;
    notifyListeners();
  }

  void setFiltro(FiltroInicio f) {
    filtro = f;
    if (f != FiltroInicio.profesionales) especialidadId = null;
    notifyListeners();
  }

  void setQuery(String q) {
    query = q.trim().toLowerCase();
    notifyListeners();
  }

  void filtrarPorEspecialidad(int id) {
    especialidadId = id;
    filtro = FiltroInicio.profesionales;
    notifyListeners();
  }

  void quitarFiltroEspecialidad() {
    especialidadId = null;
    notifyListeners();
  }

  int contar(int espId) => todos.where((e) => e.especialidadId == espId).length;

  List<Especialista> get profesionales {
    Iterable<Especialista> l = todos;
    if (filtro == FiltroInicio.misMedicos) {
      l = l.where((e) => misMedicosIds.contains(e.id));
    }
    if (especialidadId != null) {
      l = l.where((e) => e.especialidadId == especialidadId);
    }
    if (query.isNotEmpty) {
      l = l.where((e) =>
          e.nombreCompleto.toLowerCase().contains(query) ||
          e.especialidad.toLowerCase().contains(query));
    }
    return l.toList();
  }

  List<Especialidad> get especialidadesFiltradas => query.isEmpty
      ? especialidades
      : especialidades.where((e) => e.nombre.toLowerCase().contains(query)).toList();
}
