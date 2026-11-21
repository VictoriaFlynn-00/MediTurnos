'use strict';
// Prueba el FLUJO de las rutas sin Express ni MySQL reales (se simulan).
// No verifica el SQL en sí: para eso hay que probar contra una base MySQL.
const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');

process.env.JWT_SECRET = 'x'.repeat(40);
process.env.DB_HOST = 'h';
process.env.DB_USER = 'u';
process.env.DB_NAME = 'd';

// ---- Base de datos simulada ----
const estado = { turnos: [], pacientes: new Map(), reservas: new Map(), sig: 1, ahora: Date.now() };
const avisos = { confirmaciones: [], conflictos: [] };
const FECHA = '2030-01-07'; // lunes
const conexion = {
  async query(sql, p = []) {
    if (/SELECT s.version FROM usuarios/.test(sql)) return [[{ version: null }]];
    if (/FROM especialistas WHERE id_especialista/.test(sql)) return [[{ 1: 1 }]];
    if (/FROM horarios_atencion/.test(sql)) return [[{ dia_semana: 1, hora: '09:00' }]];
    if (/SELECT usuarioID FROM pacientes/.test(sql)) {
      const pac = estado.pacientes.get(String(p[0]));
      return [pac ? [{ usuarioID: pac.usuarioID }] : []];
    }
    if (/INSERT INTO pacientes/.test(sql)) {
      if (!estado.pacientes.has(String(p[0]))) estado.pacientes.set(String(p[0]), { usuarioID: null });
      return [{}];
    }
    if (/INSERT INTO turnos/.test(sql)) {
      const [fecha, hora, paciente, esp, tokenHash] = p;
      if (estado.turnos.some((t) => t.estado === 'activo' && t.fecha === fecha && t.hora === hora && t.esp === esp)) {
        throw Object.assign(new Error('dup'), { code: 'ER_DUP_ENTRY' });
      }
      const t = { id: estado.sig++, fecha, hora, paciente: String(paciente), esp, estado: 'activo', tokenHash };
      estado.turnos.push(t);
      return [{ insertId: t.id }];
    }
    if (/SELECT id_turno, paciente, reserva_token_hash FROM turnos/.test(sql)) {
      const [esp, fecha, hora] = p;
      const t = estado.turnos.find((x) => x.esp === esp && x.fecha === fecha && x.hora === hora && x.estado === 'activo');
      return [t ? [{ id_turno: t.id, paciente: t.paciente, reserva_token_hash: t.tokenHash }] : []];
    }
    if (/SELECT token_hash, usuario_id/.test(sql)) {
      const r = estado.reservas.get(p.join('|'));
      return [r ? [{ token_hash: r.hash, usuario_id: r.usuario, vigente: r.vence > estado.ahora,
        venceEn: new Date(r.vence).toISOString() }] : []];
    }
    if (/INSERT INTO reservas_turnos/.test(sql)) {
      const [esp, fecha, hora, hash, usuario] = p;
      estado.reservas.set([esp, fecha, hora].join('|'), { hash, usuario, vence: estado.ahora + 420000 });
      return [{}];
    }
    if (/DELETE FROM reservas_turnos/.test(sql)) {
      if (p.length === 1) {
        for (const [clave, r] of estado.reservas) {
          if (clave.startsWith(`${p[0]}|`) && r.vence <= estado.ahora) estado.reservas.delete(clave);
        }
        return [{}];
      }
      const clave = p.slice(0, 3).join('|');
      const r = estado.reservas.get(clave);
      const propia = r?.hash.equals(p[3]) && r.usuario === p[4];
      const vigente = !/AND vence_en >/.test(sql) || r?.vence > estado.ahora;
      const borrada = propia && vigente && estado.reservas.delete(clave);
      return [{ affectedRows: borrada ? 1 : 0 }];
    }
    if (/SELECT paciente, estado FROM turnos/.test(sql)) {
      const t = estado.turnos.find((x) => x.id === p[0]);
      return [t ? [{ paciente: t.paciente, estado: t.estado }] : []];
    }
    if (/UPDATE turnos SET estado/.test(sql)) {
      estado.turnos.find((x) => x.id === p[0]).estado = 'cancelado';
      return [{}];
    }
    throw new Error('SQL no simulado: ' + sql);
  },
};
const fakeDb = {
  pool: conexion,
  tx: async (fn) => fn(conexion),
  esDuplicado: (e) => e && e.code === 'ER_DUP_ENTRY',
};

