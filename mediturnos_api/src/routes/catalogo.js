'use strict';
const { Router } = require('express');
const { pool } = require('../db');
const cfg = require('../config');
const { E } = require('../errors');
const V = require('../validar');
const { ahoraEn, isoDe, diasDelMes } = require('../pure/fechas');
const { calcularDisponibilidad } = require('../pure/disponibilidad');

const r = Router();

// GET /api/especialidades
r.get('/especialidades', async (req, res) => {
  const [rows] = await pool.query(
    'SELECT id_especialidad AS id, nombre FROM especialidades ORDER BY nombre'
  );
  res.json(rows);
});

// GET /api/especialistas
r.get('/especialistas', async (req, res) => {
  const [rows] = await pool.query(
    `SELECT e.id_especialista AS id, e.prefijo, e.nombre, e.apellido,
            e.especialidad AS especialidadId, s.nombre AS especialidad
       FROM especialistas e
       JOIN especialidades s ON s.id_especialidad = e.especialidad
      ORDER BY e.apellido, e.nombre`
  );
  res.json(rows);
});

// GET /api/especialistas/:id/disponibilidad?anio=2026&mes=11&detalle=1
r.get('/especialistas/:id/disponibilidad', async (req, res) => {
  const id = V.entero(req.params.id, 'Especialista');
  const anio = V.entero(req.query.anio, 'Año');
  const mes = V.entero(req.query.mes, 'Mes');
  if (mes > 12 || anio < 2000 || anio > 2100) throw E.validacion('Mes o año fuera de rango');

  const [ex] = await pool.query('SELECT 1 FROM especialistas WHERE id_especialista = ?', [id]);
  if (!ex.length) throw E.noEncontrado('Especialista inexistente');

  const [horarios] = await pool.query(
    `SELECT dia_semana, TIME_FORMAT(hora, '%H:%i') AS hora
       FROM horarios_atencion WHERE especialista = ?`,
    [id]
  );
  const rango = [id, isoDe(anio, mes, 1), isoDe(anio, mes, diasDelMes(anio, mes))];
  const [tomados] = await pool.query(
    `SELECT fecha, TIME_FORMAT(hora, '%H:%i') AS hora
       FROM turnos
      WHERE especialista = ? AND estado = 'activo' AND fecha BETWEEN ? AND ?
      UNION
     SELECT fecha, TIME_FORMAT(hora, '%H:%i') AS hora
       FROM reservas_turnos
      WHERE especialista = ? AND fecha BETWEEN ? AND ? AND vence_en > UTC_TIMESTAMP(3)`,
    [...rango, ...rango]
  );
  const ocupados = new Set(tomados.map((t) => `${t.fecha} ${t.hora}`));
  res.json(calcularDisponibilidad({
    anio, mes, horarios, ocupados, ahora: ahoraEn(cfg.tz), detalle: req.query.detalle === '1',
  }));
});

module.exports = r;
