-- Ejecutar después de 06, con la API y el procesador de avisos detenidos.
-- Reanudable: el cambio de todos los identificadores ocurre en una sola transacción.
USE mediturnosapp;
DROP PROCEDURE IF EXISTS migrar_pacientes_07;
DELIMITER //
CREATE PROCEDURE migrar_pacientes_07()
BEGIN
  DECLARE fk_anteriores INT DEFAULT @@SESSION.foreign_key_checks;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET SESSION foreign_key_checks = fk_anteriores;
    ROLLBACK;
    RESIGNAL;
  END;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=DATABASE()
                 AND table_name='pacientes' AND column_name='dni') THEN
    ALTER TABLE pacientes ADD COLUMN dni VARCHAR(8) NULL AFTER id_paciente,
      ADD UNIQUE KEY uq_pacientes_dni (dni);
  END IF;

  -- Las referencias siguen a la misma persona en ambos pasos de la renumeración.
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE()
                 AND table_name='turnos' AND constraint_name='fk_turno_paciente_id') THEN
    ALTER TABLE turnos DROP FOREIGN KEY turnos_ibfk_1,
      ADD CONSTRAINT fk_turno_paciente_id FOREIGN KEY (paciente)
      REFERENCES pacientes(id_paciente) ON UPDATE CASCADE;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=DATABASE()
             AND table_name='historialclinico' AND column_name='pacienteDNI') THEN
    ALTER TABLE historialclinico RENAME COLUMN pacienteDNI TO paciente_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE()
                 AND table_name='historialclinico' AND constraint_name='fk_historial_paciente_id') THEN
    ALTER TABLE historialclinico DROP FOREIGN KEY historialclinico_ibfk_1,
      ADD CONSTRAINT fk_historial_paciente_id FOREIGN KEY (paciente_id)
      REFERENCES pacientes(id_paciente) ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE()
                 AND table_name='aviso_dispositivos' AND constraint_name='fk_dispositivo_paciente_id') THEN
    ALTER TABLE aviso_dispositivos DROP FOREIGN KEY fk_aviso_dispositivo_paciente,
      ADD CONSTRAINT fk_dispositivo_paciente_id FOREIGN KEY (paciente)
      REFERENCES pacientes(id_paciente) ON UPDATE CASCADE ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema=DATABASE()
                 AND table_name='aviso_entregas' AND constraint_name='fk_entrega_paciente_id') THEN
    ALTER TABLE aviso_entregas ADD CONSTRAINT fk_entrega_paciente_id FOREIGN KEY (paciente_destino)
      REFERENCES pacientes(id_paciente) ON UPDATE CASCADE ON DELETE CASCADE;
  END IF;

  IF EXISTS (SELECT 1 FROM pacientes WHERE dni IS NULL) THEN
    IF EXISTS (SELECT 1 FROM pacientes WHERE dni IS NOT NULL OR id_paciente < 0 OR id_paciente > 99999999) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Datos de identidad inesperados: revisar antes de migrar';
    END IF;
    DROP TEMPORARY TABLE IF EXISTS nuevos_ids;
    CREATE TEMPORARY TABLE nuevos_ids (anterior INT PRIMARY KEY, nuevo INT UNIQUE NOT NULL);
    START TRANSACTION;
    INSERT INTO nuevos_ids SELECT id_paciente, ROW_NUMBER() OVER (ORDER BY id_paciente) FROM pacientes;
    UPDATE pacientes p JOIN nuevos_ids m ON p.id_paciente=m.anterior
       SET p.dni=LPAD(CAST(m.anterior AS CHAR), GREATEST(7, CHAR_LENGTH(m.anterior)), '0'),
           p.id_paciente=-m.nuevo;
    UPDATE pacientes SET id_paciente=-id_paciente WHERE id_paciente < 0;
    COMMIT;
    DROP TEMPORARY TABLE nuevos_ids;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=DATABASE()
                 AND table_name='pacientes' AND column_name='id_paciente' AND extra LIKE '%auto_increment%') THEN
    -- MySQL exige esto solo para cambiar el atributo AUTO_INCREMENT de la PK referenciada.
    SET SESSION foreign_key_checks=0;
    ALTER TABLE pacientes MODIFY id_paciente INT NOT NULL AUTO_INCREMENT, MODIFY dni VARCHAR(8) NOT NULL;
    SET SESSION foreign_key_checks=fk_anteriores;
  END IF;
END//
DELIMITER ;
CALL migrar_pacientes_07();
DROP PROCEDURE migrar_pacientes_07;
