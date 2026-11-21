import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/connectivity_service.dart';
import '../../domain/entities/paciente.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/common.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _dom = TextEditingController();
  final _os = TextEditingController();
  final _plan = TextEditingController();
  final _nro = TextEditingController();
  final _usuario = TextEditingController();
  final _dni = TextEditingController();
  String _nac = '';

  @override
  void initState() {
    super.initState();
    final p = context.read<AuthViewModel>().paciente;
    _usuario.text = context.read<AuthViewModel>().session?.usuario.usuario ?? '';
    if (p != null) {
      _dni.text = p.dni;
      _nombre.text = p.nombreCompleto;
      _nac = p.fechaNacimiento;
      _email.text = p.email;
      _tel.text = p.telefono;
      _dom.text = p.domicilio;
      _os.text = p.obraSocial;
      _plan.text = p.plan;
      _nro.text = p.nroAfiliado;
    }
  }

  @override
  void dispose() {
    for (final c in [_nombre, _email, _tel, _dom, _os, _plan, _nro, _usuario, _dni]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!context.read<ConnectivityService>().online) {
      mostrarSnack(context, 'Necesitás conexión a internet para guardar cambios', error: true);
      return;
    }
    final auth = context.read<AuthViewModel>();
    final actual = auth.paciente!;
    final (nom, ape) = Paciente.partirNombre(_nombre.text.isEmpty ? ' ' : _nombre.text);
    final ok = await auth.guardarPerfil(actual.copyWith(
      nombre: nom, apellido: ape, fechaNacimiento: _nac, email: _email.text.trim(),
      telefono: _tel.text.trim(), domicilio: _dom.text.trim(),
      obraSocial: _os.text.trim(), plan: _plan.text.trim(), nroAfiliado: _nro.text.trim(),
    ));
    if (!mounted) return;
    mostrarSnack(context, ok ? 'Datos actualizados correctamente' : (auth.error ?? 'No se pudo guardar'), error: !ok);
  }

  Widget _bloque(String titulo, List<Widget> hijos) => AppCard(
        margin: const EdgeInsets.only(top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SeccionForm(titulo),
          ...hijos,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final p = auth.paciente;
    if (p == null) return const SizedBox.shrink();

    return Pagina(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CabeceraMarca(),
        const Titulo('Mi perfil'),
        const BannerOffline(),
        _bloque('Datos de Acceso', [
          CampoTexto(controller: _usuario, label: 'Usuario', habilitado: false),
        ]),
        _bloque('Datos Personales', [
          CampoTexto(controller: _nombre, label: 'Nombre y Apellido'),
          Row(children: [
            Expanded(child: CampoTexto(controller: _dni, label: 'DNI', habilitado: false)),
            const SizedBox(width: 12),
            Expanded(child: CampoFecha(label: 'Nacimiento', valor: _nac, onChanged: (v) => setState(() => _nac = v))),
          ]),
          CampoTexto(controller: _email, label: 'Email', tipo: TextInputType.emailAddress),
          CampoTexto(controller: _tel, label: 'Teléfono', tipo: TextInputType.phone),
          CampoTexto(controller: _dom, label: 'Domicilio'),
        ]),
        _bloque('Obra Social / Prepaga', [
          CampoTexto(controller: _os, label: 'Nombre Obra Social'),
          Row(children: [
            Expanded(child: CampoTexto(controller: _plan, label: 'Plan')),
            const SizedBox(width: 12),
            Expanded(child: CampoTexto(controller: _nro, label: 'Nro. Afiliado')),
          ]),
        ]),
        const SizedBox(height: 16),
        Boton('Guardar cambios', onPressed: _guardar, cargando: auth.cargando),
      ]),
    );
  }
}
