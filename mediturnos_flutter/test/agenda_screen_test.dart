import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediturnos/core/connectivity_service.dart';
import 'package:mediturnos/core/di.dart';
import 'package:mediturnos/core/fechas.dart';
import 'package:mediturnos/domain/entities/disponibilidad.dart';
import 'package:mediturnos/domain/entities/especialista.dart';
import 'package:mediturnos/domain/entities/paciente.dart';
import 'package:mediturnos/domain/entities/reserva_temporal.dart';
import 'package:mediturnos/domain/entities/turno.dart';
import 'package:mediturnos/domain/repositories/turno_repository.dart';
import 'package:mediturnos/domain/usecases/turno_usecases.dart';
import 'package:mediturnos/presentation/screens/agenda_screen.dart';
import 'package:mediturnos/presentation/viewmodels/auth_viewmodel.dart';
import 'package:provider/provider.dart';

const _especialista = Especialista(
  id: 3,
  prefijo: 'Dra.',
  nombre: 'María',
  apellido: 'Ríos',
  especialidadId: 3,
  especialidad: 'Pediatría',
);

class _Turnos implements TurnoRepository {
  _Turnos(this.venceEn);

  final DateTime venceEn;
  final fecha = Fechas.hoy();
  final reservas = <ReservaTemporal>[];
  final liberadas = <ReservaTemporal>[];
  int solicitudes = 0;

  @override
  Future<Disponibilidad> disponibilidadMes(
          int especialistaId, int anio, int mes) async =>
      Disponibilidad(horarios: {
        Fechas.iso(fecha): const [
          HorarioAgenda('09:00', EstadoHorario.pasado),
          HorarioAgenda('10:00', EstadoHorario.ocupado),
          HorarioAgenda('23:59', EstadoHorario.libre),
        ],
      });

  @override
  Future<ReservaTemporal?> reservarHorario(
      int especialistaId, DateTime fecha, String hora) async {
    expect(
        (especialistaId, fecha, hora), (_especialista.id, this.fecha, '23:59'));
    final reserva = ReservaTemporal('codigo-de-test', venceEn);
    reservas.add(reserva);
    return reserva;
  }

  @override
  Future<void> liberarHorario(int especialistaId, DateTime fecha, String hora,
      ReservaTemporal reserva) async {
    liberadas.add(reserva);
  }

  @override
  Future<Map<String, dynamic>?> cargarBorrador() async => null;

  @override
  Future<Turno> solicitar({
    required Especialista especialista,
    required DateTime fecha,
    required String hora,
    required Paciente datos,
    ReservaTemporal? reserva,
  }) async {
    solicitudes++;
    throw StateError('La solicitud no debería llegar al repositorio');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Vencimiento implements DateTime {
  Duration restante = const Duration(minutes: 7);

  @override
  Duration difference(DateTime other) => restante;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _cargarAgenda(WidgetTester tester, _Turnos turnos) async {
  final conexion = ConnectivityService();
  addTearDown(conexion.dispose);
  final di = Di()
    ..disponibilidad = ConsultarDisponibilidadUseCase(turnos)
    ..solicitarTurno = SolicitarTurnoUseCase(turnos)
    ..borrador = BorradorTurnoUseCase(turnos);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<Di>.value(value: di),
      ChangeNotifierProvider<ConnectivityService>.value(value: conexion),
      ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel(di)),
    ],
    child: const MaterialApp(home: AgendaScreen(especialista: _especialista)),
  ));
  await tester.pumpAndSettle();
  final dia = find.text('${turnos.fecha.day}');
  await tester.ensureVisible(dia);
  await tester.tap(dia);
  await tester.pump();
}

Future<void> _tocarTexto(WidgetTester tester, String texto) async {
  final objetivo = find.text(texto);
  await tester.ensureVisible(objetivo);
  await tester.tap(objetivo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'la agenda tacha horas no seleccionables y libera al volver del formulario',
      (tester) async {
    final turnos = _Turnos(DateTime.now().add(const Duration(minutes: 7)));
    await _cargarAgenda(tester, turnos);

    for (final hora in ['09:00', '10:00']) {
      expect(tester.widget<Text>(find.text(hora)).style?.decoration,
          TextDecoration.lineThrough);
      await _tocarTexto(tester, hora);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Continuar'))
              .onPressed,
          isNull);
    }
    expect(tester.widget<Text>(find.text('23:59')).style?.decoration, isNull);
    await _tocarTexto(tester, '23:59');
    await _tocarTexto(tester, 'Continuar');
    expect(turnos.reservas, hasLength(1));
    expect(find.textContaining('Horario reservado por'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(turnos.liberadas, turnos.reservas);
    expect(find.text('Elegí tu turno'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('un formulario vencido bloquea la confirmación', (tester) async {
    final reloj = _Vencimiento();
    final turnos = _Turnos(reloj);
    await _cargarAgenda(tester, turnos);
    await _tocarTexto(tester, '23:59');
    await _tocarTexto(tester, 'Continuar');

    final confirmar = find.widgetWithText(ElevatedButton, 'Confirmar Turno');
    expect(tester.widget<ElevatedButton>(confirmar).onPressed, isNotNull);
    reloj.restante = Duration.zero;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('La reserva de 7 minutos venció.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(confirmar).onPressed, isNull);
    await _tocarTexto(tester, 'Confirmar Turno');
    expect(turnos.solicitudes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
