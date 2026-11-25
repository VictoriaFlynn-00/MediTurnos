'use strict';
const { Router } = require('express');
const { pool, tx, esDuplicado } = require('../db');
const { autenticarOpcional } = require('../auth');
const { ApiError, E } = require('../errors');
const { pushConfigurado } = require('../avisos/push');

const r = Router();

function dispositivo(req) {
  if (req.user && (req.user.rol !== 'paciente' || !req.user.pacienteId)) throw E.prohibido();
  const { token, vinculo } = req.body ?? {};
  if (typeof token !== 'string' || !/^[\x21-\x7e]{30,512}$/.test(token)) {
    throw E.validacion('Token de notificaciones inválido');
  }
  if (typeof vinculo !== 'string' || !/^[a-f0-9]{32}$/.test(vinculo)) {
    throw E.validacion('Identificador de notificaciones inválido');
  }
  return { token, vinculo };
}

r.put('/dispositivos', autenticarOpcional, async (req, res) => {
  const { token, vinculo } = dispositivo(req);
  if (!pushConfigurado()) {
    throw new ApiError(503, 'PUSH_NO_CONFIGURADO', 'Notificaciones push no configuradas');
  }
  const paciente = req.user?.pacienteId ?? null;
  try {
    await tx(async (c) => {
      const [rows] = await c.execute(
        'SELECT paciente FROM aviso_dispositivos WHERE vinculo = ? FOR UPDATE',
        [vinculo]
      );
      if (!rows.length) {
        await c.execute(
          'INSERT INTO aviso_dispositivos (token, paciente, vinculo) VALUES (?, ?, ?)',
          [token, paciente, vinculo]
        );
        return;
      }
      const titular = rows[0].paciente;
      if (titular !== paciente) throw E.prohibido();
      await c.execute(
        'UPDATE aviso_dispositivos SET token = ?, actualizado_en = NOW() WHERE vinculo = ?',
        [token, vinculo]
      );
    });
  } catch (error) {
    if (!esDuplicado(error)) throw error;
    throw new ApiError(409, 'PUSH_REGISTRO_EXISTENTE', 'La instalación ya tiene un registro activo');
  }
  res.sendStatus(204);
});

r.delete('/dispositivos', autenticarOpcional, async (req, res) => {
  const { token, vinculo } = dispositivo(req);
  if (pushConfigurado()) {
    await pool.execute(
      'DELETE FROM aviso_dispositivos WHERE token = ? AND paciente <=> ? AND vinculo = ?',
      [token, req.user?.pacienteId ?? null, vinculo]
    );
  }
  res.sendStatus(204);
});

module.exports = r;
