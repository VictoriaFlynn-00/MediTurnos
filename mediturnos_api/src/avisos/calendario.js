'use strict';
const { tz } = require('../config');
const { ahoraEn } = require('../pure/fechas');

const titulo = 'Turno médico · MediTurnos';
const marcaUTC = (fecha) => fecha.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');

function eventoTurno({ id, fecha, hora }) {
  const pared = Date.parse(`${fecha}T${hora}:00Z`);
  let instante = pared;
  // Convertir desde la hora de la clínica usando las reglas de su zona en esa fecha.
  for (let i = 0; i < 3; i++) {
    const local = ahoraEn(tz, new Date(instante));
    const ajuste = pared - Date.parse(`${local.fecha}T${local.hora}:00Z`);
    if (ajuste === 0) break;
    instante += ajuste;
  }
  return { id, inicio: marcaUTC(new Date(instante)), fin: marcaUTC(new Date(instante + 30 * 60_000)) };
}

function enlaceGoogleCalendar({ inicio, fin }) {
  const url = new URL('https://calendar.google.com/calendar/r/eventedit');
  url.search = new URLSearchParams({ action: 'TEMPLATE', text: titulo,
    dates: `${inicio}/${fin}`, ctz: tz, stz: tz, etz: tz }).toString();
  return url.href;
}

function adjuntoCalendario({ id, inicio, fin }, remitente, destinatario) {
  // Las líneas variables largas solo contienen URI mailto codificadas en ASCII.
  const mailto = (email) => 'mailto:' + encodeURIComponent(email).replace(/%40/g, '@');
  const lineas = [
    'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//MediTurnos//Turnos//ES', 'METHOD:REQUEST',
    'BEGIN:VEVENT', `UID:turno-${id}@mediturnos-app-production.up.railway.app`,
    `DTSTAMP:${marcaUTC(new Date())}`, `DTSTART:${inicio}`, `DTEND:${fin}`,
    `SUMMARY:${titulo}`, `ORGANIZER:${mailto(remitente)}`,
    `ATTENDEE;PARTSTAT=NEEDS-ACTION:${mailto(destinatario)}`,
    'SEQUENCE:0', 'STATUS:CONFIRMED', 'END:VEVENT', 'END:VCALENDAR',
  ];
  const contenido = lineas.map(linea => linea.replace(/(.{74})(?=.)/g, '$1\r\n ')).join('\r\n') + '\r\n';
  return { filename: 'turno.ics', type: 'text/calendar',
    disposition: 'attachment', content: Buffer.from(contenido, 'utf8').toString('base64') };
}

module.exports = { eventoTurno, enlaceGoogleCalendar, adjuntoCalendario };
