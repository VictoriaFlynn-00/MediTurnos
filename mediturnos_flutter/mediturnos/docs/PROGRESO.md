# Estado del proyecto

> Importante: el código se escribió sin acceso al SDK de Flutter (no pude compilarlo ni ejecutarlo).
> Al correr `flutter pub get` / `flutter run` por primera vez pueden aparecer errores menores de compilación
> (tipos, imports, versiones de paquetes). Pasame el log y lo corrijo en la próxima sesión.

## Hecho (app Flutter)

| Req. | Descripción | Estado |
|---|---|---|
| 1-2 | Alta de paciente + registro de usuario (pantalla de 2 pasos, búsqueda por DNI) | Hecho en la app (contra mock) |
| 3 | Login con JWT (token en flutter_secure_storage, sesión restaurable offline) | Hecho (contra mock) |
| 5 | Consultar especialidades y médicos (con caché local) | Hecho |
| 6 | Horarios libres por médico/fecha (calendario mensual) | Hecho |
| 7 | Solicitar turno online | Hecho |
| 8 | Cancelar turno propio (también offline, queda en cola) | Hecho |
| 9 | Solicitar turno offline → SQLite `pendienteSync` + cola | Hecho |
| 10 | SyncManager: reenvío automático, backoff exponencial, conflicto de doble reserva → "rechazado" | Hecho |
| 11 | Historial / próximos turnos (offline-first) | Hecho |
| 13 | Ver y editar datos del paciente | Hecho (guardar requiere conexión) |
| Parte IV | Borrador del formulario (inactive/paused), restaurar al reabrir, refresco al `resumed` | Hecho (parcial: falta renovar JWT) |

Checklist Parte V: listar turnos de un médico ✔, solicitar turno ✔, SQLite ✔, simular offline ✔,
recuperar al reabrir ✔, mensaje de sincronización ✔. Faltan capturas, manual de uso y APK/ZIP final.

## Pendiente

1. **Backend real** (Azure App Service + MySQL): implementar `HttpRemoteDataSource` (paquete `http`) con los endpoints
   y poner `kUsarMock = false`. Hoy todo corre contra `MockRemoteDataSource`.
2. **SQL**: agregar `usuarioID` a la tabla `especialistas` (pendiente del documento de requerimientos).
3. Req. 4, 12, 14, 15 (admin alta de médicos/secretarios, historial clínico, recordatorios con Azure Functions + FCM,
   agenda del médico): son de backend y/o de los roles médico/secretario/admin (la app solo implementa el rol paciente;
   un login de otro rol muestra un aviso).
4. Notificaciones push (FCM) y alternativa por email si no hay permiso; sincronizar con calendario del dispositivo.
5. Renovar/refresh del JWT al volver a `resumed`; expiración de sesión.
6. Interfaz simplificada para dispositivos de gama baja (Parte I).
7. Cambio de contraseña en Perfil (el mockup lo muestra; se omitió el campo con la contraseña en claro).
8. Pruebas: unitarias de use cases, widget tests, integración del flujo de reserva.
9. Nota de diseño: el informe (Parte I) dice que offline no se puede "Agendar un turno", pero el documento de
   requerimientos (Req. 9) sí lo permite con cola. Se implementó el Req. 9 (más reciente). Avisame si preferís lo otro.
