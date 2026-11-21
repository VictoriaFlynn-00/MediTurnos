import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../domain/entities/paciente.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/common.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  int _paso = 1;
  bool _encontrado = false;
  String _nacimiento = '';

  final _usuario = TextEditingController();
  final _pass = TextEditingController();
  final _confirmacion = TextEditingController();
  final _dni = TextEditingController();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _dom = TextEditingController();
  final _os = TextEditingController();
  final _plan = TextEditingController();
  final _nro = TextEditingController();

  @override
  void dispose() {
    for (final c in [_usuario, _pass, _confirmacion, _dni, _nombre, _email, _tel, _dom, _os, _plan, _nro]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _siguiente() async {
    final auth = context.read<AuthViewModel>();
    if (auth.cargando) return;
    final ok = await auth.verificarCredencialesRegistro(
      _usuario.text, _pass.text, _confirmacion.text,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _paso = 2);
    } else if (auth.error != null) {
      mostrarSnack(context, auth.error!, error: true);
    }
  }

  Future<void> _buscar() async {
    final auth = context.read<AuthViewModel>();
    final p = await auth.buscarPorDni(_dni.text);
    if (!mounted) return;
    if (p == null) {
      setState(() => _encontrado = false);
      mostrarSnack(context, auth.error ?? 'No encontramos ese DNI. Completá tus datos para darte de alta.');
      return;
    }
    if (p.usuarioId != null) {
      setState(() => _encontrado = false);
      mostrarSnack(context, 'Ese DNI ya tiene un usuario registrado', error: true);
      return;
    }
    setState(() {
      _encontrado = true;
      _nombre.text = p.nombreCompleto;
      _nacimiento = p.fechaNacimiento;
      _email.text = p.email;
      _tel.text = p.telefono;
      _dom.text = p.domicilio;
      _os.text = p.obraSocial;
      _plan.text = p.plan;
      _nro.text = p.nroAfiliado;
    });
  }

  Future<void> _crear() async {
    final (nom, ape) = _nombre.text.trim().isEmpty
        ? ('', '')
        : Paciente.partirNombre(_nombre.text);
    final datos = Paciente(
      dni: _dni.text.trim(), nombre: nom, apellido: ape,
      fechaNacimiento: _nacimiento, email: _email.text.trim(),
      telefono: _tel.text.trim(), domicilio: _dom.text.trim(),
      obraSocial: _os.text.trim(), plan: _plan.text.trim(), nroAfiliado: _nro.text.trim(),
    );
    final auth = context.read<AuthViewModel>();
    final ok = await auth.registrar(_usuario.text, _pass.text, _confirmacion.text, datos);
    if (!mounted) return;
    if (ok) {
      // La raíz pasa sola a la pantalla principal; volvemos a ella.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else if (auth.error != null) {
      mostrarSnack(context, auth.error!, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      body: Pagina(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BarraSuperior(
            titulo: 'Crear cuenta',
            onBack: () {
              if (auth.cargando) return;
              if (_paso == 2) {
                setState(() => _paso = 1);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
            child: Text(_paso == 1 ? 'Paso 1 de 2: Credenciales' : 'Paso 2 de 2: Datos Personales',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13)),
          ),
          if (_paso == 1) ...[
            CampoTexto(controller: _usuario, label: 'Usuario', hint: 'Ej. juanperez99', habilitado: !auth.cargando),
            CampoTexto(controller: _pass, label: 'Contraseña', hint: 'Mínimo 8 caracteres', oculto: true, habilitado: !auth.cargando),
            CampoTexto(controller: _confirmacion, label: 'Repetí la contraseña', oculto: true, habilitado: !auth.cargando),
            const SizedBox(height: 8),
            Boton('Siguiente', onPressed: _siguiente, cargando: auth.cargando),
          ] else ...[
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: CampoTexto(controller: _dni, label: 'DNI', hint: 'Tu número de documento', tipo: TextInputType.number)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OutlinedButton(
                  onPressed: auth.cargando ? null : _buscar,
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Buscar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            if (_encontrado)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('✅ Paciente encontrado. Datos autocompletados.',
                    style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            CampoTexto(controller: _nombre, label: 'Nombre y Apellido', hint: 'Nombre completo'),
            CampoFecha(label: 'Fecha de Nacimiento', valor: _nacimiento, onChanged: (v) => setState(() => _nacimiento = v)),
            CampoTexto(controller: _email, label: 'Correo electrónico (obligatorio)', hint: 'correo@ejemplo.com', tipo: TextInputType.emailAddress),
            CampoTexto(controller: _tel, label: 'Teléfono', hint: 'Código de área + Número', tipo: TextInputType.phone),
            CampoTexto(controller: _dom, label: 'Domicilio', hint: 'Calle, Número, Localidad'),
            const SeccionForm('Obra Social (Opcional)'),
            CampoTexto(controller: _os, label: 'Nombre Obra Social / Prepaga', hint: 'Ej. OSDE, PAMI, Swiss Medical'),
            Row(children: [
              Expanded(child: CampoTexto(controller: _plan, label: 'Plan', hint: 'Ej. 210')),
              const SizedBox(width: 12),
              Expanded(child: CampoTexto(controller: _nro, label: 'Nro. Afiliado', hint: 'Ej. 12345678')),
            ]),
            const SizedBox(height: 8),
            Boton('Crear cuenta e Iniciar Sesión', onPressed: _crear, cargando: auth.cargando),
          ],
        ]),
      ),
    );
  }
}
