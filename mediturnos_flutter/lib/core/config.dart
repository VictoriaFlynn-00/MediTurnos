/// Configuración global.
///
/// Por defecto la app usa la API de MediTurnos en Railway.
/// Para apuntar a otra API, indicá la URL al ejecutar:
///
///   flutter run --dart-define=API_URL=https://tu-api.example/api
///
/// Usá --dart-define=USAR_MOCK=true para el servidor simulado.
const bool kUsarMock = bool.fromEnvironment('USAR_MOCK', defaultValue: false);

/// Las instalaciones móviles con configuración de Firebase habilitan push al arrancar.
const bool kPushHabilitado = bool.fromEnvironment('PUSH_HABILITADO', defaultValue: true);

/// URL base de la API REST (termina en /api).
const String kApiBaseUrl =
    String.fromEnvironment('API_URL', defaultValue: 'https://mediturnos-app-production.up.railway.app/api');
