'use strict';
const cfg = require('./config');
const app = require('./app');
const { pool } = require('./db');
const { arrancarAvisos } = require('./avisos/cola');

const detenerAvisos = arrancarAvisos();

const server = app.listen(cfg.port, () => {
  console.log(`MediTurnos API escuchando en el puerto ${cfg.port}`);
});

function apagar() {
  server.close(async () => {
    await detenerAvisos();
    await pool.end().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 20_000).unref();
}
process.on('SIGTERM', apagar);
process.on('SIGINT', apagar);
