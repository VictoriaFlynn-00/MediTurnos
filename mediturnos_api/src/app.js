'use strict';
const express = require('express');
const helmet = require('helmet');
const { pool } = require('./db');
const { general, auth } = require('./limites');
const { noEncontrada, manejarErrores } = require('./errors');

const app = express();
app.set('trust proxy', 1); // Azure App Service está detrás de un proxy
app.use(helmet());
app.use((req, res, next) => {
  res.on('finish', () => console.log(`${req.method} ${req.originalUrl} → ${res.statusCode}`));
  next();
});
app.use(express.json({ limit: '50kb' }));

const api = express.Router();
api.use(general);

// Azure puede usarlo como "health check".
api.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true });
  } catch {
    res.status(503).json({ ok: false });
  }
});

api.use('/auth', auth, require('./routes/auth'));
api.use('/pacientes', require('./routes/pacientes'));
api.use('/turnos', require('./routes/turnos'));
api.use('/avisos', require('./routes/avisos'));
api.use('/', require('./routes/catalogo'));

app.get('/', (req, res) => res.json({ servicio: 'MediTurnos API', ok: true }));
app.use('/api', api);
app.use(noEncontrada);
app.use(manejarErrores);

module.exports = app;
