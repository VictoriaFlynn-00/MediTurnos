'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = 'x'.repeat(40);
process.env.DB_HOST = 'h';
process.env.DB_USER = 'u';
process.env.DB_NAME = 'd';
process.env.SENDGRID_API_KEY = 'clave-de-prueba';
process.env.CORREO_REMITENTE = 'MediTurnos <avisos@example.test>';
delete process.env.FCM_SERVICE_ACCOUNT_JSON;

const { sendMail } = require('../src/avisos/correo');
const { mensajePush } = require('../src/avisos/push');
const { textoConfirmacion } = require('../src/avisos/cola');
const { eventoTurno } = require('../src/avisos/calendario');

test('SendGrid recibe el remitente verificado y los datos de la cita', async (t) => {
  const fetch = t.mock.method(globalThis, 'fetch', async () => new Response(null, { status: 202 }));
  const turno = { id: 12, profesional: 'Dra. Pérez', especialidad: 'Clínica', fecha: '2030-01-07', hora: '09:00' };
  const envio = {
    to: 'paciente@example.test',
    subject: 'Confirmación de turno en MediTurnos',
    evento: eventoTurno(turno),
    text: textoConfirmacion(turno, eventoTurno(turno)),
  };
  await sendMail(envio);
  const [url, pedido] = fetch.mock.calls[0].arguments;
  assert.equal(url, 'https://api.sendgrid.com/v3/mail/send');
  assert.equal(pedido.headers.Authorization, 'Bearer clave-de-prueba');
  const carta = JSON.parse(pedido.body);
  assert.equal(carta.subject, envio.subject);
  assert.deepEqual(carta.from, { name: 'MediTurnos', email: 'avisos@example.test' });
  assert.deepEqual(carta.personalizations, [{ to: [{ email: envio.to }] }]);
  assert.equal(carta.content[0].type, 'text/plain');
  for (const dato of ['#12', '07/01/2030', '09:00', 'Dra. Pérez', 'Clínica']) {
    assert.ok(carta.content[0].value.includes(dato));
  }
  const calendario = new URL(carta.content[0].value.split('\n').at(-1));
  assert.equal(calendario.origin, 'https://calendar.google.com');
  assert.equal(calendario.searchParams.get('dates'), '20300107T120000Z/20300107T123000Z');
  const [adjunto] = carta.attachments;
  assert.equal(adjunto.filename, 'turno.ics');
  assert.equal(adjunto.type, 'text/calendar');
  const lineas = Buffer.from(adjunto.content, 'base64').toString('utf8').split('\r\n');
  for (const campo of ['METHOD:REQUEST', 'DTSTART:20300107T120000Z', 'DTEND:20300107T123000Z',
    'ORGANIZER:mailto:avisos@example.test', 'ATTENDEE;PARTSTAT=NEEDS-ACTION:mailto:paciente@example.test',
    'UID:turno-12@mediturnos-app-production.up.railway.app', 'END:VCALENDAR']) {
    assert.ok(lineas.includes(campo), campo);
  }
  assert.equal(calendario.searchParams.get('ctz'), 'America/Argentina/Buenos_Aires');
});

test('FCM distingue los dos estados y transmite solo identificadores opacos', () => {
  const datos = {
    token: 'fcm-de-prueba',
    aviso: 'a'.repeat(64),
    vinculo: 'b'.repeat(32),
    dni: '99123456',
    profesional: 'Dra. Pérez',
  };
  const confirmacion = mensajePush({ ...datos, tipo: 'confirmacion' });
  const conflicto = mensajePush({ ...datos, tipo: 'conflicto' });
  assert.match(confirmacion.notification.body, /guardó/i);
  assert.match(conflicto.notification.body, /no está disponible/i);
  assert.deepEqual(Object.keys(conflicto.data).sort(), ['aviso', 'tipo', 'vinculo']);
  assert.equal(conflicto.android.notification.tag, datos.aviso);
  assert.equal(conflicto.apns.headers['apns-collapse-id'], datos.aviso);
  assert.equal(conflicto.android.notification.visibility, 'PRIVATE');
  assert.doesNotMatch(JSON.stringify(conflicto), /99123456|Pérez/);
});

test('el correo reintenta límites explícitos y evita duplicar un envío incierto', async (t) => {
  const envio = { to: 'prueba@example.test', subject: 'Recuperación', text: 'Código de prueba' };
  const mock = t.mock.method(globalThis, 'fetch', async () => new Response(null, {
    status: 429, headers: { 'Retry-After': '120' },
  }));
  await assert.rejects(sendMail(envio), { code: 'CORREO_429', reintentar: true, esperarSegundos: 120 });
  mock.mock.mockImplementation(async () => { throw new Error('Timeout'); });
  await assert.rejects(sendMail(envio), { code: 'CORREO_RESULTADO_INCIERTO', reintentar: false });
});
