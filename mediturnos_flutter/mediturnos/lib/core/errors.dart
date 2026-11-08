class AppException implements Exception {
  final String mensaje;
  const AppException(this.mensaje);
  @override
  String toString() => mensaje;
}

class SinConexionException extends AppException {
  const SinConexionException([super.mensaje = 'Sin conexión a internet']);
}

class HorarioNoDisponibleException extends AppException {
  const HorarioNoDisponibleException(
      [super.mensaje = 'El horario ya no está disponible, elegí otro']);
}

class CredencialesInvalidasException extends AppException {
  const CredencialesInvalidasException(
      [super.mensaje = 'Usuario o contraseña incorrectos']);
}

class UsuarioExistenteException extends AppException {
  const UsuarioExistenteException(super.mensaje);
}

class ValidacionException extends AppException {
  const ValidacionException(super.mensaje);
}
