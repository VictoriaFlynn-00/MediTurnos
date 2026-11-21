'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const Module = require('node:module');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'x'.repeat(40);
process.env.DB_HOST = 'h';
process.env.DB_USER = 'u';
process.env.DB_NAME = 'd';

const usuario = { id: 1, nombre: 'usuario_demo', dni: 34123456, email: 'titular@example.test' };
const hash = (s) => createHash('sha256').update(s).digest();
const correos = [];
const rutas = new Map();
let registro;
let clave = 'bcrypt:clave-anterior';
let version = null;
let tarea;

const db = {
  pool: {
    async query(sql, [param]) {
      if (sql.includes('SELECT s.version FROM usuarios')) {
        return [param === usuario.id ? [{ version }] : []];
      }
      if (sql.includes('u.contrasena_hash')) {
        return [param === usuario.nombre ? [{
          id_usuario: usuario.id, usuario: usuario.nombre, contrasena_hash: clave, rol: 'paciente', version,
        }] : []];
      }
      if (sql.startsWith('SELECT * FROM pacientes')) {
        assert.equal(param, usuario.id);
        return [[{ id_paciente: usuario.dni, email: usuario.email, usuarioID: usuario.id }]];
      }
      if (sql.includes('FROM usuarios WHERE usuario')) {
        return [param.toLowerCase() === usuario.nombre ? [{ id_usuario: usuario.id }] : []];
      }
      if (sql.includes('FROM usuarios u JOIN pacientes')) {
        return [[usuario.nombre, usuario.dni].includes(param) ? [{ id_usuario: usuario.id }] : []];
      }
      if (sql.includes('SELECT usuario_id FROM recuperaciones_clave')) {
        return [registro?.token.equals(param) && !registro.vencido ? [{ usuario_id: usuario.id }] : []];
      }
      throw new Error(`Consulta no simulada: ${sql}`);
    },
  },
  async tx(fn) {
    return fn({
      async query(sql, params) {
        assert.equal(params[0], sql.startsWith('UPDATE usuarios') ? claveEsperada : usuario.id);
        if (sql.startsWith('SELECT id_usuario')) return [[{ id_usuario: usuario.id }]];
        if (sql.startsWith('SELECT email')) return [[{ email: usuario.email }]];
        if (sql.startsWith('SELECT 1')) return [registro?.reciente ? [{ '1': 1 }] : []];
        if (sql.startsWith('DELETE FROM')) { registro = undefined; return [{}]; }
        if (sql.startsWith('INSERT INTO recuperaciones_clave')) {
          registro = { token: params[1], email: params[2], reciente: true, vencido: false };
          return [{}];
        }
        if (sql.startsWith('DELETE r FROM')) {
          if (!registro?.token.equals(params[1]) || registro.vencido || !registro.email.equals(hash(usuario.email))) {
            return [{ affectedRows: 0 }];
          }
          registro = undefined;
          return [{ affectedRows: 1 }];
        }
        if (sql.startsWith('UPDATE usuarios')) { clave = params[0]; return [{}]; }
        if (sql.startsWith('INSERT INTO versiones_sesion')) { version = (version ?? 0) + 1; return [{}]; }
        throw new Error(`Consulta no simulada: ${sql}`);
      },
    });
  },
};

const claveNueva = 'clave-numero-2468';
const claveEsperada = `bcrypt:${claveNueva}`;
const correo = {
  correoConfigurado: () => true,
  async sendMail(mensaje) { correos.push(mensaje); },
};
const bcrypt = {
  hashSync: () => '',
  hash: async (password) => `bcrypt:${password}`,
  compare: async (password, hash) => `bcrypt:${password}` === hash,
};
const original = Module._load;
Module._load = function (req, ...resto) {
  if (req === 'express') return { Router: () => ({ post: (ruta, fn) => rutas.set(ruta, fn) }) };
  if (req === '../db' || req === './db') return db;
  if (req === '../avisos/correo' || req === './avisos/correo') return correo;
  if (req === 'bcryptjs') return bcrypt;
  return original.call(this, req, ...resto);
};
const recuperacion = require('../src/recuperacionClave');
const solicitarReal = recuperacion.solicitarRecuperacion;
recuperacion.solicitarRecuperacion = (id) => { tarea = solicitarReal(id); return tarea; };
require('../src/routes/auth');
const { autenticar } = require('../src/auth');
Module._load = original;

