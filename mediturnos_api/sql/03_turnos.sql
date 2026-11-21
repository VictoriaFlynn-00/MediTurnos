-- Ejecutar después de 01_migracion.sql (MySQL 8).
USE mediturnosapp;

CREATE TABLE reservas_turnos (
  especialista INT NOT NULL,
  fecha DATE NOT NULL,
  hora TIME NOT NULL,
  token_hash BINARY(32) NOT NULL,
  usuario_id INT NULL,
  vence_en DATETIME(3) NOT NULL COMMENT 'UTC',
  PRIMARY KEY (especialista, fecha, hora),
  KEY idx_reserva_vencimiento (especialista, vence_en),
  CONSTRAINT fk_reserva_especialista FOREIGN KEY (especialista)
    REFERENCES especialistas (id_especialista) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE turnos ADD COLUMN reserva_token_hash BINARY(32) NULL;
