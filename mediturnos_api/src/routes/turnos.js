'use strict';
const { Router } = require('express');
const { createHash } = require('node:crypto');
const { tx, esDuplicado } = require('../db');
const cfg = require('../config');
const { E } = require('../errors');
const { autenticar, autenticarOpcional, exigirDueno } = require('../auth');
const { guardarFicha } = require('../pacientesDb');
const { encolarConfirmacion, encolarConflicto, registrarFalloAviso } = require('../avisos/cola');
const { ahoraEn } = require('../pure/fechas');
const { atiende, esFuturo } = require('../pure/disponibilidad');
const V = require('../validar');

const r = Router();

function leerSlot(body) {
  return [V.entero(body?.especialistaId, 'Especialista'), V.fechaIso(body?.fecha), V.hora(body?.hora)];
}

function identificador(valor, campo) {
  if (typeof valor !== 'string' || !/^[a-f0-9]{64}$/.test(valor)) {
    throw E.validacion(`${campo} inválido`);
  }
  return valor;
}

function hashDe(token) {
  return createHash('sha256').update(identificador(token, 'Código de reserva')).digest();
}

function usuarioDeReserva(user) {
  if (!user) return null;
  if (user.rol !== 'paciente' || !user.dni) throw E.prohibido('Solo los pacientes pueden pedir turnos');
  return user.id;
}

function vinculoDeOrigen(req) {
  const vinculo = req.body?.avisoVinculo;
  return typeof vinculo === 'string' && /^[a-f0-9]{32}$/.test(vinculo) ? vinculo : null;
}

async function avisarConflicto(e, { dni, avisoVinculo, operacionId }) {
  if (e.code === 'HORARIO_NO_DISPONIBLE' && avisoVinculo && operacionId) {
    await encolarConflicto({ dni, avisoVinculo, operacionId }).catch(registrarFalloAviso);
  }
}

// Las escrituras de un especialista comparten este bloqueo aun cuando todavía no exista el horario.
async function bloquearEspecialista(c, especialistaId) {
  const [ex] = await c.query(
    'SELECT 1 FROM especialistas WHERE id_especialista = ? FOR UPDATE', [especialistaId]
  );
  if (!ex.length) throw E.noEncontrado('Especialista inexistente');
}

async function validarHorario(c, [especialistaId, fecha, hora]) {
  const [horarios] = await c.query(
    `SELECT dia_semana, TIME_FORMAT(hora, '%H:%i') AS hora
       FROM horarios_atencion WHERE especialista = ?`,
    [especialistaId]
  );
  if (!atiende(horarios, fecha, hora) || !esFuturo(fecha, hora, ahoraEn(cfg.tz))) {
    throw E.horarioNoDisponible();
  }
}

async function leerReserva(c, slot) {
  const [rows] = await c.query(
    `SELECT token_hash, usuario_id, vence_en > UTC_TIMESTAMP(3) AS vigente,
            DATE_FORMAT(vence_en, '%Y-%m-%dT%H:%i:%s.%fZ') AS venceEn
       FROM reservas_turnos WHERE especialista = ? AND fecha = ? AND hora = ?`,
    slot
  );
  return rows[0];
}

function perteneceReserva(reserva, tokenHash, usuarioId) {
  return Boolean(tokenHash && reserva?.vigente && reserva.usuario_id === usuarioId &&
    reserva.token_hash.equals(tokenHash));
}

function borrarReserva(c, slot, tokenHash, usuarioId, exigirVigente = false) {
  return c.query(
    `DELETE FROM reservas_turnos
      WHERE especialista = ? AND fecha = ? AND hora = ? AND token_hash = ? AND usuario_id <=> ?
      ${exigirVigente ? 'AND vence_en > UTC_TIMESTAMP(3)' : ''}`,
    [...slot, tokenHash, usuarioId]
  );
}

async function leerTurnoActivo(c, slot) {
  const [rows] = await c.query(
    `SELECT id_turno, paciente, reserva_token_hash FROM turnos
      WHERE especialista = ? AND fecha = ? AND hora = ? AND slot_activo = 1`,
    slot
  );
  return rows[0];
}

// POST /api/turnos/reservas { especialistaId, fecha, hora, reservaToken }
r.post('/reservas', autenticarOpcional, async (req, res) => {
  const slot = leerSlot(req.body);
  const token = req.body?.reservaToken;
  const tokenHash = hashDe(token);
  const usuarioId = usuarioDeReserva(req.user);
  try {
    const { venceEn, repetida } = await tx(async (c) => {
      await bloquearEspecialista(c, slot[0]);
      await validarHorario(c, slot);
      if (await leerTurnoActivo(c, slot)) throw E.horarioNoDisponible();
      const reserva = await leerReserva(c, slot);
      if (perteneceReserva(reserva, tokenHash, usuarioId)) {
        return { venceEn: reserva.venceEn, repetida: true };
      }
      if (reserva?.vigente) throw E.horarioNoDisponible();

      await c.query('DELETE FROM reservas_turnos WHERE especialista = ? AND vence_en <= UTC_TIMESTAMP(3)', [slot[0]]);
      await c.query(
        `INSERT INTO reservas_turnos (especialista, fecha, hora, token_hash, usuario_id, vence_en)
         VALUES (?, ?, ?, ?, ?, UTC_TIMESTAMP(3) + INTERVAL 7 MINUTE)`,
        [...slot, tokenHash, usuarioId]
      );
      return { venceEn: (await leerReserva(c, slot)).venceEn, repetida: false };
    });
    res.status(repetida ? 200 : 201).json({ venceEn });
  } catch (e) {
    await avisarConflicto(e, { dni: req.user?.dni, avisoVinculo: vinculoDeOrigen(req), operacionId: token });
    throw e;
  }
});

