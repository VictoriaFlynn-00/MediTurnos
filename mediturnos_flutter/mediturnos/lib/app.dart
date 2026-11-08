import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/connectivity_service.dart';
import 'core/di.dart';
import 'core/theme.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/viewmodels/auth_viewmodel.dart';
import 'presentation/widgets/sync_listener.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

class MediTurnosApp extends StatelessWidget {
  const MediTurnosApp({super.key, required this.di});
  final Di di;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          Provider<Di>.value(value: di),
          ChangeNotifierProvider<ConnectivityService>.value(value: di.connectivity),
          ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel(di)..restaurar()),
        ],
        child: MaterialApp(
          title: 'MediTurnos',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          scaffoldMessengerKey: messengerKey,
          home: SyncListener(messengerKey: messengerKey, child: const _RootGate()),
        ),
      );
}

/// Decide qué mostrar según el estado de sesión:
/// splash -> login -> (sesión o invitado) pantalla principal.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (auth.restaurando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.hayAcceso ? const HomeShell() : const LoginScreen();
  }
}
