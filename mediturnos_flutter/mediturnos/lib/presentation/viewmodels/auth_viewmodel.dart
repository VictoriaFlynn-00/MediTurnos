import '../../core/di.dart';
import '../../core/errors.dart';
import '../../core/safe_notifier.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/session.dart';

class AuthViewModel extends SafeNotifier {
  AuthViewModel(this._di);
  final Di _di;

  Session? session;
  bool invitado = false;
  bool restaurando = true;
  bool cargando = false;
  String? error;

  bool get autenticado => session != null;
  Paciente? get paciente => session?.paciente;
  bool get hayAcceso => autenticado || invitado;

  Future<void> restaurar() async {
    try {
      session = await _di.restaurarSesion();
    } catch (_) {
      session = null;
    }
    restaurando = false;
    notifyListeners();
  }

  Future<T?> _ejecutar<T>(Future<T> Function() op) async {
    cargando = true;
    error = null;
    notifyListeners();
    try {
      return await op();
    } on AppException catch (e) {
      error = e.mensaje;
    } catch (_) {
      error = 'Ocurrió un error inesperado. Intentá de nuevo.';
    } finally {
      cargando = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> iniciarSesion(String usuario, String password) async {
    final s = await _ejecutar(() => _di.iniciarSesion(usuario, password));
    if (s == null) return false;
    if (s.usuario.rol != Rol.paciente) {
      await _di.cerrarSesion();
      error = 'El panel para este rol estará disponible en una próxima versión.';
      notifyListeners();
      return false;
    }
    session = s;
    invitado = false;
    notifyListeners();
    return true;
  }

  Future<bool> registrar(String usuario, String password, Paciente datos) async {
    final s = await _ejecutar(() =>
        _di.registrarPaciente(usuario: usuario, password: password, datos: datos));
    if (s == null) return false;
    session = s;
    invitado = false;
    notifyListeners();
    return true;
  }

  Future<Paciente?> buscarPorDni(String dni) =>
      _ejecutar<Paciente?>(() => _di.buscarPaciente(dni));

  Future<bool> guardarPerfil(Paciente p) async {
    final nuevo = await _ejecutar(() => _di.actualizarPerfil(p));
    if (nuevo == null) return false;
    final s = session!;
    session = Session(token: s.token, usuario: s.usuario, paciente: nuevo);
    notifyListeners();
    return true;
  }

  void continuarComoInvitado() {
    invitado = true;
    error = null;
    notifyListeners();
  }

  void limpiarError() {
    error = null;
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    if (autenticado) await _di.cerrarSesion();
    session = null;
    invitado = false;
    error = null;
    notifyListeners();
  }
}
