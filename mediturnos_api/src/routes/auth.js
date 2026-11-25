'use strict';
const { Router } = require('express');
const bcrypt = require('bcryptjs');
const { pool, tx, esDuplicado } = require('../db');
const { ApiError, E } = require('../errors');
const { firmar } = require('../auth');
const { pacienteAJson } = require('../mappers');
const { guardarFicha } = require('../pacientesDb');
const { correoConfigurado } = require('../avisos/correo');
const { solicitarRecuperacion, restablecerClave } = require('../recuperacionClave');
const V = require('../validar');

const r = Router();

// Se compara contra este hash cuando el usuario no existe, para que
// "usuario inexistente" y "clave incorrecta" tarden lo mismo.
const HASH_FALSO = bcrypt.hashSync('no-existe-este-usuario', 10);

function sesion(u, p) {
  return {
    token: firmar({ id: u.id_usuario, rol: u.rol, version: u.version }),
    usuario: { id: u.id_usuario, usuario: u.usuario, rol: u.rol },
    paciente: p ? pacienteAJson(p) : null,
  };
}

// POST /api/auth/login   { usuario, password }   (usuario puede ser el DNI)
r.post('/login', async (req, res) => {
  const q = String(req.body?.usuario ?? '').trim();
  const pass = String(req.body?.password ?? '');
  if (!q || !pass || pass.length > 200) throw E.credenciales();

  const dni = /^\d{7,8}$/.test(q) ? V.dni(q) : null;
  const [rows] = await pool.query(
    `SELECT u.id_usuario, u.usuario, u.contrasena_hash, u.rol, s.version
       FROM usuarios u
       LEFT JOIN pacientes p ON p.usuarioID = u.id_usuario
       LEFT JOIN versiones_sesion s ON s.usuario_id = u.id_usuario
      WHERE u.usuario = ? OR p.dni = ?
      LIMIT 1`,
    [q, dni]
  );
  const u = rows[0];
  const ok = await bcrypt.compare(pass, u ? u.contrasena_hash : HASH_FALSO);
  if (!u || !ok) throw E.credenciales();

  const [pac] = await pool.query('SELECT * FROM pacientes WHERE usuarioID = ?', [u.id_usuario]);
  res.json(sesion(u, pac[0] ?? null));
});

// POST /api/auth/usuario-disponible   { usuario }
r.post('/usuario-disponible', async (req, res) => {
  const usuario = V.usuario(req.body?.usuario);
  const [rows] = await pool.query('SELECT id_usuario FROM usuarios WHERE usuario = ? LIMIT 1', [usuario]);
  if (rows.length) throw E.usuarioExistente('Ese nombre de usuario ya está en uso');
  res.json({ disponible: true });
});

// POST /api/auth/recuperacion   { usuario }
r.post('/recuperacion', (req, res) => {
  const usuario = typeof req.body?.usuario === 'string' ? req.body.usuario.trim() : '';
  if (!usuario || usuario.length > 100) throw E.validacion('Ingresá tu usuario o DNI');
  if (!correoConfigurado()) {
    throw new ApiError(503, 'CORREO_NO_DISPONIBLE', 'La recuperación por correo no está disponible en este momento');
  }

  // La respuesta no depende de la existencia de la cuenta ni del envío del correo.
  res.status(202).json({ ok: true });
  void solicitarRecuperacion(usuario).catch(() => {
    console.error('No se pudo procesar una solicitud de recuperación de contraseña');
  });
});

// POST /api/auth/restablecer   { codigo, password }
r.post('/restablecer', async (req, res) => {
  const pass = V.password(req.body?.password);
  await restablecerClave(req.body?.codigo, pass);
  res.status(204).end();
});

// POST /api/auth/registro   { usuario, password, paciente: {...} }
r.post('/registro', async (req, res) => {
  const usuario = V.usuario(req.body?.usuario);
  const pass = V.password(req.body?.password);
  const datos = V.paciente(req.body?.paciente);
  if (!datos.email) throw E.validacion('Ingresá un correo electrónico válido');
  const hash = await bcrypt.hash(pass, 10);

  const nueva = await tx(async (c) => {
    // Bloquea la fila del DNI para que dos registros simultáneos no se pisen.
    const [ex] = await c.query('SELECT usuarioID FROM pacientes WHERE dni = ? FOR UPDATE', [
      datos.dni,
    ]);
    if (ex[0]?.usuarioID) throw E.usuarioExistente('Ese DNI ya tiene un usuario registrado');

    let idUsuario;
    try {
      const [ins] = await c.query(
        "INSERT INTO usuarios (usuario, contrasena_hash, rol) VALUES (?, ?, 'paciente')",
        [usuario, hash]
      );
      idUsuario = ins.insertId;
    } catch (e) {
      if (esDuplicado(e)) throw E.usuarioExistente('Ese nombre de usuario ya está en uso');
      throw e;
    }
    await guardarFicha(c, datos, idUsuario);
    const [pac] = await c.query('SELECT * FROM pacientes WHERE dni = ?', [datos.dni]);
    if (pac[0]?.usuarioID !== idUsuario) throw E.usuarioExistente('Ese DNI ya tiene un usuario registrado');
    return sesion({ id_usuario: idUsuario, usuario, rol: 'paciente' }, pac[0]);
  });
  res.status(201).json(nueva);
});

module.exports = r;
