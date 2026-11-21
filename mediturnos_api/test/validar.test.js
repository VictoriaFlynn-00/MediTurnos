'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const V = require('../src/validar');
const { ApiError } = require('../src/errors');

const falla = (fn) => assert.throws(fn, (e) => e instanceof ApiError && e.status === 422);

test('dni', () => {
  assert.equal(V.dni(' 34123456 '), '34123456');
  falla(() => V.dni('123'));
  falla(() => V.dni('12345678a'));
});

test('usuario no puede ser solo números (se confundiría con un DNI)', () => {
  assert.equal(V.usuario('camilaf_99'), 'camilaf_99');
  falla(() => V.usuario('34123456'));
  falla(() => V.usuario('ab'));
  falla(() => V.usuario("x'; DROP TABLE usuarios;--"));
});

test('password: entre 8 y 72 bytes', () => {
  assert.equal(V.password('12345678'), '12345678');
  falla(() => V.password('corta'));
  falla(() => V.password('a'.repeat(73)));
});

test('paciente normaliza: vacío -> null y exige nombre', () => {
  const p = V.paciente({ dni: '40111222', nombre: ' Lucía ', apellido: 'Gómez', telefono: '', fechaNacimiento: '2001-03-02' });
  assert.equal(p.nombre, 'Lucía');
  assert.equal(p.telefono, null);
  assert.equal(p.fechaNacimiento, '2001-03-02');
  falla(() => V.paciente({ dni: '40111222', nombre: '' }));
  falla(() => V.paciente({ dni: '40111222', nombre: 'Ana', email: 'no-es-un-mail' }));
  falla(() => V.paciente({ dni: '40111222', nombre: 'Ana', fechaNacimiento: '2001-13-40' }));
  falla(() => V.paciente(null));
});

test('fechaIso y hora', () => {
  assert.equal(V.fechaIso('2026-11-10'), '2026-11-10');
  assert.equal(V.hora('09:30'), '09:30');
  falla(() => V.fechaIso('2026-02-31'));
  falla(() => V.hora('9:30'));
  falla(() => V.hora('24:00'));
});
