'use strict';
const fs = require('node:fs');
const mysql = require('mysql2/promise');
const { db: cfg } = require('./config');

const ssl = cfg.ssl
  ? {
      minVersion: 'TLSv1.2',
      rejectUnauthorized: true,
      ...(cfg.sslCa ? { ca: fs.readFileSync(cfg.sslCa) } : {}),
    }
  : undefined;

const pool = mysql.createPool({
  host: cfg.host,
  port: cfg.port,
  user: cfg.user,
  password: cfg.password,
  database: cfg.database,
  ssl,
  charset: 'utf8mb4',
  dateStrings: true, // DATE/TIME llegan como texto: sin corrimientos de zona horaria
  waitForConnections: true,
  connectionLimit: 10,
});

/** Ejecuta fn dentro de una transacción: todo o nada. */
async function tx(fn) {
  const c = await pool.getConnection();
  try {
    await c.beginTransaction();
    const r = await fn(c);
    await c.commit();
    return r;
  } catch (e) {
    await c.rollback();
    throw e;
  } finally {
    c.release();
  }
}

const esDuplicado = (e) => Boolean(e) && e.code === 'ER_DUP_ENTRY';

module.exports = { pool, tx, esDuplicado };
