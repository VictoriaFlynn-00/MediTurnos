import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/di.dart';
import '../../core/theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/inicio_viewmodel.dart';
import '../viewmodels/turnos_viewmodel.dart';
import 'inicio_screen.dart';
import 'perfil_screen.dart';
import 'turnos_screen.dart';

/// Contenedor principal con barra inferior (Inicio / Mis Turnos / Perfil).
/// Los invitados solo ven Inicio. Los ViewModels viven mientras dura la sesión.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final di = context.read<Di>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (c) => InicioViewModel(di, () => c.read<AuthViewModel>().paciente)..cargar(),
        ),
        ChangeNotifierProvider(
          create: (c) => TurnosViewModel(di.historial, di.cancelarTurno,
              () => c.read<AuthViewModel>().paciente, di.turnoRepo.resultadosSync)
            ..cargar(),
        ),
      ],
      child: const _Scaffold(),
    );
  }
}

class _Scaffold extends StatefulWidget {
  const _Scaffold();
  @override
  State<_Scaffold> createState() => _ScaffoldState();
}

class _ScaffoldState extends State<_Scaffold> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final registrado = context.watch<AuthViewModel>().autenticado;
    final paginas = <Widget>[
      const InicioScreen(),
      if (registrado) const TurnosScreen(),
      if (registrado) const PerfilScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _i, children: paginas),
      bottomNavigationBar: registrado
          ? Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: BottomNavigationBar(
                currentIndex: _i,
                backgroundColor: Colors.white,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textMuted,
                type: BottomNavigationBarType.fixed,
                selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                onTap: (i) {
                  setState(() => _i = i);
                  if (i == 1) context.read<TurnosViewModel>().cargar();
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Inicio'),
                  BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Mis Turnos'),
                  BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
                ],
              ),
            )
          : null,
    );
  }
}
