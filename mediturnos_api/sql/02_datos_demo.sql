-- Datos de prueba (los mismos que el servidor simulado de la app). Opcional.
SET NAMES utf8mb4;
USE mediturnosapp;

INSERT INTO especialidades (id_especialidad, nombre) VALUES
  (1, 'Cardiología'), (2, 'Clínica Médica'), (3, 'Pediatría');

-- DNI ficticios (20000001...). Cambialos por los reales.
INSERT INTO especialistas (id_especialista, prefijo, nombre, apellido, fechaNacimiento, especialidad, DNI) VALUES
  (1, 'Dr.',  'Alberto', 'Fernández', '1975-05-10', 2, 20000001),
  (2, 'Dr.',  'Juan',    'Pérez',     '1972-03-22', 1, 20000002),
  (3, 'Dra.', 'María',   'Ríos',      '1980-11-02', 3, 20000003),
  (4, 'Dra.', 'Laura',   'Gómez',     '1983-07-18', 1, 20000004),
  (5, 'Dr.',  'Pablo',   'Sosa',      '1978-01-30', 3, 20000005);

-- Días de atención (1 = lunes ... 7 = domingo) x 6 horarios fijos por día.
INSERT INTO horarios_atencion (especialista, dia_semana, hora)
SELECT d.esp, d.dia, h.hora
FROM (
  SELECT 1 AS esp, 1 AS dia UNION ALL SELECT 1,2 UNION ALL SELECT 1,3 UNION ALL SELECT 1,4 UNION ALL SELECT 1,5
  UNION ALL SELECT 2,2 UNION ALL SELECT 2,4 UNION ALL SELECT 2,5
  UNION ALL SELECT 3,1 UNION ALL SELECT 3,3 UNION ALL SELECT 3,5
  UNION ALL SELECT 4,1 UNION ALL SELECT 4,3
  UNION ALL SELECT 5,2 UNION ALL SELECT 5,4
) d
CROSS JOIN (
  SELECT '09:00' AS hora UNION ALL SELECT '09:30' UNION ALL SELECT '10:15'
  UNION ALL SELECT '11:00' UNION ALL SELECT '15:30' UNION ALL SELECT '16:00'
) h;

-- Pacientes SIN cuenta: sirven para probar el registro con autocompletado por DNI.
INSERT INTO pacientes (id_paciente, nombre, apellido, fechaNacimiento, domicilio, telefono, obraSocial, email, plan, nroAfiliado) VALUES
  (34123456, 'Camila', 'Fernández', '1995-08-14', 'Av. Belgrano Sur 1234, Santiago del Estero', '385 555 1234', 'OSDE', 'camila.f@ejemplo.com', '210', '123456789'),
  (40111222, 'Lucía',  'Gómez',     '2001-03-02', 'Independencia 450', '385 444 9876', NULL, 'lucia.g@ejemplo.com', NULL, NULL);
