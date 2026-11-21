import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../widgets/common.dart';

class RecuperarClaveScreen extends StatefulWidget {
  const RecuperarClaveScreen({super.key, this.usuario = ''});

  final String usuario;

  @override
  State<RecuperarClaveScreen> createState() => _RecuperarClaveScreenState();
}

class _RecuperarClaveScreenState extends State<RecuperarClaveScreen> {
  late final _usuario = TextEditingController(text: widget.usuario);
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();

  bool _ingresarCodigo = false;
  bool _solicitado = false;

  @override
  void dispose() {
    _usuario.dispose();
    _codigo.dispose();
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _solicitar() async {
    final auth = context.read<AuthViewModel>();
    if (auth.cargando) return;
    final ok = await auth.solicitarRecuperacion(_usuario.text);
    if (!mounted) return;
    if (ok) {
      _codigo.clear();
      setState(() {
        _ingresarCodigo = true;
        _solicitado = true;
      });
    } else if (auth.error != null) {
      mostrarSnack(context, auth.error!, error: true);
    }
  }

  Future<void> _restablecer() async {
    final auth = context.read<AuthViewModel>();
    if (auth.cargando) return;
    final ok = await auth.restablecerClave(
      _codigo.text,
      _password.text,
      _confirmacion.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else if (auth.error != null) {
      mostrarSnack(context, auth.error!, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      body: Pagina(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BarraSuperior(
              titulo: 'Recuperar contraseña',
              onBack: () {
                if (auth.cargando) return;
                if (_ingresarCodigo) {
                  setState(() => _ingresarCodigo = false);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            if (!_ingresarCodigo) ...[
              const Subtitulo(
                  'Te enviaremos un código al correo asociado a tu cuenta.'),
              const SizedBox(height: 16),
              CampoTexto(
                controller: _usuario,
                label: 'Usuario o DNI',
                habilitado: !auth.cargando,
              ),
              Boton('Enviar código',
                  onPressed: _solicitar, cargando: auth.cargando),
              Center(
                child: TextButton(
                  onPressed: auth.cargando
                      ? null
                      : () => setState(() => _ingresarCodigo = true),
                  child: const Text('Ya tengo un código'),
                ),
              ),
            ] else ...[
              Subtitulo(
                _solicitado
                    ? 'Si los datos coinciden con una cuenta, vas a recibir un código por correo. Revisá también la carpeta de spam.'
                    : 'Copiá y pegá el código que te llegó por correo.',
              ),
              const SizedBox(height: 16),
              CampoTexto(
                controller: _codigo,
                label: 'Código de recuperación',
                habilitado: !auth.cargando,
              ),
              CampoTexto(
                controller: _password,
                label: 'Nueva contraseña',
                hint: 'Mínimo 8 caracteres',
                oculto: true,
                habilitado: !auth.cargando,
              ),
              CampoTexto(
                controller: _confirmacion,
                label: 'Repetí la nueva contraseña',
                oculto: true,
                habilitado: !auth.cargando,
              ),
              Boton('Cambiar contraseña',
                  onPressed: _restablecer, cargando: auth.cargando),
              Center(
                child: TextButton(
                  onPressed: auth.cargando
                      ? null
                      : () => setState(() => _ingresarCodigo = false),
                  child: const Text('Pedir otro código'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
