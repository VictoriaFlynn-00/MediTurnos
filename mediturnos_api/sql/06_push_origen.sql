-- Aplicar una vez después de 05_avisos.sql, antes de desplegar la API actualizada.
USE mediturnosapp;

ALTER TABLE aviso_entregas ADD COLUMN paciente_destino INT NULL;
