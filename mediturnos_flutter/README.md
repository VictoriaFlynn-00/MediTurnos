# MediTurnos (Flutter)

App móvil (Android + iOS) para solicitar, consultar y cancelar turnos médicos con enfoque **offline-first**.
Arquitectura: **MVVM + Clean Architecture** (Domain / Data / Presentation), según las Partes II-IV del informe.

## Cómo abrirlo en Android Studio

Abrí la carpeta mediturnos_flutter en Android Studio, ejecutá flutter pub get y usá el botón Run. El proyecto incluye Android e iOS y apunta por defecto a la API de Railway. Para compilar en iOS se necesita macOS con Xcode.

## Cómo probar el prototipo (servidor simulado)

`lib/core/config.dart` permite elegir el prototipo con `flutter run --dart-define=USAR_MOCK=true`.

| Prueba | Datos |
|---|---|
| Login paciente | `camilaf_99` / `12345678` (o DNI `34123456`) |
| Registro con autocompletado | paso 2, DNI `40111222` → "Buscar" |
| Invitado | "Continuar sin cuenta" |
| **Modo sin conexión** | ícono de wifi (arriba en Inicio) |

Flujo offline: abrí un médico estando online (se cachea la disponibilidad) → activá el modo sin conexión → pedí el turno → queda "Pendiente de sincronizar" → desactivá el modo offline → se sincroniza y aparece el mensaje.

## Estructura

```
lib/
  core/           config, errores, DI, tema, conectividad (real + simulada), fechas
  domain/         entities, repositories (interfaces), usecases
  data/
    datasources/  local_db (SQLite), remote_data_source (contrato API), mock_remote_data_source
    repositories/ auth/turno repository impl, sync_manager (cola + reintentos)
  presentation/   viewmodels, screens (fieles al mockup), widgets
```

Ver `docs/PROGRESO.md` para el estado por requerimiento y lo que falta.

## Conexión y avisos

La configuración predeterminada usa Railway. Para probar la API de tu PC desde el emulador de Android, ejecutá `flutter run --dart-define=API_URL=http://10.0.2.2:3000/api`.

Las migraciones 03, 04 y 05 de `mediturnos_api/sql` habilitan las reservas temporales, la recuperación de cuentas y la entrega de avisos. Consultá [la configuración de correo y push](docs/AVISOS.md).
