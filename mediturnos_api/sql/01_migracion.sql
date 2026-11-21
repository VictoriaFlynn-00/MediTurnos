-- MediTurnos: cambios al esquema del dump "mediturnos (1).sql" que necesita la API.
-- Ejecutar UNA sola vez, después de importar el dump. Requiere MySQL 8.0.19 o superior.
USE mediturnosapp;

-- 1) El nombre de usuario no puede repetirse.
ALTER TABLE usuarios
  ADD UNIQUE KEY uq_usuarios_usuario (usuario);

-- 2) La app guarda más datos del paciente y un invitado puede no tener fecha de nacimiento.
ALTER TABLE pacientes
  MODIFY fechaNacimiento DATE NULL,
  ADD COLUMN email       VARCHAR(150) NULL,
  ADD COLUMN plan        VARCHAR(50)  NULL,
  ADD COLUMN nroAfiliado VARCHAR(50)  NULL;

-- 3) Prefijo (Dr./Dra.) y vínculo con la cuenta de usuario del médico.
ALTER TABLE especialistas
  ADD COLUMN prefijo    VARCHAR(5) NOT NULL DEFAULT 'Dr.',
  ADD COLUMN usuarioID  INT NULL,
  ADD UNIQUE KEY uq_especialista_usuario (usuarioID),
  ADD CONSTRAINT fk_especialista_usuario FOREIGN KEY (usuarioID) REFERENCES usuarios (id_usuario);

-- 4) Agenda semanal de cada médico (de dónde sale la disponibilidad).
--    dia_semana: 1 = lunes ... 7 = domingo
CREATE TABLE horarios_atencion (
  id           INT NOT NULL AUTO_INCREMENT,
  especialista INT NOT NULL,
  dia_semana   TINYINT NOT NULL,
  hora         TIME NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_horario (especialista, dia_semana, hora),
  CONSTRAINT fk_horario_especialista FOREIGN KEY (especialista) REFERENCES especialistas (id_especialista),
  CONSTRAINT ck_dia_semana CHECK (dia_semana BETWEEN 1 AND 7)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 5) ANTI DOBLE RESERVA, a prueba de carreras.
--    slot_activo vale 1 solo si el turno está 'activo' y NULL si no. MySQL permite varios
--    NULL en un índice único, así que un horario cancelado se puede volver a reservar,
--    pero dos turnos ACTIVOS en el mismo médico/fecha/hora son imposibles.
ALTER TABLE turnos
  ADD COLUMN slot_activo TINYINT GENERATED ALWAYS AS (IF(estado = 'activo', 1, NULL)) STORED,
  ADD UNIQUE KEY uq_turno_slot_activo (especialista, fecha, hora, slot_activo);
