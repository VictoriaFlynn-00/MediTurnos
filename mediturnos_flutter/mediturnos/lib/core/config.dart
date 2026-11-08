/// Configuración global.
/// Mientras el backend (Azure App Service + MySQL) no esté listo, la app usa
/// un servidor simulado en memoria (MockRemoteDataSource).
const bool kUsarMock = true;

/// URL base de la API REST en Azure (se usará cuando kUsarMock = false).
const String kApiBaseUrl = 'https://TU-APP.azurewebsites.net/api';
