'use strict';
const { Router } = require('express');
const { pool } = require('../db');
const { E } = require('../errors');
const { autenticar, autenticarOpcional, exigirDueno } = require('../auth');
const { busqueda } = require('../limites');
const { pacienteAJson, turnoAJson } = require('../mappers');
const V = require('../validar');

const r = Router();

// GET /api/pacientes/:dni  -> ficha (para autocompletar el registro)
r.get('/:dni', busqueda, autenticarOpcional, async (req, res) => {
  const dni = V.dni(req.params.dni);
  const [rows] = await pool.query('SELECT * FROM pacientes WHERE id_paciente = ?', [dni]);
  const p = rows[0];
  if (!p) throw E.noEncontrado('No hay un paciente con ese DNI');
  // De quien ya tiene cuenta no se exponen datos personales a desconocidos.
  if (p.usuarioID && req.user?.dni !== dni) return res.json({ dni, usuarioId: p.usuarioID });
  res.json(pacienteAJson(p));
});

// PUT /api/pacientes/:dni  -> editar mi ficha
r.put('/:dni', autenticar, async (req, res) => {
  const dni = V.dni(req.params.dni);
  exigirDueno(req.user, dni);
  const d = V.paciente({ ...req.body, dni });
  await pool.query(
    `UPDATE pacientes
        SET nombre = ?, apellido = ?, fechaNacimiento = ?, domicilio = ?, telefono = ?,
            obraSocial = ?, email = ?, plan = ?, nroAfiliado = ?
      WHERE id_paciente = ?`,
    [d.nombre, d.apellido, d.fechaNacimiento, d.domicilio, d.telefono, d.obraSocial,
     d.email, d.plan, d.nroAfiliado, dni]
  );
  const [rows] = await pool.query('SELECT * FROM pacientes WHERE id_paciente = ?', [dni]);
  if (!rows[0]) throw E.noEncontrado('Paciente inexistente');
  res.json(pacienteAJson(rows[0]));
});

// GET /api/pacientes/:dni/turnos  -> mi historial
r.get('/:dni/turnos', autenticar, async (req, res) => {
  const dni = V.dni(req.params.dni);
  exigirDueno(req.user, dni);
  const [rows] = await pool.query(
    `SELECT t.id_turno AS id, t.fecha, t.hora, t.estado,
            e.id_especialista AS especialistaId, e.prefijo, e.nombre, e.apellido,
            s.nombre AS especialidad
       FROM turnos t
       JOIN especialistas e ON e.id_especialista = t.especialista
       JOIN especialidades s ON s.id_especialidad = e.especialidad
      WHERE t.paciente = ?
      ORDER BY t.fecha DESC, t.hora DESC`,
    [dni]
  );
  res.json(rows.map(turnoAJson));
});

module.exports = r;
