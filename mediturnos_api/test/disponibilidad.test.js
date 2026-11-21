'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { calcularDisponibilidad, atiende, esFuturo } = require('../src/pure/disponibilidad');

const ahora = { fecha: '2026-11-10', hora: '12:00' }; // martes

test('solo lista días de atención futuros y descuenta los turnos tomados', () => {
  const horarios = [
    { dia_semana: 1, hora: '09:00' },
    { dia_semana: 1, hora: '10:00' },
  ];
  const ocupados = new Set(['2026-11-16 09:00']);
  const r = calcularDisponibilidad({ anio: 2026, mes: 11, horarios, ocupados, ahora });
  assert.deepEqual(Object.keys(r), ['2026-11-16', '2026-11-23', '2026-11-30']); // 2 y 9 ya pasaron
  assert.deepEqual(r['2026-11-16'], ['10:00']);
  assert.deepEqual(r['2026-11-23'], ['09:00', '10:00']);
});

test('hoy solo quedan los horarios que todavía no pasaron', () => {
  const horarios = [
    { dia_semana: 2, hora: '09:00' },
    { dia_semana: 2, hora: '15:30' },
  ];
  const r = calcularDisponibilidad({ anio: 2026, mes: 11, horarios, ocupados: new Set(), ahora });
  assert.deepEqual(r['2026-11-10'], ['15:30']);
});

test('un día sin horarios libres no aparece', () => {
  const horarios = [{ dia_semana: 2, hora: '15:30' }];
  const ocupados = new Set(['2026-11-10 15:30']);
  const r = calcularDisponibilidad({ anio: 2026, mes: 11, horarios, ocupados, ahora });
  assert.equal('2026-11-10' in r, false);
  assert.equal('2026-11-17' in r, true);
});

test('el detalle conserva horarios pasados, ocupados y libres de cualquier día de atención', () => {
  const horarios = ['09:00', '15:30', '16:00'].map((hora) => ({ dia_semana: 2, hora }));
  const ocupados = new Set(['2026-11-10 15:30']);
  const r = calcularDisponibilidad({ anio: 2026, mes: 11, horarios, ocupados, ahora, detalle: true });
  assert.deepEqual(r['2026-11-10'], [
    { hora: '09:00', estado: 'pasado' },
    { hora: '15:30', estado: 'ocupado' },
    { hora: '16:00', estado: 'libre' },
  ]);
  assert.ok(r['2026-11-03'].every((h) => h.estado === 'pasado'));
  assert.equal('2026-11-11' in r, false);
});

test('atiende y esFuturo', () => {
  const horarios = [{ dia_semana: 1, hora: '09:00' }];
  assert.equal(atiende(horarios, '2026-11-16', '09:00'), true); // lunes
  assert.equal(atiende(horarios, '2026-11-17', '09:00'), false); // martes
  assert.equal(atiende(horarios, '2026-11-16', '09:30'), false);
  assert.equal(esFuturo('2026-11-10', '12:01', ahora), true);
  assert.equal(esFuturo('2026-11-10', '12:00', ahora), false);
  assert.equal(esFuturo('2026-11-09', '23:00', ahora), false);
});
