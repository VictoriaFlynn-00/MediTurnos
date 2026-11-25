'use strict';

/** Fila de MySQL -> JSON que espera Paciente.fromJson (Flutter). */
function pacienteAJson(r) {
  return {
    id: r.id_paciente,
    dni: r.dni,
    nombre: r.nombre,
    apellido: r.apellido ?? '',
    fechaNacimiento: r.fechaNacimiento ?? '',
    email: r.email ?? '',
    telefono: r.telefono ?? '',
    domicilio: r.domicilio ?? '',
    obraSocial: r.obraSocial ?? '',
    plan: r.plan ?? '',
    nroAfiliado: r.nroAfiliado ?? '',
    usuarioId: r.usuarioID ?? null,
  };
}

const hhmm = (t) => String(t).slice(0, 5);

function turnoAJson(r) {
  return {
    id: r.id,
    especialistaId: r.especialistaId,
    especialistaNombre: `${r.prefijo} ${r.nombre} ${r.apellido}`,
    especialidad: r.especialidad,
    fecha: r.fecha,
    hora: hhmm(r.hora),
    estado: r.estado,
  };
}

module.exports = { pacienteAJson, turnoAJson, hhmm };
