'use strict';
const { adjuntoCalendario } = require('./calendario');

function correoConfigurado() {
  return Boolean(process.env.SENDGRID_API_KEY?.trim() && process.env.CORREO_REMITENTE?.trim());
}

async function sendMail({ to, subject, text, evento }) {
  if (!correoConfigurado()) {
    throw Object.assign(new Error('Correo no configurado'), { code: 'CORREO_NO_CONFIGURADO' });
  }
  const remitente = process.env.CORREO_REMITENTE.trim();
  // Admitir tanto la dirección sola como "MediTurnos <avisos@dominio>".
  const partes = remitente.match(/^(.+?)\s*<([^<>]+)>$/);
  const from = partes ? { name: partes[1].trim(), email: partes[2].trim() } : { email: remitente };
  let respuesta;
  try {
    respuesta = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.SENDGRID_API_KEY.trim()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        personalizations: [{ to: [{ email: to }] }],
        from, subject, content: [{ type: 'text/plain', value: text }],
        ...(evento && {
          attachments: [adjuntoCalendario(evento, from.email, to)],
          tracking_settings: { click_tracking: { enable: false, enable_text: false } },
        }),
      }),
      signal: AbortSignal.timeout(8_000),
    });
  } catch {
    throw Object.assign(new Error('Se desconoce si SendGrid aceptó el correo'), {
      code: 'CORREO_RESULTADO_INCIERTO', reintentar: false,
    });
  }
  if (respuesta.status !== 202) {
    throw Object.assign(new Error('SendGrid no confirmó la aceptación del correo'), {
      code: `CORREO_${respuesta.status}`,
      reintentar: respuesta.status === 429,
      esperarSegundos: Number(respuesta.headers.get('retry-after')) || 0,
    });
  }
}

module.exports = { correoConfigurado, sendMail };
