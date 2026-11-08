import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/common.dart';
import 'registro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuario = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _usuario.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    final auth = context.read<AuthViewModel>();
    final ok = await auth.iniciarSesion(_usuario.text, _pass.text);
    if (!ok && mounted && auth.error != null) {
      mostrarSnack(context, auth.error!, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      body: Pagina(
        child: Column(children: [
          const SizedBox(height: 32),
          const LogoMark(size: 64),
          const SizedBox(height: 12),
          const Text('MediTurnos',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: -1)),
          const SizedBox(height: 4),
          const Subtitulo('Gestión rápida de tus turnos médicos', centrado: true),
          const SizedBox(height: 24),
          CampoTexto(controller: _usuario, hint: 'DNI o Nombre de usuario'),
          CampoTexto(controller: _pass, hint: 'Contraseña', oculto: true),
          Boton('Iniciar Sesión', onPressed: _ingresar, cargando: auth.cargando),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const RegistroScreen())),
            child: const Text('¿No tienes cuenta? Regístrate',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              Expanded(child: Divider()),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('O', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
              Expanded(child: Divider()),
            ]),
          ),
          Boton('Continuar sin cuenta',
              subtexto: '(Solo permite solicitar turnos)',
              tipo: TipoBoton.contorno,
              onPressed: () => context.read<AuthViewModel>().continuarComoInvitado()),
        ]),
      ),
    );
  }
}
