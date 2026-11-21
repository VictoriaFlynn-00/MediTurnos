'use strict';
const rateLimit = require('express-rate-limit');

// Azure App Service a veces manda la IP como "1.2.3.4:5678": le sacamos el puerto.
const keyGenerator = (req) => (req.ip || 'desconocida').replace(/^(\d{1,3}(?:\.\d{1,3}){3}):\d+$/, '$1');

const base = {
  windowMs: 15 * 60 * 1000,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator,
  message: { error: 'Demasiados intentos, esperá unos minutos', code: 'DEMASIADOS_INTENTOS' },
};

module.exports = {
  general: rateLimit({ ...base, limit: 600 }),
  // login y registro: frenan los intentos de adivinar contraseñas
  auth: rateLimit({ ...base, limit: 30 }),
  // buscar un paciente por DNI: frena el "barrido" de DNIs
  busqueda: rateLimit({ ...base, limit: 40 }),
};
