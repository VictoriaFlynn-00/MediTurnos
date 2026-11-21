# Estado del proyecto

La app se conecta a Railway y permite simular el servidor con USAR_MOCK=true. El registro comprueba el usuario antes de los datos personales. La agenda incluye horarios vencidos u ocupados y retenciones de siete minutos. El correo de recuperación, las confirmaciones y las notificaciones de resultado se configuran según [AVISOS.md](AVISOS.md).

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

## Pendiente según el informe original

1. Aplicar las nuevas migraciones en Railway y desplegar la API actualizada.
2. Probar la recepción en una casilla y en un celular con Firebase configurado.
3. Req. 4, 12, 14, 15 (admin alta de médicos/secretarios, historial clínico, recordatorios con Azure Functions + FCM,
   agenda del médico): son de backend y/o de los roles médico/secretario/admin (la app solo implementa el rol paciente;
   un login de otro rol muestra un aviso).
4. Recordatorios previos al turno e integración con el calendario del dispositivo. El correo y el push de resultado ya están implementados.
5. Renovar/refresh del JWT al volver a `resumed`; expiración de sesión.
6. Interfaz simplificada para dispositivos de gama baja (Parte I).
7. Cambio de contraseña en Perfil (el mockup lo muestra; se omitió el campo con la contraseña en claro).
8. Pruebas: unitarias de use cases, widget tests, integración del flujo de reserva.
9. Nota de diseño: el informe (Parte I) dice que offline no se puede "Agendar un turno", pero el documento de
   requerimientos (Req. 9) sí lo permite con cola. Se implementó el Req. 9 (más reciente). Avisame si preferís lo otro.
