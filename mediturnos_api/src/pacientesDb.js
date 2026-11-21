'use strict';

/**
 * Crea o actualiza la ficha de un paciente (la clave es el DNI).
 * Si usuarioId es null NO toca el vínculo con la cuenta que ya tuviera.
 */
async function guardarFicha(c, d, usuarioId = null) {
  await c.query(
    `INSERT INTO pacientes
       (id_paciente, nombre, apellido, fechaNacimiento, domicilio, telefono,
        obraSocial, email, plan, nroAfiliado, usuarioID)
     VALUES (?,?,?,?,?,?,?,?,?,?,?) AS nueva
     ON DUPLICATE KEY UPDATE
       nombre = nueva.nombre, apellido = nueva.apellido,
       fechaNacimiento = nueva.fechaNacimiento, domicilio = nueva.domicilio,
       telefono = nueva.telefono, obraSocial = nueva.obraSocial,
       email = nueva.email, plan = nueva.plan, nroAfiliado = nueva.nroAfiliado,
       usuarioID = COALESCE(nueva.usuarioID, pacientes.usuarioID)`,
    [
      d.dni, d.nombre, d.apellido, d.fechaNacimiento, d.domicilio, d.telefono,
      d.obraSocial, d.email, d.plan, d.nroAfiliado, usuarioId,
    ]
  );
}

module.exports = { guardarFicha };
