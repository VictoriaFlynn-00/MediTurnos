'use strict';
const { diasDelMes, diaSemana, isoDe } = require('./fechas');

/**
 * Horarios de un mes, con opción de incluir todos los estados.
 * - horarios: [{ dia_semana: 1..7, hora: 'HH:mm' }]  (agenda semanal del médico)
 * - ocupados: Set de 'YYYY-MM-DD HH:mm' con turnos activos
 * - ahora:    { fecha: 'YYYY-MM-DD', hora: 'HH:mm' } en la zona de la clínica
 * Con detalle, cada horario indica su estado. Sin detalle, conserva la lista de horas libres.
 */
function calcularDisponibilidad({ anio, mes, horarios, ocupados, ahora, detalle = false }) {
  const porDia = new Map();
  for (const h of horarios) {
    if (!porDia.has(h.dia_semana)) porDia.set(h.dia_semana, []);
    porDia.get(h.dia_semana).push(h.hora);
  }
  for (const horas of porDia.values()) horas.sort();
  const salida = {};
  const n = diasDelMes(anio, mes);
  for (let d = 1; d <= n; d++) {
    const iso = isoDe(anio, mes, d);
    const horas = porDia.get(diaSemana(iso));
    if (!horas) continue;
    const estados = horas.map((hora) => ({
      hora,
      estado: !esFuturo(iso, hora, ahora) ? 'pasado' :
        ocupados.has(`${iso} ${hora}`) ? 'ocupado' : 'libre',
    }));
    const resultado = detalle ? estados : estados.filter((h) => h.estado === 'libre').map((h) => h.hora);
    if (resultado.length) salida[iso] = resultado;
  }
  return salida;
}

/** ¿El médico atiende ese día de la semana a esa hora? */
function atiende(horarios, fecha, hora) {
  const dia = diaSemana(fecha);
  return horarios.some((h) => h.dia_semana === dia && h.hora === hora);
}

function esFuturo(fecha, hora, ahora) {
  return fecha > ahora.fecha || (fecha === ahora.fecha && hora > ahora.hora);
}

module.exports = { calcularDisponibilidad, atiende, esFuturo };