// El código de reserva va en el cuerpo para que no aparezca en los logs de URL.
r.post('/reservas/liberar', autenticarOpcional, async (req, res) => {
  const slot = leerSlot(req.body);
  const tokenHash = hashDe(req.body?.reservaToken);
  const usuarioId = usuarioDeReserva(req.user);
  await tx(async (c) => {
    await bloquearEspecialista(c, slot[0]);
    await borrarReserva(c, slot, tokenHash, usuarioId);
  });
  res.status(204).end();
});

// POST /api/turnos   { especialistaId, fecha, hora, paciente }
// Con carnet (JWT): el turno es del paciente de la sesión.
// Sin carnet (invitado): se usa el paciente del cuerpo, salvo que ese DNI ya tenga cuenta.
r.post('/', autenticarOpcional, async (req, res) => {
  const slot = leerSlot(req.body);
  const [especialistaId, fecha, hora] = slot;
  const usuarioId = usuarioDeReserva(req.user);
  const datos = req.user && req.body?.paciente == null ? null : V.paciente(req.body?.paciente);
  const dni = req.user?.dni ?? datos.dni;
  if (datos && datos.dni !== dni) throw E.prohibido('El turno debe ser a nombre del paciente de la sesión');
  const tokenHash = req.body?.reservaToken == null ? null : hashDe(req.body.reservaToken);
  const reservaTentativa = req.body?.reservaTentativa === true;
  const operacionId = req.body?.operacionId == null ? null : identificador(req.body.operacionId, 'Operación');
  const avisoVinculo = vinculoDeOrigen(req);

  try {
    const { id, repetido } = await tx(async (c) => {
      await bloquearEspecialista(c, especialistaId);
      let pacienteExistente = false;
      if (!req.user) {
        const [p] = await c.query('SELECT usuarioID FROM pacientes WHERE id_paciente = ?', [dni]);
        pacienteExistente = Boolean(p[0]);
        if (pacienteExistente) await verificarFichaInvitada(c, dni);
      }

      const activo = await leerTurnoActivo(c, slot);
      if (activo) {
        if (String(activo.paciente) === dni && (!tokenHash || activo.reserva_token_hash?.equals(tokenHash))) {
          return { id: activo.id_turno, repetido: true };
        }
        throw E.horarioNoDisponible();
      }

      await validarHorario(c, slot);
      const reserva = await leerReserva(c, slot);
      const propia = perteneceReserva(reserva, tokenHash, usuarioId);
      // Si se perdió la respuesta al adquirir, aún se puede enviar como solicitud offline.
      if (!propia && (reserva?.vigente || (tokenHash && !reservaTentativa))) throw E.horarioNoDisponible();
      if (datos) {
        if (!datos.email) throw E.validacion('El correo electrónico es obligatorio para confirmar');
        await guardarFicha(c, datos, null);
        // Para un DNI nuevo, el upsert obtiene el bloqueo sin bloquear un hueco del índice.
        if (!req.user && !pacienteExistente) await verificarFichaInvitada(c, dni);
      }
      if (propia) {
        const [resultado] = await borrarReserva(c, slot, tokenHash, usuarioId, true);
        if (!resultado.affectedRows) throw E.horarioNoDisponible();
      }

      let id;
      try {
        const [ins] = await c.query(
          `INSERT INTO turnos (fecha, hora, paciente, especialista, reserva_token_hash)
           VALUES (?, ?, ?, ?, ?)`,
          [fecha, hora, dni, especialistaId, tokenHash]
        );
        id = ins.insertId;
      } catch (e) {
        if (!esDuplicado(e)) throw e;
        throw E.horarioNoDisponible();
      }
      await encolarConfirmacion(c, { turnoId: id, dni, avisoVinculo, autenticado: Boolean(req.user) });
      return { id, repetido: false };
    });
    res.status(repetido ? 200 : 201).json({ id });
  } catch (e) {
    await avisarConflicto(e, { dni: req.user?.dni, avisoVinculo, operacionId: operacionId ?? req.body?.reservaToken });
    throw e;
  }
});

async function verificarFichaInvitada(c, dni) {
  const [p] = await c.query('SELECT usuarioID FROM pacientes WHERE id_paciente = ? FOR UPDATE', [dni]);
  if (p[0]?.usuarioID) throw E.requiereLogin();
}

// PATCH /api/turnos/:id/cancelar
r.patch('/:id/cancelar', autenticar, async (req, res) => {
  const id = V.entero(req.params.id, 'Turno');
  await tx(async (c) => {
    const [rows] = await c.query('SELECT paciente, estado FROM turnos WHERE id_turno = ? FOR UPDATE', [id]);
    const t = rows[0];
    // Si el turno es de otro paciente respondemos "no existe" (no revelamos qué ids existen).
    if (!t) throw E.noEncontrado('El turno no existe');
    try {
      exigirDueno(req.user, String(t.paciente));
    } catch {
      throw E.noEncontrado('El turno no existe');
    }
    if (t.estado === 'cancelado') return; // cancelar dos veces no es error
    if (t.estado !== 'activo') throw E.estadoInvalido();
    await c.query("UPDATE turnos SET estado = 'cancelado' WHERE id_turno = ?", [id]);
  });
  res.json({ id, estado: 'cancelado' });
});

module.exports = r;
