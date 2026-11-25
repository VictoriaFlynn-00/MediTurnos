# MediTurnos API

El "mozo" entre la app Flutter y la base MySQL. Node.js + Express. Pensada para **Azure App Service**
(la API) y **Azure Database for MySQL** (la base).

```
App Flutter ──HTTPS + JWT──▶ esta API ──▶ MySQL
```

## Actualizar una instalación de MediTurnos

En una base que ya tiene el esquema de MediTurnos, aplicá una vez las migraciones pendientes de la carpeta sql, en orden: 03_turnos.sql, 04_cuentas.sql, 05_avisos.sql, 06_push_origen.sql y 07_pacientes.sql. Antes de la migración 07, hacé un respaldo y detené las escrituras de la API y del procesador de avisos. La migración asigna un ID autoincremental a cada ficha y conserva el DNI como campo único. Después desplegá esta API y actualizá Flutter en los dispositivos. El volcado inicial elimina tablas y se usa únicamente al instalar desde cero.

La app consulta los horarios con detalle=1, aparta una franja por siete minutos en MySQL y confirma usando el token de esa reserva. La confirmación genera los avisos de correo y push configurados. La recuperación de contraseña usa un código de un solo uso que vence en 20 minutos. Las credenciales de SendGrid y Firebase y los pasos para cada plataforma figuran en [la guía de avisos](../mediturnos_flutter/docs/AVISOS.md).

## Qué trae

| Carpeta | Para qué |
|---|---|
| `src/routes/` | Los endpoints (auth, pacientes, catálogo, turnos) |
| `src/pure/` | Lógica sin base de datos (fechas, cálculo de disponibilidad) |
| `sql/01_migracion.sql` | Cambios al esquema del dump original (obligatorio) |
| `sql/02_datos_demo.sql` | Médicos, horarios y 2 pacientes de prueba (opcional) |
| `test/` | Tests: `npm test` (no necesitan MySQL) |

## Endpoints

Todos cuelgan de `/api`. Los errores vuelven como `{ "error": "texto", "code": "CODIGO" }`.

| Pedido | Qué hace | ¿Carnet (JWT)? |
|---|---|---|
| `GET /health` | ¿La API y la base están vivas? | no |
| `POST /auth/login` | `{usuario, password}` (usuario puede ser el DNI) → `{token, usuario, paciente}` | no |
| `POST /auth/registro` | `{usuario, password, paciente}` → sesión | no |
| `GET /pacientes/{dni}` | Ficha para autocompletar el registro | opcional |
| `PUT /pacientes/{dni}` | Editar mi ficha | **sí**, y es la mía |
| `GET /pacientes/{dni}/turnos` | Mi historial | **sí**, y es el mío |
| `GET /especialidades` | Catálogo | no |
| `GET /especialistas` | Catálogo | no |
| `GET /especialistas/{id}/disponibilidad?anio=2026&mes=11` | `{"2026-11-16": ["09:00", ...]}` | no |
| `POST /turnos` | `{especialistaId, fecha, hora, paciente}` → `{id}` | opcional (invitado) |
| `PATCH /turnos/{id}/cancelar` | Cancelar mi turno | **sí**, y es mío |

Códigos de error que la app entiende: `CREDENCIALES_INVALIDAS`, `HORARIO_NO_DISPONIBLE` (409),
`USUARIO_EXISTENTE` (409), `VALIDACION` (422), `TOKEN_INVALIDO` (401), `DEMASIADOS_INTENTOS` (429).

## Probarla en tu PC

Necesitás Node 20.6+ y MySQL 8.0.19+.

1. Importá el dump y los cambios (desde la carpeta del repo):
   ```bash
   mysql -u root -p < "mediturnos (1).sql"
   mysql -u root -p < mediturnos_api/sql/01_migracion.sql
   mysql -u root -p < mediturnos_api/sql/02_datos_demo.sql    # opcional
   mysql -u root -p < mediturnos_api/sql/03_turnos.sql
   mysql -u root -p < mediturnos_api/sql/04_cuentas.sql
   mysql -u root -p < mediturnos_api/sql/05_avisos.sql
   mysql -u root -p < mediturnos_api/sql/06_push_origen.sql
   mysql -u root -p < mediturnos_api/sql/07_pacientes.sql
   ```
