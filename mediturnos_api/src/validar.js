'use strict';
const { E } = require('./errors');
const { esFechaIsoValida } = require('./pure/fechas');

const DNI = /^\d{7,8}$/;
const HORA = /^([01]\d|2[0-3]):[0-5]\d$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// Empieza con letra: así un usuario nunca se confunde con un DNI al iniciar sesión.
const USUARIO = /^[A-Za-z][A-Za-z0-9._-]{2,29}$/;

function dni(v) {
  const s = String(v ?? '').trim();
  if (!DNI.test(s)) throw E.validacion('El DNI debe tener 7 u 8 dígitos');
  return s;
}

function entero(v, campo) {
  const n = Number(v);
  if (!Number.isInteger(n) || n <= 0) throw E.validacion(`${campo} inválido`);
  return n;
}

function fechaIso(v) {
  const s = String(v ?? '');
  if (!esFechaIsoValida(s)) throw E.validacion('Fecha inválida (usar AAAA-MM-DD)');
  return s;
}

function hora(v) {
  const s = String(v ?? '');
  if (!HORA.test(s)) throw E.validacion('Hora inválida (usar HH:mm)');
  return s;
}

function usuario(v) {
  const s = String(v ?? '').trim();
  if (!USUARIO.test(s)) {
    throw E.validacion(
      'El usuario debe empezar con una letra y tener de 3 a 30 caracteres (letras, números, . _ -)'
    );
  }
  return s;
}

function password(v) {
  const s = String(v ?? '');
  if (s.length < 8 || Buffer.byteLength(s) > 72) {
    throw E.validacion('La contraseña debe tener entre 8 y 72 caracteres');
  }
  return s;
}

function paciente(b) {
  if (!b || typeof b !== 'object') throw E.validacion('Faltan los datos del paciente');
  const t = (v, max, campo, obligatorio = false) => {
    const s = v == null ? '' : String(v).trim();
    if (obligatorio && !s) throw E.validacion(`${campo} es obligatorio`);
    if (s.length > max) throw E.validacion(`${campo} es demasiado largo`);
    return s;
  };
  const email = t(b.email, 150, 'El email');
  if (email && !EMAIL.test(email)) throw E.validacion('El email no es válido');
  const nac = t(b.fechaNacimiento, 10, 'La fecha de nacimiento');
  if (nac && !esFechaIsoValida(nac)) throw E.validacion('Fecha de nacimiento inválida');
  return {
    dni: dni(b.dni),
    nombre: t(b.nombre, 100, 'El nombre', true),
    apellido: t(b.apellido, 100, 'El apellido'),
    fechaNacimiento: nac || null,
    email: email || null,
    telefono: t(b.telefono, 20, 'El teléfono') || null,
    domicilio: t(b.domicilio, 200, 'El domicilio') || null,
    obraSocial: t(b.obraSocial, 100, 'La obra social') || null,
    plan: t(b.plan, 50, 'El plan') || null,
    nroAfiliado: t(b.nroAfiliado, 50, 'El nro. de afiliado') || null,
  };
}

module.exports = { dni, entero, fechaIso, hora, usuario, password, paciente };