// ---- Express y librerías simuladas ----
const rutas = {};
const stubs = {
  express: { Router: () => {
    const r = {};
    for (const m of ['get', 'post', 'put', 'patch']) r[m] = (path, ...h) => { rutas[`${m.toUpperCase()} ${path}`] = h; };
    return r;
  } },
  jsonwebtoken: {
    sign: (payload, _s, o) => 'T.' + Buffer.from(JSON.stringify({ ...payload, sub: o.subject })).toString('base64'),
    verify: (t) => JSON.parse(Buffer.from(t.slice(2), 'base64').toString()),
  },
  bcryptjs: { hashSync: () => 'h', hash: async () => 'h', compare: async () => true },
  'express-rate-limit': () => (req, res, next) => next(),
  '../db': fakeDb,
  './db': fakeDb,
  '../avisos/cola': {
    encolarConfirmacion: async (_, aviso) => { avisos.confirmaciones.push(aviso); },
    encolarConflicto: async (aviso) => { avisos.conflictos.push(aviso); },
    registrarFalloAviso: () => {},
  },
};
const original = Module._load;
Module._load = function (req, ...resto) {
  return Object.hasOwn(stubs, req) ? stubs[req] : original.call(this, req, ...resto);
};
require('../src/routes/turnos');
Module._load = original;

// ---- Ayudas ----
const carnet = (dni) => 'Bearer T.' + Buffer.from(JSON.stringify({ rol: 'paciente', dni, sub: '1' })).toString('base64');
async function llamar(clave, { body, params, headers = {} } = {}) {
  const req = { body, params: params ?? {}, query: {}, headers };
  const res = { codigo: 200, json(x) { this.cuerpo = x; return this; }, status(c) { this.codigo = c; return this; }, end() {} };
  const hs = rutas[clave];
  try {
    for (let i = 0; i < hs.length; i++) {
      let siguio = false;
      await hs[i](req, res, () => { siguio = true; });
      if (!siguio) break;
    }
  } catch (e) {
    return { codigo: e.status ?? 500, code: e.code };
  }
  return { codigo: res.codigo, cuerpo: res.cuerpo };
}
const invitado = (dni) => ({ dni, nombre: 'Ana', apellido: 'Paz', email: 'ana@example.test' });
const pedido = (paciente) => ({ especialistaId: 1, fecha: FECHA, hora: '09:00', paciente });

test('pedir turno libre -> 201; mismo horario otro paciente -> 409', async () => {
  const a = await llamar('POST /', { body: pedido(invitado('40111222')) });
  assert.equal(a.codigo, 201);
  const b = await llamar('POST /', { body: pedido(invitado('40999888')) });
  assert.equal(b.codigo, 409);
  assert.equal(b.code, 'HORARIO_NO_DISPONIBLE');
});

test('reintento del MISMO paciente devuelve el mismo turno (idempotente)', async () => {
  const otra = { ...pedido(invitado('40111222')), hora: '09:00' };
  const r = await llamar('POST /', { body: otra });
  assert.equal(r.codigo, 200);
  assert.equal(r.cuerpo.id, 1);
});

test('invitado con DNI que ya tiene cuenta -> 403 REQUIERE_LOGIN', async () => {
  estado.pacientes.set('34123456', { usuarioID: 7 });
  const r = await llamar('POST /', { body: pedido(invitado('34123456')) });
  assert.equal(r.codigo, 403);
  assert.equal(r.code, 'REQUIERE_LOGIN');
});

test('con carnet no se puede pedir turno a nombre de otro DNI', async () => {
  const r = await llamar('POST /', { headers: { authorization: carnet('34123456') }, body: pedido(invitado('40111222')) });
  assert.equal(r.codigo, 403);
});