async function llamar(ruta, body) {
  const res = {
    statusCode: 200,
    status(codigo) { this.statusCode = codigo; return this; },
    json(cuerpo) { this.cuerpo = cuerpo; return this; },
    end() {},
  };
  try {
    await rutas.get(ruta)({ body }, res);
    if (ruta === '/recuperacion') await tarea;
    return { status: res.statusCode, cuerpo: res.cuerpo };
  } catch (e) {
    if (!e.status) throw e;
    return { status: e.status, code: e.code };
  }
}

test('disponibilidad valida el nombre y detecta cuentas existentes antes del registro', async () => {
  assert.deepEqual(await llamar('/usuario-disponible', { usuario: 'nuevo_usuario' }), {
    status: 200, cuerpo: { disponible: true },
  });
  assert.deepEqual(await llamar('/usuario-disponible', { usuario: ' USUARIO_DEMO ' }), {
    status: 409, code: 'USUARIO_EXISTENTE',
  });
  assert.equal((await llamar('/usuario-disponible', { usuario: '123' })).status, 422);
});

test('el registro exige un correo para las cuentas nuevas', async () => {
  const datos = { usuario: 'nuevo_usuario', password: claveNueva, paciente: { dni: '45123456', nombre: 'Paciente' } };
  assert.equal((await llamar('/registro', datos)).status, 422);
  assert.equal((await llamar('/registro', { ...datos, paciente: { ...datos.paciente, email: 'invalido' } })).status, 422);
});

test('recupera por correo registrado y canjea cada código una sola vez', async () => {
  const jwtAnterior = jwt.sign({ rol: 'paciente', dni: String(usuario.dni) }, process.env.JWT_SECRET, {
    subject: String(usuario.id), algorithm: 'HS256', expiresIn: '1h',
  });
  async function validarSesion(token) {
    await autenticar({ headers: { authorization: `Bearer ${token}` } }, {}, () => {});
  }
  await validarSesion(jwtAnterior);
  const inicio = await llamar('/login', { usuario: usuario.nombre, password: 'clave-anterior' });
  await validarSesion(inicio.cuerpo.token);

  const desconocido = await llamar('/recuperacion', { usuario: 'cuenta_desconocida' });
  assert.equal(correos.length, 0);
  const existente = await llamar('/recuperacion', { usuario: String(usuario.dni), email: 'ajeno@example.test' });
  assert.deepEqual(existente, desconocido);
  assert.equal(existente.status, 202);
  assert.equal(correos[0].to, usuario.email);
  const codigo = correos[0].text.match(/^[A-Za-z0-9_-]{43}$/m)[0];
  assert.deepEqual(registro.token, hash(codigo));
  await llamar('/recuperacion', { usuario: usuario.nombre });
  assert.equal(correos.length, 1);

  const restablecer = (code) => llamar('/restablecer', { codigo: code, password: claveNueva });
  assert.equal((await restablecer('x'.repeat(43))).status, 422);
  registro.vencido = true;
  assert.equal((await restablecer(codigo)).status, 422);
  registro.vencido = false;
  const emailOriginal = usuario.email;
  usuario.email = 'actualizado@example.test';
  assert.equal((await restablecer(codigo)).status, 422);
  usuario.email = emailOriginal;
  assert.equal((await restablecer(codigo)).status, 204);
  assert.equal(clave, claveEsperada);
  assert.equal((await restablecer(codigo)).status, 422);
  await assert.rejects(validarSesion(jwtAnterior), { code: 'TOKEN_INVALIDO' });
  await assert.rejects(validarSesion(inicio.cuerpo.token), { code: 'TOKEN_INVALIDO' });
  assert.equal((await llamar('/login', { usuario: usuario.nombre, password: 'clave-anterior' })).status, 401);
  const nuevoInicio = await llamar('/login', { usuario: usuario.nombre, password: claveNueva });
  await validarSesion(nuevoInicio.cuerpo.token);
});
