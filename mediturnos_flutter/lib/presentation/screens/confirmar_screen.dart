import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/di.dart';
import '../../core/fechas.dart';
import '../../core/theme.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/paciente.dart';
import '../../domain/entities/reserva_temporal.dart';
import '../../domain/entities/turno.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/confirmar_viewmodel.dart';
import '../widgets/common.dart';

class ConfirmarScreen extends StatelessWidget {
  const ConfirmarScreen({super.key, required this.especialista, required this.fecha, required this.hora, required this.reserva});
  final Especialista especialista;
  final DateTime fecha;
  final String hora;
  final ReservaTemporal? reserva;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => ConfirmarViewModel(c.read<Di>().solicitarTurno, c.read<Di>().borrador, reserva),
        child: _Form(especialista: especialista, fecha: fecha, hora: hora),
      );
}

class _Form extends StatefulWidget {
  const _Form({required this.especialista, required this.fecha, required this.hora});
  final Especialista especialista;
  final DateTime fecha;
  final String hora;
  @override
  State<_Form> createState() => _FormState();
}

/// Formulario con borrador persistente: si entra una llamada, la app pasa a
/// inactive/paused o el SO la cierra, los datos ingresados se recuperan.
class _FormState extends State<_Form> with WidgetsBindingObserver {
  final _dni = TextEditingController();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _dom = TextEditingController();
  final _os = TextEditingController();
  final _plan = TextEditingController();
  final _nro = TextEditingController();
  String _nac = '';
  bool _restaurando = true;
  bool _registrado = false;

  List<TextEditingController> get _todos => [_dni, _nombre, _email, _tel, _dom, _os, _plan, _nro];
  String get _slot => '${widget.especialista.id}|${Fechas.iso(widget.fecha)}|${widget.hora}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  Future<void> _iniciar() async {
    if (!mounted) return;
    final p = context.read<AuthViewModel>().paciente;
    _registrado = p != null;
    if (p != null) _llenar(p);

    final b = await context.read<ConfirmarViewModel>().borrador.cargar();
    if (!mounted) return;
    if (b != null && b['slot'] == _slot && b['datos'] is Map) {
      _llenar(Paciente.fromJson(Map<String, dynamic>.from(b['datos'] as Map)));
    }
    for (final c in _todos) {
      c.addListener(_guardarBorrador);
    }
    setState(() => _restaurando = false);
  }

  void _llenar(Paciente p) {
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

  Paciente _paciente() {
    final (nom, ape) = _nombre.text.trim().isEmpty ? ('', '') : Paciente.partirNombre(_nombre.text);
    return Paciente(
      dni: _dni.text.trim(), nombre: nom, apellido: ape, fechaNacimiento: _nac,
      email: _email.text.trim(), telefono: _tel.text.trim(), domicilio: _dom.text.trim(),
      obraSocial: _os.text.trim(), plan: _plan.text.trim(), nroAfiliado: _nro.text.trim(),
    );
  }

  void _guardarBorrador() {
    if (_restaurando || !mounted) return;
    unawaited(context.read<ConfirmarViewModel>().borrador
        .guardar({'slot': _slot, 'datos': _paciente().toJson()}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _guardarBorrador();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _todos) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmar() async {
    final vm = context.read<ConfirmarViewModel>();
    final datos = _paciente();
    final t = await vm.confirmar(widget.especialista, widget.fecha, widget.hora, datos);
    if (!mounted) return;
    if (t == null) {
      if (vm.error != null) mostrarSnack(context, vm.error!, error: true);
      return;
    }
    Navigator.of(context).pop<(Turno, String)>((t, datos.email));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConfirmarViewModel>();
    final segundos = vm.segundosRestantes;
    return PopScope(
      canPop: !vm.enviando,
      child: Scaffold(
        body: Pagina(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const BarraSuperior(titulo: 'Revisá tu turno'),
            AppCard(
              color: AppColors.primaryLight,
              borderColor: AppColors.primaryLight,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.especialista.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                Text(Fechas.larga(widget.fecha, widget.hora),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
            const BannerOffline(),
            if (!vm.horarioDisponible)
              Aviso(
                titulo: vm.vencida ? 'La reserva de 7 minutos venció.' : 'El horario ya no está disponible.',
                detalle: 'Volvé a la agenda para elegir un horario.',
                fondo: AppColors.dangerLight,
                color: AppColors.danger,
              )
            else if (segundos != null)
              Aviso(titulo: 'Horario reservado por ${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}')
            else
              const Aviso(titulo: 'Horario tentativo', detalle: 'La clínica verificará la disponibilidad al recibir tu solicitud.'),
            _registrado
                ? const Aviso(titulo: 'Tus datos están precargados.', detalle: 'Puedes editarlos si lo necesitas antes de confirmar el turno.')
                : const Aviso(titulo: 'Estás pidiendo turno como invitado.', detalle: 'Por favor, completa tus datos para la clínica. (No se creará una cuenta)'),
            CampoTexto(controller: _dni, label: 'DNI', hint: 'Número de documento', tipo: TextInputType.number),
            CampoTexto(controller: _nombre, label: 'Nombre y Apellido', hint: 'Nombre completo'),
            CampoFecha(label: 'Fecha de Nacimiento', valor: _nac, onChanged: (v) {
              setState(() => _nac = v);
              _guardarBorrador();
            }),
            CampoTexto(controller: _email, label: 'Email', hint: 'correo@ejemplo.com', tipo: TextInputType.emailAddress),
            CampoTexto(controller: _tel, label: 'Teléfono', hint: 'Código de área + Número', tipo: TextInputType.phone),
            CampoTexto(controller: _dom, label: 'Domicilio', hint: 'Calle, Número, Localidad'),
            const SeccionForm('Obra Social (Opcional)'),
            CampoTexto(controller: _os, label: 'Nombre Obra Social / Prepaga', hint: 'Ej. OSDE, PAMI'),
            Row(children: [
              Expanded(child: CampoTexto(controller: _plan, label: 'Plan', hint: 'Ej. 210')),
              const SizedBox(width: 12),
              Expanded(child: CampoTexto(controller: _nro, label: 'Nro. Afiliado', hint: 'Ej. 123456')),
            ]),
            const SizedBox(height: 8),
            Boton('Confirmar Turno', onPressed: _restaurando || !vm.horarioDisponible ? null : _confirmar, cargando: vm.enviando),
          ]),
        ),
      ),
    );
  }
}