test('horario fuera de la agenda o en el pasado -> 409', async () => {
  const fueraDeAgenda = await llamar('POST /', { body: { ...pedido(invitado('40555666')), hora: '09:30' } });
  assert.equal(fueraDeAgenda.code, 'HORARIO_NO_DISPONIBLE');
  const pasado = await llamar('POST /', { body: { ...pedido(invitado('40555666')), fecha: '2020-01-06' } });
  assert.equal(pasado.code, 'HORARIO_NO_DISPONIBLE');
});

test('cancelar: sin carnet 401; ajeno 404; propio 200 (y repetir también); luego el horario se libera', async () => {
  assert.equal((await llamar('PATCH /:id/cancelar', { params: { id: '1' } })).codigo, 401);
  const ajeno = await llamar('PATCH /:id/cancelar', { params: { id: '1' }, headers: { authorization: carnet('34123456') } });
  assert.equal(ajeno.codigo, 404);
  const mio = { params: { id: '1' }, headers: { authorization: carnet('40111222') } };
  assert.equal((await llamar('PATCH /:id/cancelar', mio)).codigo, 200);
  assert.equal((await llamar('PATCH /:id/cancelar', mio)).codigo, 200);
  const nuevo = await llamar('POST /', { body: pedido(invitado('40999888')) });
  assert.equal(nuevo.codigo, 201); // el horario cancelado se pudo volver a reservar
});

const reservar = (body) => llamar('POST /reservas', { body });
const liberar = (body) => llamar('POST /reservas/liberar', { body });
const confirmar = (body) => llamar('POST /', { body });
const candidato = (fecha, reservaToken, extras = {}) => ({
  ...pedido(invitado('40555666')), fecha, reservaToken, ...extras,
});

test('una retención aparta el horario y su reintento conserva el vencimiento', async () => {
  const a = candidato('2030-01-14', 'a'.repeat(64));
  const b = candidato(a.fecha, 'b'.repeat(64), { avisoVinculo: '1'.repeat(32) });
  const inicial = await reservar(a);
  assert.equal(inicial.codigo, 201);
  assert.equal(Date.parse(inicial.cuerpo.venceEn) - estado.ahora, 7 * 60 * 1000);
  estado.ahora += 1000;
  assert.deepEqual(await reservar(a), { codigo: 200, cuerpo: inicial.cuerpo });
  assert.equal((await reservar(b)).codigo, 409);
  assert.equal(avisos.conflictos.at(-1).operacionId, b.reservaToken);
  assert.equal((await liberar(b)).codigo, 204);
  assert.equal((await confirmar({ ...b, reservaToken: undefined })).codigo, 409);
  const confirmacionesPrevias = avisos.confirmaciones.length;
  const turno = await confirmar(a);
  assert.equal(turno.codigo, 201);
  estado.ahora += 7 * 60 * 1000;
  assert.deepEqual(await confirmar(a), { codigo: 200, cuerpo: turno.cuerpo });
  assert.equal(avisos.confirmaciones.length, confirmacionesPrevias + 1);
});

test('proteger reservas de sesión y liberar al cancelar o vencer', async () => {
  const a = candidato('2030-01-21', 'c'.repeat(64));
  const b = candidato(a.fecha, 'd'.repeat(64));
  const sesion = { headers: { authorization: carnet(a.paciente.dni) }, body: a };
  assert.equal((await llamar('POST /reservas', sesion)).codigo, 201);
  await liberar(a);
  assert.equal((await reservar(b)).codigo, 409);
  assert.equal((await llamar('POST /reservas/liberar', sesion)).codigo, 204);
  assert.equal((await reservar(b)).codigo, 201);
  estado.ahora += 7 * 60 * 1000;
  assert.equal((await confirmar(b)).codigo, 409);
  assert.equal((await reservar(a)).codigo, 201);
  assert.equal((await confirmar(a)).codigo, 201);
});

test('una solicitud tentativa se valida online, aunque nunca se haya creado la retención', async () => {
  const a = candidato('2030-01-28', 'e'.repeat(64));
  assert.equal((await confirmar(a)).codigo, 409);
  assert.equal((await confirmar({ ...a, reservaTentativa: true })).codigo, 201);
});
