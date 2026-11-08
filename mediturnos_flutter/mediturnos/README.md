# MediTurnos (Flutter)

App móvil (Android + iOS) para solicitar, consultar y cancelar turnos médicos con enfoque **offline-first**.
Arquitectura: **MVVM + Clean Architecture** (Domain / Data / Presentation), según las Partes II-IV del informe.

## Cómo abrirlo en Android Studio

Este zip contiene `lib/`, `test/` y `pubspec.yaml`. Faltan las carpetas nativas (`android/`, `ios/`), que genera Flutter:

```bash
cd mediturnos
flutter create --org com.mediturnos --project-name mediturnos .
flutter pub get
flutter run
```

`flutter create .` NO pisa `lib/`, `pubspec.yaml` ni `test/`. Luego abrí la carpeta en Android Studio (plugins Flutter y Dart).

- Android: si compilás release contra una API real, agregá `<uses-permission android:name="android.permission.INTERNET"/>` en `android/app/src/main/AndroidManifest.xml`.
- iOS: requiere Mac con Xcode (`cd ios && pod install`).

## Cómo probar el prototipo (servidor simulado)

`lib/core/config.dart` tiene `kUsarMock = true`: la app usa un servidor en memoria (`MockRemoteDataSource`).

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
