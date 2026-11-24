'use strict';
const { createHash } = require('node:crypto');
const { pool, tx, esDuplicado } = require('../db');
const { correoConfigurado, sendMail } = require('./correo');
const { pushConfigurado, enviarPush } = require('./push');
const { eventoTurno, enlaceGoogleCalendar } = require('./calendario');

const maxIntentos = 6;
const huella = (s) => createHash('sha256').update(s).digest('hex');

function registrarFalloAviso(error) {
  // Los errores del proveedor/SQL pueden contener destinatarios o credenciales.
  console.error('Falló un aviso de MediTurnos', error?.code || error?.name || 'ERROR');
}

async function insertarEvento(c, clave, tipo, turno = null) {
  try {
    await c.execute('INSERT INTO aviso_eventos (clave, tipo, turno) VALUES (?, ?, ?)', [clave, tipo, turno]);
    return true;
  } catch (error) {
    if (esDuplicado(error)) return false;
    throw error;
  }
}

async function encolarPush(c, evento, dni, avisoVinculo) {
  if (!avisoVinculo) return;
  await c.execute(
    "INSERT INTO aviso_entregas (evento, canal, vinculo, paciente_destino) VALUES (?, 'push', ?, ?)",
    [evento, avisoVinculo, dni ?? null]
  );
}

/** Se llama dentro de la transacción que crea un nuevo turno. */
async function encolarConfirmacion(c, { turnoId, dni, avisoVinculo, autenticado }) {
  const correo = correoConfigurado();
  const push = pushConfigurado();
  if (!correo && !push) return;

  const clave = huella(`confirmacion:${turnoId}`);
  if (!(await insertarEvento(c, clave, 'confirmacion', turnoId))) return;
  if (correo) {
    await c.execute(
      `INSERT INTO aviso_entregas (evento, canal, email)
         SELECT ?, 'correo', TRIM(email) FROM pacientes
          WHERE id_paciente = ? AND NULLIF(TRIM(email), '') IS NOT NULL`,
      [clave, dni]
    );
  }
  if (push) await encolarPush(c, clave, autenticado ? dni : null, avisoVinculo);
}

/** Se llama después de revertir el turno que falló en la sincronización. */
async function encolarConflicto({ dni, avisoVinculo, operacionId }) {
  if (!pushConfigurado() || !avisoVinculo) return;
  const origen = dni ? `paciente:${dni}` : `invitado:${avisoVinculo}`;
  const clave = huella(`conflicto:${origen}:${operacionId}`);
  await tx(async (c) => {
    if (await insertarEvento(c, clave, 'conflicto')) await encolarPush(c, clave, dni, avisoVinculo);
  });
}

async function tomarEntrega(canal) {
  return tx(async (c) => {
    const [rows] = await c.execute(
      `SELECT id_entrega AS id, evento, canal, email, dispositivo, vinculo, paciente_destino, estado, intentos
         FROM aviso_entregas
        WHERE canal = ? AND estado IN ('pendiente', 'en_curso') AND proximo_intento <= NOW()
        ORDER BY proximo_intento, id_entrega LIMIT 1 FOR UPDATE SKIP LOCKED`,
      [canal]
    );
    const entrega = rows[0];
    if (!entrega) return null;

    if (entrega.intentos >= maxIntentos || entrega.estado === 'en_curso') {
      // Tras una caída, no se puede distinguir un aviso ya aceptado de uno sin enviar.
      await c.execute(
        "UPDATE aviso_entregas SET estado = 'fallido', email = NULL WHERE id_entrega = ?",
        [entrega.id]
      );
      return null;
    }
    await c.execute(
      `UPDATE aviso_entregas
          SET estado = 'en_curso', intentos = intentos + 1,
              proximo_intento = DATE_ADD(NOW(), INTERVAL 60 SECOND)
        WHERE id_entrega = ?`,
      [entrega.id]
    );
    entrega.intentos += 1;
    return entrega;
  });
}

function textoConfirmacion({ id, profesional, especialidad, fecha, hora }, evento) {
  const [anio, mes, dia] = fecha.split('-');
  return [
    'Tu turno en MediTurnos está confirmado.',
    '',
    `Turno: #${id}`,
    `Profesional: ${profesional}`,
    ...(especialidad ? [`Especialidad: ${especialidad}`] : []),
    `Fecha: ${dia}/${mes}/${anio}`,
    `Hora: ${hora} (hora local del centro médico)`,
    '',
    'Podés consultar el estado de tu turno en MediTurnos.',
    '',
    'Para agendar los 30 minutos, aceptá la invitación del correo o abrí el archivo turno.ics y guardá el evento.',
    'También podés abrir el evento en Google Calendar desde tu navegador:',
    enlaceGoogleCalendar(evento),
  ].join('\n');
}

