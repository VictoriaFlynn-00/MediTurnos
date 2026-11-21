# Correo y notificaciones de turnos

La API registra el aviso de confirmación al guardar el turno en MySQL. El correo incluye número de turno, profesional, especialidad, fecha y hora local. Si la API rechaza un horario por conflicto, envía un push de indisponibilidad al dispositivo suscripto. Una retención temporal o una solicitud pendiente en el teléfono no generan un aviso de confirmación.

## API y MySQL

1. Aplicá `mediturnos_api/sql/05_avisos.sql` en la misma base donde están los turnos y pacientes antes de activar los proveedores. En una base nueva, cargá primero el esquema y las migraciones anteriores según el README de la API.
2. Para correo, en SendGrid verificá tu dirección con Single Sender Verification y creá una API key con permiso Mail Send. Agregá `SENDGRID_API_KEY` y `CORREO_REMITENTE` como variables del servicio. Usá la dirección verificada, por ejemplo `MediTurnos <turnos@tu-dominio.example>`. La confirmación y la recuperación de clave comparten este transporte HTTPS. [Enviar correo con SendGrid](https://www.twilio.com/docs/sendgrid/api-reference/mail-send/mail-send).
3. Para push, creá un proyecto Firebase y habilitá Firebase Cloud Messaging API (HTTP v1) en el proyecto. Creá una cuenta de servicio en ese proyecto con el rol Firebase Cloud Messaging API Admin y guardá su JSON completo como la variable secreta `FCM_SERVICE_ACCOUNT_JSON` del servicio. En Railway cargala desde Variables. Conservá los escapes de salto de línea de la clave privada dentro del JSON y mantené el secreto fuera de la app y del repositorio. [Configurar FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api).
4. Reiniciá la API tras cargar las variables. Los dos canales se habilitan por separado cuando tienen su configuración completa.

## Android

1. Registrá la aplicación Android `com.mediturnos.mediturnos` en el mismo proyecto Firebase.
2. Guardá el `google-services.json` de la aplicación en `mediturnos_flutter/android/app/google-services.json`. Gradle aplica el plugin Google Services cuando encuentra ese archivo. [Configuración de Google Services](https://firebase.google.com/docs/android/google-services-plugin-and-file).
3. Iniciá la app normalmente en Android Studio o con `flutter run`. Usá un teléfono con Google Play Services o un emulador con Google APIs. Al iniciar sesión o entrar como invitado, concedé permiso para notificaciones. [Configurar FCM en Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

## iOS

1. Registrá `com.mediturnos.mediturnos` en el mismo proyecto Firebase. En Xcode, agregá `GoogleService-Info.plist` a `ios/Runner` con el target Runner para que quede incluido en sus recursos.
2. En el target Runner, habilitá Push Notifications y, en Background Modes, Background fetch y Remote notifications. Configurá la firma con tu equipo y el perfil que habilita push.
3. Cargá en Firebase la clave APNs de desarrollo o producción que corresponda, con su Key ID y Team ID. Iniciá la app en un iPhone y concedé permiso de notificaciones. [Configurar FCM y APNs](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

Flutter intenta inicializar Firebase al abrir una instalación móvil. Podés usar `--dart-define=PUSH_HABILITADO=false` para apagarlo. El modo simulado prescinde de Firebase.

## Entrega y verificación

- Probá un turno válido con correo propio de prueba. Vas a ver el push de confirmación y recibir el correo con los detalles. Probá tanto con una cuenta como con acceso invitado y comprobá que un reintento de la misma reserva devuelve su confirmación existente.
- Para probar un conflicto offline, descargá la agenda en un dispositivo con permiso push, desconectalo, dejá una solicitud pendiente y tomá ese mismo horario desde otra instalación. Al volver a conectarlo, el backend rechaza esa solicitud y el dispositivo iniciador recibe el aviso. También podés provocar el conflicto de retención con dos dispositivos que intenten elegir el mismo horario.
- Para invitados, se guarda un vínculo aleatorio de la instalación junto a la solicitud pendiente. Cerrar el acceso invalida el vínculo local y solicita la baja del token. Con sesión, el backend utiliza los dispositivos del paciente autenticado. En la pantalla bloqueada el aviso indica el estado, sin incluir fecha, profesional, especialidad, DNI ni correo.
- La cola deduplica eventos por turno confirmado o intento de reserva. Reintenta fallos transitorios con espera creciente, hasta seis intentos. Para correo, reintenta cuando SendGrid limita temporalmente los pedidos (HTTP 429). Si una respuesta se pierde o una entrega queda interrumpida, evita repetir automáticamente el envío. HTTP 202 indica aceptación por el proveedor.
- La API mantiene la cola procesada durante 30 días y limpia los registros de dispositivos que llevan 30 días sin renovarse. Las entregas de push vencen al cabo de una hora en la cola y los correos al cabo de 23 horas.
