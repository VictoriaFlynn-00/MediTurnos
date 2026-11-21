'use strict';

/** Error "esperado": se convierte en una respuesta JSON {error, code}. */
class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const E = {
  validacion: (m) => new ApiError(422, 'VALIDACION', m),
  credenciales: () => new ApiError(401, 'CREDENCIALES_INVALIDAS', 'Usuario o contraseña incorrectos'),
  tokenInvalido: () => new ApiError(401, 'TOKEN_INVALIDO', 'Sesión inválida o vencida'),
  prohibido: (m = 'No tenés permiso para hacer esto') => new ApiError(403, 'PROHIBIDO', m),
  requiereLogin: () =>
    new ApiError(403, 'REQUIERE_LOGIN', 'Ese DNI tiene una cuenta: iniciá sesión para pedir el turno'),
  noEncontrado: (m = 'No encontrado') => new ApiError(404, 'NO_ENCONTRADO', m),
  horarioNoDisponible: () =>
    new ApiError(409, 'HORARIO_NO_DISPONIBLE', 'El horario ya no está disponible, elegí otro'),
  usuarioExistente: (m) => new ApiError(409, 'USUARIO_EXISTENTE', m),
  estadoInvalido: () => new ApiError(409, 'ESTADO_INVALIDO', 'El turno no se puede cancelar en su estado actual'),
};

function noEncontrada(req, res) {
  res.status(404).json({ error: 'Ruta inexistente', code: 'RUTA_INEXISTENTE' });
}

// Express reconoce un manejador de errores por tener 4 parámetros.
// eslint-disable-next-line no-unused-vars
function manejarErrores(err, req, res, next) {
  if (err instanceof ApiError) {
    return res.status(err.status).json({ error: err.message, code: err.code });
  }
  if (err && err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'JSON inválido', code: 'JSON_INVALIDO' });
  }
  if (err && err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Pedido demasiado grande', code: 'PEDIDO_GRANDE' });
  }
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor', code: 'ERROR_INTERNO' });
}

module.exports = { ApiError, E, noEncontrada, manejarErrores };
