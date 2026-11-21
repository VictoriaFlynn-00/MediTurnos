'use strict';
const { createPrivateKey, sign } = require('node:crypto');

const credenciales = process.env.FCM_SERVICE_ACCOUNT_JSON?.trim();
const urlOauth = 'https://oauth2.googleapis.com/token';
const alcance = 'https://www.googleapis.com/auth/firebase.messaging';
let cuenta;
if (credenciales) {
  try {
    const { project_id: proyecto, client_email: email, private_key: clave } = JSON.parse(credenciales);
    if (typeof proyecto !== 'string' || !/^[a-z0-9-]+$/.test(proyecto) ||
        typeof email !== 'string' || !email || !clave) {
      throw new Error();
    }
    cuenta = { proyecto, email, clave: createPrivateKey(clave) };
  } catch {
    throw new Error('FCM_SERVICE_ACCOUNT_JSON debe contener una cuenta de servicio válida');
  }
}

function pushConfigurado() {
  return Boolean(cuenta);
}

const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
let acceso;
let renovando;

async function solicitarAcceso() {
  const ahora = Math.floor(Date.now() / 1000);
  const jwt = [
    b64({ alg: 'RS256', typ: 'JWT' }),
    b64({ iss: cuenta.email, scope: alcance, aud: urlOauth, iat: ahora, exp: ahora + 3600 }),
  ].join('.');
  const assertion = `${jwt}.${sign('RSA-SHA256', Buffer.from(jwt), cuenta.clave).toString('base64url')}`;
  const respuesta = await fetch(urlOauth, {
    method: 'POST',
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    signal: AbortSignal.timeout(6_000),
  });
  const json = await respuesta.json().catch(() => ({}));
  if (!respuesta.ok || typeof json.access_token !== 'string' || !Number.isFinite(json.expires_in)) {
    throw Object.assign(new Error('No se pudo autenticar el envío a Firebase'), {
      code: `FCM_OAUTH_${respuesta.status}`,
      reintentar: respuesta.status === 429 || respuesta.status >= 500,
    });
  }
  acceso = { token: json.access_token, vence: Date.now() + json.expires_in * 1000 };
  return acceso.token;
}

async function tokenDeAcceso() {
  if (acceso?.vence > Date.now() + 60_000) return acceso.token;
  renovando ??= solicitarAcceso().finally(() => { renovando = null; });
  return renovando;
}

function mensajePush({ token, aviso, tipo, vinculo }) {
  return {
    token,
    notification: {
      title: 'MediTurnos',
      body: tipo === 'confirmacion'
        ? 'Tu turno se guardó correctamente.'
        : 'El horario solicitado ya no está disponible.',
    },
    data: { aviso, tipo, vinculo },
    android: {
      ttl: '3600s',
      notification: { tag: aviso, visibility: 'PRIVATE' },
    },
    apns: {
      headers: {
        'apns-collapse-id': aviso,
        'apns-expiration': String(Math.floor(Date.now() / 1000) + 3600),
      },
    },
  };
}

async function enviarPush(datos) {
  const token = await tokenDeAcceso();
  let respuesta;
  try {
    respuesta = await fetch(
      `https://fcm.googleapis.com/v1/projects/${cuenta.proyecto}/messages:send`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: mensajePush(datos) }),
        signal: AbortSignal.timeout(8_000),
      }
    );
  } catch {
    // Si se pierde la respuesta, FCM pudo haber aceptado el envío.
    throw Object.assign(new Error('Entrega de push sin confirmación del proveedor'), {
      code: 'FCM_RESULTADO_INCIERTO',
      reintentar: false,
    });
  }
  const json = await respuesta.json().catch(() => ({}));
  if (respuesta.ok) return;

  const detalle = json.error?.details?.find((d) =>
    d['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError')?.errorCode;
  if (respuesta.status === 401 && acceso?.token === token) acceso = null;
  const retryAfter = respuesta.headers.get('retry-after');
  const segundos = retryAfter && /^\d+$/.test(retryAfter)
    ? Number(retryAfter)
    : Math.ceil((Date.parse(retryAfter) - Date.now()) / 1000);
  throw Object.assign(new Error('Firebase rechazó la notificación'), {
    code: `FCM_${respuesta.status}`,
    dispositivoInvalido: detalle === 'UNREGISTERED' || detalle === 'SENDER_ID_MISMATCH',
    reintentar: [401, 429].includes(respuesta.status) || respuesta.status >= 500,
    esperarSegundos: Number.isFinite(segundos) ? segundos : 0,
  });
}

module.exports = { pushConfigurado, enviarPush, mensajePush };