async function entregarCorreo(entrega) {
  const [rows] = await pool.execute(
    `SELECT t.id_turno AS id, t.fecha, TIME_FORMAT(t.hora, '%H:%i') AS hora,
            CONCAT_WS(' ', e.prefijo, e.nombre, e.apellido) AS profesional, s.nombre AS especialidad
       FROM aviso_eventos a JOIN turnos t ON t.id_turno = a.turno
       JOIN especialistas e ON e.id_especialista = t.especialista
       LEFT JOIN especialidades s ON s.id_especialidad = e.especialidad
      WHERE a.clave = ? AND t.estado = 'activo'
        AND a.creado_en > DATE_SUB(NOW(), INTERVAL 23 HOUR)`,
    [entrega.evento]
  );
  const turno = rows[0];
  if (!turno) return 'omitido';
  const evento = eventoTurno(turno);
  await sendMail({
    to: entrega.email,
    subject: 'Confirmación de turno en MediTurnos',
    text: textoConfirmacion(turno, evento),
    evento,
  });
  return 'enviado';
}

async function entregarPush(entrega) {
  const [rows] = await pool.execute(
    `SELECT d.id_dispositivo AS dispositivo, d.token, a.tipo
       FROM aviso_eventos a
       LEFT JOIN aviso_dispositivos d
         ON d.vinculo = ?
         AND ((? IS NULL AND d.paciente <=> ?) OR d.id_dispositivo = ?)
         AND d.actualizado_en > DATE_SUB(NOW(), INTERVAL 30 DAY)
       LEFT JOIN turnos t ON t.id_turno = a.turno
      WHERE a.clave = ?
        AND a.creado_en > DATE_SUB(NOW(), INTERVAL 1 HOUR)
        AND (a.tipo = 'conflicto' OR (t.estado = 'activo'
             AND (? IS NULL OR t.paciente = ?)
             AND (? IS NULL OR t.paciente = d.paciente)))`,
    [entrega.vinculo, entrega.dispositivo, entrega.paciente_destino, entrega.dispositivo,
      entrega.evento, entrega.paciente_destino, entrega.paciente_destino, entrega.dispositivo]
  );
  const destino = rows[0];
  if (!destino) return 'omitido';
  if (!destino.token) {
    if (entrega.dispositivo) return 'omitido';
    // La sincronización puede crear el aviso antes de que la instalación registre su token.
    throw Object.assign(new Error('El dispositivo todavía no está registrado'), { code: 'FCM_DISPOSITIVO_PENDIENTE' });
  }
  try {
    await enviarPush({ ...destino, aviso: entrega.evento, vinculo: entrega.vinculo });
  } catch (error) {
    if (!error.dispositivoInvalido) throw error;
    await pool.execute(
      'DELETE FROM aviso_dispositivos WHERE id_dispositivo = ? AND vinculo = ?',
      [destino.dispositivo, entrega.vinculo]
    );
    return 'omitido';
  }
  return 'enviado';
}

async function resolver(entrega) {
  let estado;
  let espera = 0;
  try {
    estado = await (entrega.canal === 'correo' ? entregarCorreo(entrega) : entregarPush(entrega));
  } catch (error) {
    if (error.code !== 'FCM_DISPOSITIVO_PENDIENTE') registrarFalloAviso(error);
    const reintentar = error.reintentar !== false && entrega.intentos < maxIntentos;
    estado = reintentar ? 'pendiente' : 'fallido';
    if (reintentar) {
      espera = Math.min(3600, Math.max(60 * 2 ** (entrega.intentos - 1), error.esperarSegundos || 0));
    }
  }
  await pool.execute(
    `UPDATE aviso_entregas
        SET estado = ?, proximo_intento = DATE_ADD(NOW(), INTERVAL ? SECOND),
            email = CASE WHEN ? = 'pendiente' THEN email ELSE NULL END
      WHERE id_entrega = ? AND estado = 'en_curso' AND intentos = ?`,
    [estado, espera, estado, entrega.id, entrega.intentos]
  );
}

function arrancarAvisos() {
  const canales = [
    ...(correoConfigurado() ? ['correo'] : []),
    ...(pushConfigurado() ? ['push'] : []),
  ];
  if (!canales.length) return async () => {};

  let detenido = false;
  let bucle = Promise.resolve();
  let timer;
  let proximaLimpieza = 0;
  async function procesar() {
    if (detenido) return;
    try {
      for (let i = 0; i < 8 && !detenido; i += 1) {
        let huboEntrega = false;
        for (const canal of canales) {
          if (detenido) break;
          const entrega = await tomarEntrega(canal);
          if (entrega) {
            huboEntrega = true;
            await resolver(entrega);
          }
        }
        if (!huboEntrega) break;
      }
      if (!detenido && Date.now() >= proximaLimpieza) {
        await pool.execute('DELETE FROM aviso_dispositivos WHERE actualizado_en < DATE_SUB(NOW(), INTERVAL 30 DAY)');
        await pool.execute('DELETE FROM aviso_eventos WHERE creado_en < DATE_SUB(NOW(), INTERVAL 30 DAY)');
        proximaLimpieza = Date.now() + 86_400_000;
      }
    } catch (error) {
      registrarFalloAviso(error);
    } finally {
      if (!detenido) timer = setTimeout(() => { bucle = procesar(); }, 5_000).unref();
    }
  }
  bucle = procesar();
  return async () => {
    detenido = true;
    clearTimeout(timer);
    await bucle;
  };
}

module.exports = { encolarConfirmacion, encolarConflicto, registrarFalloAviso, arrancarAvisos, textoConfirmacion };
