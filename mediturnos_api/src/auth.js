'use strict';
const jwt = require('jsonwebtoken');
const cfg = require('./config');
const { pool } = require('./db');
const { E } = require('./errors');

/** Emite el "carnet" (JWT). Lleva: id de usuario, rol y DNI (si es paciente). */
function firmar(usuario, dni) {
  return jwt.sign({ rol: usuario.rol, dni: dni ?? null, v: usuario.version ?? 0 }, cfg.jwtSecret, {
    algorithm: 'HS256',
    subject: String(usuario.id),
    expiresIn: `${cfg.jwtHoras}h`,
  });
}

async function leer(req) {
  const h = req.headers.authorization;
  if (!h) return null;
  const m = /^Bearer (.+)$/.exec(h);
  if (!m) throw E.tokenInvalido();
  let p;
  try {
    p = jwt.verify(m[1], cfg.jwtSecret, { algorithms: ['HS256'] });
  } catch {
    throw E.tokenInvalido();
  }
  const id = Number(p?.sub);
  if (!Number.isSafeInteger(id) || id <= 0) throw E.tokenInvalido();

  const [[sesion]] = await pool.query(
    `SELECT s.version FROM usuarios u
       LEFT JOIN versiones_sesion s ON s.usuario_id = u.id_usuario
      WHERE u.id_usuario = ?`,
    [id]
  );
  // Las cuentas y los JWT anteriores a la migración tienen versión inicial 0.
  if (!sesion || (sesion.version ?? 0) !== (p.v ?? 0)) throw E.tokenInvalido();
  return { id, rol: p.rol, dni: p.dni ?? null };
}

/** Exige carnet válido. */
async function autenticar(req, res, next) {
  const u = await leer(req);
  if (!u) throw E.tokenInvalido();
  req.user = u;
  next();
}

/** Deja pasar a invitados (sin carnet); si trae uno, tiene que ser válido. */
async function autenticarOpcional(req, res, next) {
  req.user = await leer(req);
  next();
}

/** El recurso tiene que ser del paciente que hace el pedido. */
function exigirDueno(user, dni) {
  if (!user || user.rol !== 'paciente' || user.dni !== dni) throw E.prohibido();
}

module.exports = { firmar, autenticar, autenticarOpcional, exigirDueno };
