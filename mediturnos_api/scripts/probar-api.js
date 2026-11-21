#!/usr/bin/env node
'use strict';
/*
 * Prueba de punta a punta de la API de MediTurnos (registro, login, turnos,
 * doble reserva, reintentos, permisos, cancelación).
 *
 *   node scripts/probar-api.js                       -> http://localhost:3000/api
 *   node scripts/probar-api.js https://TU-APP.azurewebsites.net/api
 *
 * Deja datos de prueba: usuarios "test_..." y DNI 9xxxxxxx. Para borrarlos, mirá el README.
 */
const BASE = (process.argv[2] || 'http://localhost:3000/api').replace(/\/$/, '');
let bien = 0;
let mal = 0;

function chequear(nombre, condicion, detalle = '') {
  if (condicion) {
    bien++;
    console.log(`  ✔ ${nombre}`);
  } else {
    mal++;
    console.log(`  ✖ ${nombre}${detalle ? `  →  ${detalle}` : ''}`);
  }
  return condicion;
}

async function http(metodo, ruta, { token, body } = {}) {
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const r = await fetch(BASE + ruta, {
    method: metodo,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(20000),
  });
  let json = null;
  try {
    json = await r.json();
  } catch {
    /* sin cuerpo JSON */
  }
  return { status: r.status, json };
}

const detalle = (r) => `status ${r.status} ${JSON.stringify(r.json)}`;
const titulo = (t) => console.log(`\n${t}`);
const dniAleatorio = () => String(90000000 + Math.floor(Math.random() * 9999999));
const sufijo = Date.now().toString(36);
const PASSWORD = 'Prueba12345';

function pac(dni, extra = {}) {
  return { dni, nombre: 'Paciente', apellido: 'Prueba', email: 'prueba@ejemplo.com', ...extra };
}

