-- Ejecutar después de 01_migracion.sql.
USE mediturnosapp;

CREATE TABLE IF NOT EXISTS recuperaciones_clave (
  usuario_id   INT NOT NULL,
  token_hash   BINARY(32) NOT NULL,
  email_hash   BINARY(32) NOT NULL,
  creada_en    DATETIME(6) NOT NULL,
  vence_en     DATETIME(6) NOT NULL,
  PRIMARY KEY (usuario_id),
  UNIQUE KEY uq_recuperaciones_token (token_hash),
  CONSTRAINT fk_recuperaciones_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS versiones_sesion (
  usuario_id INT NOT NULL,
  version    INT UNSIGNED NOT NULL,
  PRIMARY KEY (usuario_id),
  CONSTRAINT fk_versiones_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios (id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