2. Configurá y arrancá:
   ```bash
   cd mediturnos_api
   cp .env.example .env        # editá JWT_SECRET y DB_PASSWORD
   npm install
   npm run dev
   ```
3. Probá:
   ```bash
   curl http://localhost:3000/api/health
   curl http://localhost:3000/api/especialistas
   curl -X POST http://localhost:3000/api/auth/registro -H "Content-Type: application/json" \
     -d '{"usuario":"camilaf_99","password":"12345678","paciente":{"dni":"34123456","nombre":"Camila","apellido":"Fernández"}}'
   ```

## Subirla a Azure (resumen)

La interfaz de Azure cambia seguido: seguí la documentación oficial para los clics exactos. Los pasos son:

1. **Azure Database for MySQL**: crear el servidor, crear la base `mediturnosapp` e importar el volcado y las migraciones en el orden indicado arriba.
   Habilitar que App Service pueda conectarse (reglas de firewall / red).
2. **App Service** (Linux, runtime Node 20 o superior): crear y subir esta carpeta `mediturnos_api`
   (Deployment Center, GitHub Actions o zip). Azure ejecuta `npm install` y `npm start`.
3. En **Configuración → Variables de entorno** del App Service cargar: `JWT_SECRET`, `DB_HOST`, `DB_PORT`,
   `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSL=true`, `APP_TZ`. (`PORT` lo pone Azure solo.)
4. Verificar `https://TU-APP.azurewebsites.net/api/health`.
5. En la app Flutter: `--dart-define=API_URL=https://TU-APP.azurewebsites.net/api` (ver el README de la app).

Si la conexión TLS a MySQL falla, descargá el certificado raíz que indica la documentación de Azure,
guardalo en `certs/ca.pem` y poné `DB_SSL_CA=./certs/ca.pem`.

## Decisiones importantes

- **Anti doble reserva en la base, no en el código.** `turnos` tiene un índice único sobre
  `(especialista, fecha, hora, slot_activo)`. Aunque dos personas pidan el mismo horario en el mismo
  milisegundo, MySQL deja pasar solo una. Los turnos cancelados no cuentan, así que el horario se reutiliza.
- **Reintentos seguros.** Si la app pidió un turno, el servidor lo guardó pero la respuesta se perdió, la app
  reintenta desde su cola offline. Si el horario ya es de ese mismo paciente, la API devuelve el mismo
  turno (200) en vez de un 409. Sin esto, el turno quedaría "rechazado" en el celular estando reservado.
- **La ficha se obtiene por el ID de usuario del carnet**, no de lo que manda la app: nadie puede pedir, ver ni cancelar turnos ajenos.
- **Disponibilidad** = agenda semanal (`horarios_atencion`) − turnos activos − horarios que ya pasaron
  (en la zona `APP_TZ`).
- Contraseñas con bcrypt. Límite de intentos en login/registro y en la búsqueda por DNI.

## Riesgos conocidos (para resolver antes de producción)

1. **Registro sin verificación de identidad.** Quien conozca el DNI de un paciente que todavía no tiene
   cuenta puede registrarse como él. Hace falta verificar (código por email/SMS o alta presencial).
2. **`GET /pacientes/{dni}` devuelve datos personales** de fichas sin cuenta (lo necesita el autocompletado).
   Tiene límite de intentos, pero conviene devolver menos datos o eliminar la función.
3. **Datos de salud.** Confirmar con quien corresponda los requisitos legales de protección de datos
   personales y de salud de la clínica.
4. **No implementado** (según `docs/PROGRESO.md`): alta de médicos/secretarios por admin, historial clínico,
   recordatorios con Azure Functions + FCM, agenda del médico y renovación del JWT.
5. Probado: la lógica pura y el flujo de las rutas con una base simulada. **No probado** contra MySQL real
   ni desplegado en Azure.
