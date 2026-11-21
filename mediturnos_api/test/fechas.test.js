'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { ahoraEn, diaSemana, diasDelMes, esFechaIsoValida, isoDe } = require('../src/pure/fechas');

test('ahoraEn convierte de UTC a la zona de la clínica (UTC-3)', () => {
  const r = ahoraEn('America/Argentina/Buenos_Aires', new Date('2026-11-10T02:30:00Z'));
  assert.deepEqual(r, { fecha: '2026-11-09', hora: '23:30' });
});

test('ahoraEn no devuelve hora 24 a medianoche', () => {
  const r = ahoraEn('America/Argentina/Buenos_Aires', new Date('2026-11-10T03:05:00Z'));
  assert.deepEqual(r, { fecha: '2026-11-10', hora: '00:05' });
});

test('diaSemana: 1 = lunes ... 7 = domingo', () => {
  assert.equal(diaSemana('2026-11-09'), 1); // lunes
  assert.equal(diaSemana('2026-11-10'), 2); // martes
  assert.equal(diaSemana('2026-11-15'), 7); // domingo
});

test('diasDelMes e isoDe', () => {
  assert.equal(diasDelMes(2026, 2), 28);
  assert.equal(diasDelMes(2028, 2), 29);
  assert.equal(diasDelMes(2026, 11), 30);
  assert.equal(isoDe(2026, 3, 5), '2026-03-05');
});

test('esFechaIsoValida rechaza fechas imposibles', () => {
  assert.equal(esFechaIsoValida('2026-11-10'), true);
  assert.equal(esFechaIsoValida('2026-02-30'), false);
  assert.equal(esFechaIsoValida('10/11/2026'), false);
  assert.equal(esFechaIsoValida(null), false);
});
