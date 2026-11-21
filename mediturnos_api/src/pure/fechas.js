'use strict';

/** Fecha y hora "de pared" en una zona horaria (Azure corre en UTC). */
function ahoraEn(tz, d = new Date()) {
  const p = {};
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(d);
  for (const x of partes) p[x.type] = x.value;
  return { fecha: `${p.year}-${p.month}-${p.day}`, hora: `${p.hour}:${p.minute}` };
}

const dos = (n) => String(n).padStart(2, '0');
const isoDe = (y, m, d) => `${String(y).padStart(4, '0')}-${dos(m)}-${dos(d)}`;

function diasDelMes(anio, mes) {
  return new Date(Date.UTC(anio, mes, 0)).getUTCDate();
}

/** 1 = lunes ... 7 = domingo (igual que DateTime.weekday de Dart). */
function diaSemana(iso) {
  const [y, m, d] = iso.split('-').map(Number);
  const w = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return w === 0 ? 7 : w;
}

function esFechaIsoValida(s) {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const [y, m, d] = s.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d;
}

module.exports = { ahoraEn, isoDe, diasDelMes, diaSemana, esFechaIsoValida };
