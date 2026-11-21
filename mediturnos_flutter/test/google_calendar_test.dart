import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediturnos/core/google_calendar.dart';
import 'package:mediturnos/domain/entities/turno.dart';
import 'package:mediturnos/presentation/screens/exito_screen.dart';

void main() {
  test('el evento dura media hora incluso al cambiar de año', () {
    final url = enlaceGoogleCalendar(DateTime(2030, 12, 31), '23:45');
    expect(url.host, 'calendar.google.com');
    expect(url.queryParameters['dates'], '20301231T234500/20310101T001500');
    expect(url.queryParameters['ctz'], 'America/Argentina/Buenos_Aires');
  });

  testWidgets('Calendar aparece cuando el servidor confirma el turno', (tester) async {
    Future<void> mostrar(EstadoTurno estado, int? remoto) async {
      final turno = Turno(
        id: 'local', remoteId: remoto, pacienteDni: '123',
        especialistaId: 1, especialistaNombre: 'Dra. Pérez',
        especialidad: 'Clínica', fecha: DateTime(2030, 1, 7),
        hora: '09:00', estado: estado,
      );
      await tester.pumpWidget(MaterialApp(home: ExitoScreen(turno: turno, email: '')));
    }

    final boton = find.text('Agregar a Google Calendar');
    await mostrar(EstadoTurno.pendienteSync, null);
    expect(boton, findsNothing);
    await mostrar(EstadoTurno.activo, null);
    expect(boton, findsNothing);
    await mostrar(EstadoTurno.activo, 12);
    expect(boton, findsOneWidget);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const canal = MethodChannel('com.mediturnos.mediturnos/calendario');
    final messenger = tester.binding.defaultBinaryMessenger;
    MethodCall? solicitud;
    messenger.setMockMethodCallHandler(canal, (call) async {
      solicitud = call;
      return true;
    });
    try {
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(solicitud?.method, 'crearEvento');
      expect(solicitud?.arguments, {
        'fechaHora': '2030-01-07 09:00',
        'zona': 'America/Argentina/Buenos_Aires',
        'titulo': 'Turno médico · MediTurnos',
        'duracionMs': 1800000,
      });
    } finally {
      messenger.setMockMethodCallHandler(canal, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