async function main() {
  console.log(`Probando la API en ${BASE}`);

  titulo('1. ¿La API y la base están vivas?');
  let r;
  try {
    r = await http('GET', '/health');
  } catch (e) {
    console.log(`  ✖ No se pudo conectar a ${BASE}: ${e.message}`);
    console.log('    ¿Está corriendo "npm run dev"? ¿La URL es correcta?');
    process.exit(1);
  }
  if (!chequear('GET /health responde {ok:true} (la API llega a MySQL)', r.status === 200 && r.json?.ok === true, detalle(r))) {
    console.log('    Mirá la consola de la API: ahí aparece el error de conexión a MySQL.');
    process.exit(1);
  }

  titulo('2. Catálogo');
  const esps = await http('GET', '/especialistas');
  const espec = await http('GET', '/especialidades');
  chequear('GET /especialidades devuelve datos', Array.isArray(espec.json) && espec.json.length > 0, 'vacío: ¿cargaste sql/02_datos_demo.sql?');
  chequear('GET /especialistas devuelve datos', Array.isArray(esps.json) && esps.json.length > 0, 'vacío: ¿cargaste sql/02_datos_demo.sql?');
  if (!Array.isArray(esps.json) || esps.json.length === 0) process.exit(1);

  titulo('3. Disponibilidad (busco un horario libre del mes que viene)');
  const hoy = new Date();
  const objetivo = new Date(hoy.getFullYear(), hoy.getMonth() + 1, 1);
  const anio = objetivo.getFullYear();
  const mes = objetivo.getMonth() + 1;
  let esp = null;
  let fecha = null;
  let hora = null;
  for (const e of esps.json) {
    const d = await http('GET', `/especialistas/${e.id}/disponibilidad?anio=${anio}&mes=${mes}`);
    const dias = d.json ? Object.keys(d.json).sort() : [];
    if (d.status === 200 && dias.length) {
      esp = e;
      fecha = dias[dias.length - 1];
      hora = d.json[fecha][d.json[fecha].length - 1];
      break;
    }
  }
  if (!chequear('hay al menos un horario libre', Boolean(esp), 'sin horarios: ¿cargaste horarios_atencion (02_datos_demo.sql)?')) process.exit(1);
  console.log(`    usaré: ${esp.prefijo} ${esp.nombre} ${esp.apellido} · ${fecha} · ${hora}`);
  const libre = async () => {
    const d = await http('GET', `/especialistas/${esp.id}/disponibilidad?anio=${anio}&mes=${mes}`);
    return (d.json?.[fecha] ?? []).includes(hora);
  };

  titulo('4. Registro y login');
  const dniA = dniAleatorio();
  let dniB = dniAleatorio();
  while (dniB === dniA) dniB = dniAleatorio();
  let dniC = dniAleatorio();
  while (dniC === dniA || dniC === dniB) dniC = dniAleatorio();
  const userA = `test_a_${sufijo}`;
  const userB = `test_b_${sufijo}`;

  r = await http('POST', '/auth/registro', { body: { usuario: userA, password: PASSWORD, paciente: pac(dniA) } });
  chequear('registro del paciente A → 201 con token', r.status === 201 && Boolean(r.json?.token) && r.json?.paciente?.dni === dniA, detalle(r));
  const tokenA = r.json?.token;

  r = await http('POST', '/auth/registro', { body: { usuario: `otro_${sufijo}`, password: PASSWORD, paciente: pac(dniA) } });
  chequear('registrar el mismo DNI otra vez → 409 USUARIO_EXISTENTE', r.status === 409 && r.json?.code === 'USUARIO_EXISTENTE', detalle(r));

  r = await http('POST', '/auth/login', { body: { usuario: userA, password: PASSWORD } });
  chequear('login con usuario → 200', r.status === 200 && Boolean(r.json?.token), detalle(r));
  r = await http('POST', '/auth/login', { body: { usuario: dniA, password: PASSWORD } });
  chequear('login con DNI → 200', r.status === 200 && Boolean(r.json?.token), detalle(r));
  r = await http('POST', '/auth/login', { body: { usuario: userA, password: 'incorrecta1' } });
  chequear('contraseña incorrecta → 401 CREDENCIALES_INVALIDAS', r.status === 401 && r.json?.code === 'CREDENCIALES_INVALIDAS', detalle(r));

  r = await http('POST', '/auth/registro', { body: { usuario: userB, password: PASSWORD, paciente: pac(dniB) } });
  chequear('registro del paciente B → 201', r.status === 201, detalle(r));
  const tokenB = r.json?.token;

  titulo('5. Pedir turno y anti doble reserva');
  const pedido = { especialistaId: esp.id, fecha, hora };
  r = await http('POST', '/turnos', { token: tokenA, body: pedido });
  chequear('A pide el turno → 201 con id', r.status === 201 && Number.isInteger(r.json?.id), detalle(r));
  const idTurno = r.json?.id;

  r = await http('POST', '/turnos', { token: tokenA, body: pedido });
  chequear('A repite el mismo pedido (reintento) → 200 y el MISMO id', r.status === 200 && r.json?.id === idTurno, detalle(r));

  r = await http('POST', '/turnos', { body: { ...pedido, paciente: pac(dniC) } });
  chequear('un invitado pide el mismo horario → 409 HORARIO_NO_DISPONIBLE', r.status === 409 && r.json?.code === 'HORARIO_NO_DISPONIBLE', detalle(r));

  r = await http('POST', '/turnos', { body: { ...pedido, hora: '03:33', paciente: pac(dniC) } });
  chequear('hora fuera de la agenda del médico → 409', r.status === 409 && r.json?.code === 'HORARIO_NO_DISPONIBLE', detalle(r));

  r = await http('POST', '/turnos', { body: { ...pedido, paciente: pac(dniA) } });
  chequear('invitado con el DNI de una cuenta → 403 REQUIERE_LOGIN', r.status === 403 && r.json?.code === 'REQUIERE_LOGIN', detalle(r));

  chequear('el horario ya no figura como libre', !(await libre()));

  titulo('6. Historial y permisos');
  r = await http('GET', `/pacientes/${dniA}/turnos`, { token: tokenA });
  const mio = Array.isArray(r.json) ? r.json.find((t) => t.id === idTurno) : null;
  chequear('A ve su turno en el historial, estado "activo"', r.status === 200 && mio?.estado === 'activo' && mio?.hora === hora && mio?.fecha === fecha, detalle(r));

  r = await http('GET', `/pacientes/${dniA}/turnos`);
  chequear('sin token → 401', r.status === 401, detalle(r));
  r = await http('GET', `/pacientes/${dniA}/turnos`, { token: tokenB });
  chequear('B no puede ver los turnos de A → 403', r.status === 403, detalle(r));
  r = await http('PATCH', `/turnos/${idTurno}/cancelar`, { token: tokenB });
  chequear('B no puede cancelar el turno de A → 404', r.status === 404, detalle(r));
  r = await http('PATCH', `/turnos/${idTurno}/cancelar`);
  chequear('cancelar sin token → 401', r.status === 401, detalle(r));

  titulo('7. Cancelar');
  r = await http('PATCH', `/turnos/${idTurno}/cancelar`, { token: tokenA });
  chequear('A cancela su turno → 200', r.status === 200 && r.json?.estado === 'cancelado', detalle(r));
  r = await http('PATCH', `/turnos/${idTurno}/cancelar`, { token: tokenA });
  chequear('cancelar de nuevo no es error → 200', r.status === 200, detalle(r));
  chequear('el horario cancelado vuelve a estar libre', await libre());

  titulo('8. Perfil');
  r = await http('PUT', `/pacientes/${dniA}`, { token: tokenA, body: { nombre: 'Ana', apellido: 'Prueba', telefono: '385 000 0000' } });
  chequear('A edita su perfil → 200 con los datos nuevos', r.status === 200 && r.json?.nombre === 'Ana' && r.json?.telefono === '385 000 0000', detalle(r));
  r = await http('PUT', `/pacientes/${dniA}`, { token: tokenB, body: { nombre: 'Hackeado' } });
  chequear('B no puede editar el perfil de A → 403', r.status === 403, detalle(r));

  console.log(`\nResultado: ${bien} bien, ${mal} mal.`);
  if (mal === 0) console.log('Todo en orden ✔');
  else console.log('Hay pruebas que fallaron ✖  (mirá los detalles de arriba y la consola de la API)');
  process.exit(mal === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error('Error inesperado:', e);
  process.exit(1);
});
