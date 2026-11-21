import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediturnos/core/di.dart';
import 'package:mediturnos/core/errors.dart';
import 'package:mediturnos/domain/repositories/auth_repository.dart';
import 'package:mediturnos/domain/usecases/auth_usecases.dart';
import 'package:mediturnos/presentation/screens/registro_screen.dart';
import 'package:mediturnos/presentation/viewmodels/auth_viewmodel.dart';
import 'package:provider/provider.dart';

class _Cuentas implements AuthRepository {
  final consultas = <String>[];
  Completer<void> respuesta = Completer<void>();

  @override
  Future<void> verificarUsuarioDisponible(String usuario) {
    consultas.add(usuario);
    return respuesta.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'registro exige claves iguales y espera disponibilidad antes del DNI',
      (tester) async {
    final cuentas = _Cuentas();
    final di = Di()..registrarPaciente = RegistrarPacienteUseCase(cuentas);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthViewModel(di),
        child: const MaterialApp(home: RegistroScreen()),
      ),
    );

    final campos = find.byType(TextField);
    final siguiente = find.text('Siguiente');
    await tester.enterText(campos.at(0), 'usuario_usado');
    await tester.enterText(campos.at(1), 'clave-demo-123');
    await tester.enterText(campos.at(2), 'otra-clave-123');
    await tester.tap(siguiente);
    await tester.pumpAndSettle();
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(cuentas.consultas, isEmpty);

    await tester.enterText(campos.at(2), 'clave-demo-123');
    await tester.tap(siguiente);
    await tester.pump();
    expect(cuentas.consultas, ['usuario_usado']);
    expect(find.text('DNI'), findsNothing);

    cuentas.respuesta.completeError(const UsuarioExistenteException(
        'Ese nombre de usuario ya está en uso'));
    await tester.pumpAndSettle();
    expect(find.text('DNI'), findsNothing);

    cuentas.respuesta = Completer<void>();
    await tester.enterText(campos.at(0), 'usuario_nuevo');
    await tester.tap(siguiente);
    await tester.pump();
    expect(cuentas.consultas.last, 'usuario_nuevo');
    expect(find.text('DNI'), findsNothing);
    cuentas.respuesta.complete();
    await tester.pumpAndSettle();
    expect(find.text('DNI'), findsOneWidget);
  });
}
