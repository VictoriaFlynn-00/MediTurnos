'use strict';

/**
 * Crea o actualiza la ficha de un paciente (MySQL asigna el ID; el DNI único permite encontrar la ficha).
 * Si usuarioId es null NO toca el vínculo con la cuenta que ya tuviera.
 */
async function guardarFicha(c, d, usuarioId = null) {
  const [result] = await c.query(
    `INSERT INTO pacientes
       (dni, nombre, apellido, fechaNacimiento, domicilio, telefono,
        obraSocial, email, plan, nroAfiliado, usuarioID)
     VALUES (?,?,?,?,?,?,?,?,?,?,?) AS nueva
     ON DUPLICATE KEY UPDATE
       id_paciente = LAST_INSERT_ID(pacientes.id_paciente),
       nombre = nueva.nombre, apellido = nueva.apellido,
       fechaNacimiento = nueva.fechaNacimiento, domicilio = nueva.domicilio,
       telefono = nueva.telefono, obraSocial = nueva.obraSocial,
       email = nueva.email, plan = nueva.plan, nroAfiliado = nueva.nroAfiliado,
       usuarioID = COALESCE(pacientes.usuarioID, nueva.usuarioID)`,
    [
      d.dni, d.nombre, d.apellido, d.fechaNacimiento, d.domicilio, d.telefono,
      d.obraSocial, d.email, d.plan, d.nroAfiliado, usuarioId,
    ]
  );
  return result.insertId;
}

module.exports = { guardarFicha };
