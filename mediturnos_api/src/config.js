'use strict';

function requerida(nombre) {
  const v = process.env[nombre];
  if (!v) throw new Error(`Falta la variable de entorno ${nombre}`);
  return v;
}

const jwtSecret = requerida('JWT_SECRET');
if (jwtSecret.length < 32) {
  throw new Error('JWT_SECRET debe tener al menos 32 caracteres');
}

module.exports = {
  port: Number(process.env.PORT || 3000),
  tz: process.env.APP_TZ || 'America/Argentina/Buenos_Aires',
  jwtSecret,
  jwtHoras: Number(process.env.JWT_HORAS || 8),
  db: {
    host: requerida('DB_HOST'),
    port: Number(process.env.DB_PORT || 3306),
    user: requerida('DB_USER'),
    password: process.env.DB_PASSWORD || '',
    database: requerida('DB_NAME'),
    ssl: process.env.DB_SSL !== 'false', // por defecto SÍ usa TLS
    sslCa: process.env.DB_SSL_CA || null,
  },
};
