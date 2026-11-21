-- Ejecutar en la misma base de la API, después de 01_migracion.sql.
USE mediturnosapp;

CREATE TABLE IF NOT EXISTS aviso_dispositivos (
  id_dispositivo BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  token VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  paciente INT NULL,
  vinculo CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_dispositivo),
  UNIQUE KEY uq_aviso_token (token),
  UNIQUE KEY uq_aviso_vinculo (vinculo),
  KEY ix_aviso_dispositivo_paciente (paciente, actualizado_en),
  KEY ix_aviso_dispositivo_vigencia (actualizado_en),
  CONSTRAINT fk_aviso_dispositivo_paciente FOREIGN KEY (paciente)
    REFERENCES pacientes (id_paciente) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS aviso_eventos (
  clave CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  tipo ENUM('confirmacion', 'conflicto') NOT NULL,
  turno INT NULL,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (clave),
  CONSTRAINT fk_aviso_evento_turno FOREIGN KEY (turno)
    REFERENCES turnos (id_turno) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS aviso_entregas (
  id_entrega BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  evento CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  canal ENUM('correo', 'push') NOT NULL,
  email VARCHAR(150) NULL,
  dispositivo BIGINT UNSIGNED NULL,
  vinculo CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
  estado ENUM('pendiente', 'en_curso', 'enviado', 'omitido', 'fallido') NOT NULL DEFAULT 'pendiente',
  intentos TINYINT UNSIGNED NOT NULL DEFAULT 0,
  proximo_intento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_entrega),
  KEY ix_aviso_entrega_pendiente (canal, estado, proximo_intento),
  CONSTRAINT fk_aviso_entrega_evento FOREIGN KEY (evento)
    REFERENCES aviso_eventos (clave) ON DELETE CASCADE,
  CONSTRAINT fk_aviso_entrega_dispositivo FOREIGN KEY (dispositivo)
    REFERENCES aviso_dispositivos (id_dispositivo) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
