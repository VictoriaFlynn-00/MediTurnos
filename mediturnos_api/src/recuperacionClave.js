'use strict';
const { createHash, randomBytes } = require('node:crypto');
const bcrypt = require('bcryptjs');
const { pool, tx } = require('./db');
const { E } = require('./errors');
const { sendMail } = require('./avisos/correo');

const MINUTOS_VALIDEZ = 20;
const hash = (s) => createHash('sha256').update(s).digest();
const codigoInvalido = () => E.validacion('El código es inválido o venció. Pedí uno nuevo.');

async function solicitarRecuperacion(usuarioODni) {
  const porDni = /^\d{7,8}$/.test(usuarioODni);
  const [[cuenta]] = await pool.query(
    `SELECT u.id_usuario
       FROM usuarios u JOIN pacientes p ON p.usuarioID = u.id_usuario
      WHERE u.rol = 'paciente' AND ${porDni ? 'p.id_paciente' : 'u.usuario'} = ?`,
    [porDni ? Number(usuarioODni) : usuarioODni]
  );
  if (!cuenta) return;

  const { id_usuario: id } = cuenta;
  const token = randomBytes(32).toString('base64url');
  const destinatario = await tx(async (c) => {
    const [[u]] = await c.query('SELECT id_usuario FROM usuarios WHERE id_usuario = ? FOR UPDATE', [id]);
    if (!u) return null;
    const [[p]] = await c.query('SELECT email FROM pacientes WHERE usuarioID = ?', [id]);
    if (!p?.email?.trim()) return null;

    const emailHash = hash(p.email);
    const [[reciente]] = await c.query(
      `SELECT 1 FROM recuperaciones_clave
        WHERE usuario_id = ? AND email_hash = ?
          AND creada_en > UTC_TIMESTAMP(6) - INTERVAL 1 MINUTE`,
      [id, emailHash]
    );
    if (reciente) return null;

    await c.query('DELETE FROM recuperaciones_clave WHERE usuario_id = ?', [id]);
    await c.query(
      `INSERT INTO recuperaciones_clave (usuario_id, token_hash, email_hash, creada_en, vence_en)
       VALUES (?, ?, ?, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6) + INTERVAL ${MINUTOS_VALIDEZ} MINUTE)`,
      [id, hash(token), emailHash]
    );
    return p.email.trim();
  });
  if (!destinatario) return;

  await sendMail({
    to: destinatario,
    subject: 'Recuperá tu contraseña de MediTurnos',
    text: `Copiá y pegá este código en la pantalla de recuperación de MediTurnos.\n\n${token}\n\nEl código vence en ${MINUTOS_VALIDEZ} minutos y podés usarlo una sola vez. Si no pediste recuperar tu contraseña, podés ignorar este correo.`,
  });
}

async function restablecerClave(token, password) {
  if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) throw codigoInvalido();
  const tokenHash = hash(token);
  const [[registro]] = await pool.query(
    `SELECT usuario_id FROM recuperaciones_clave
      WHERE token_hash = ? AND vence_en > UTC_TIMESTAMP(6)`,
    [tokenHash]
  );
  if (!registro) throw codigoInvalido();

  const passwordHash = await bcrypt.hash(password, 10);
  await tx(async (c) => {
    const { usuario_id: id } = registro;
    // Las solicitudes y el canje bloquean primero la misma cuenta.
    const [[u]] = await c.query('SELECT id_usuario FROM usuarios WHERE id_usuario = ? FOR UPDATE', [id]);
    if (!u) throw codigoInvalido();
    const [borrado] = await c.query(
      `DELETE r FROM recuperaciones_clave r JOIN pacientes p ON p.usuarioID = r.usuario_id
        WHERE r.usuario_id = ? AND r.token_hash = ? AND r.vence_en > UTC_TIMESTAMP(6)
          AND r.email_hash = UNHEX(SHA2(p.email, 256))`,
      [id, tokenHash]
    );
    if (borrado.affectedRows !== 1) throw codigoInvalido();
    await c.query('UPDATE usuarios SET contrasena_hash = ? WHERE id_usuario = ?', [passwordHash, id]);
    await c.query(
      `INSERT INTO versiones_sesion (usuario_id, version) VALUES (?, 1)
       ON DUPLICATE KEY UPDATE version = version + 1`,
      [id]
    );
  });
}

module.exports = { solicitarRecuperacion, restablecerClave };
