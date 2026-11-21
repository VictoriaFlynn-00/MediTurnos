import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/di.dart';
import '../../core/errors.dart';
import '../../core/fechas.dart';
import '../../core/theme.dart';
import '../../domain/entities/especialista.dart';
import '../../domain/entities/reserva_temporal.dart';
import '../../domain/entities/turno.dart';
import '../viewmodels/agenda_viewmodel.dart';
import '../widgets/common.dart';
import 'confirmar_screen.dart';
import 'exito_screen.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key, required this.especialista});
  final Especialista especialista;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (c) => AgendaViewModel(especialista, c.read<Di>().disponibilidad)..cargarMes(),
        child: _AgendaView(especialista: especialista),
      );
}

class _AgendaView extends StatelessWidget {
  const _AgendaView({required this.especialista});
  final Especialista especialista;

  Future<void> _abrirFormulario(BuildContext context, AgendaViewModel vm) async {
    final fecha = vm.fechaSeleccionada;
    final hora = vm.horaSel;
    if (vm.reservando || fecha == null || hora == null) return;
    final pedir = context.read<Di>().solicitarTurno;
    vm.cambiarReserva(true);
    ReservaTemporal? reserva;
    (Turno, String)? resultado;
    try {
      reserva = await pedir.reservar(especialista.id, fecha, hora);
      if (context.mounted) {
        resultado = await Navigator.of(context).push(MaterialPageRoute<(Turno, String)>(
          builder: (_) => ConfirmarScreen(
            especialista: especialista, fecha: fecha, hora: hora, reserva: reserva,
          ),
        ));
      }
    } on AppException catch (e) {
      if (context.mounted) mostrarSnack(context, e.mensaje, error: true);
    } finally {
      final tomada = reserva;
      if (tomada != null && resultado == null) {
        try {
          await pedir.liberar(especialista.id, fecha, hora, tomada);
        } on AppException {
          // Si no podemos liberar el horario, la reserva vence en el servidor.
        }
      }
      if (context.mounted && resultado == null) await vm.cargarMes(conservarFecha: true);
      vm.cambiarReserva(false);
    }

    if (!context.mounted || resultado == null) return;
    final (turno, email) = resultado;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => ExitoScreen(turno: turno, email: email)),
      (ruta) => ruta.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgendaViewModel>();
    return Scaffold(
      body: Pagina(
        child: Column(children: [
          const BarraSuperior(titulo: 'Elegí tu turno'),
          Avatar(especialista.iniciales, size: 64),
          const SizedBox(height: 12),
          Text(especialista.nombreCompleto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(especialista.especialidad, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          const BannerOffline(),
          _Calendario(vm: vm),
          if (vm.error != null) Aviso(titulo: vm.error!, fondo: AppColors.dangerLight, color: AppColors.danger),
          if (vm.disp.desdeCache && !vm.cargando)
            Aviso(
              titulo: vm.disp.horarios.isEmpty
                  ? 'Sin datos de este mes guardados en el dispositivo'
                  : 'Mostrando disponibilidad guardada',
              detalle: vm.disp.horarios.isEmpty
                  ? 'Conectate a internet para ver los turnos disponibles.'
                  : 'La disponibilidad real se confirma al recuperar la conexión.',
            ),
          if (vm.fechaSel != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Horarios del ${Fechas.corta(vm.fechaSeleccionada!)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
              children: vm.horarios.map((h) {
                final sel = h.libre && vm.horaSel == h.hora;
                final onTap = h.libre && !vm.reservando && !vm.cargando
                    ? () => vm.seleccionarHora(h.hora)
                    : null;
                return Semantics(
                  button: true, enabled: onTap != null, onTap: onTap,
                  label: '${h.hora}, ${h.estado.name}', excludeSemantics: true,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : h.libre ? Colors.white : AppColors.bgApp,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: 1.5),
                      ),
                      child: Text(h.hora, style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : h.libre ? AppColors.textMain : AppColors.textMuted,
                        decoration: h.libre ? null : TextDecoration.lineThrough,
                      )),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Boton('Continuar',
                cargando: vm.reservando,
                onPressed: vm.horaSel == null ? null : () => _abrirFormulario(context, vm)),
          ],
        ]),
      ),
    );
  }
}

class _Calendario extends StatelessWidget {
  const _Calendario({required this.vm});
  final AgendaViewModel vm;

  @override
  Widget build(BuildContext context) {
    final primero = vm.mes;
    final diasMes = DateTime(primero.year, primero.month + 1, 0).day;
    final vacios = primero.weekday % 7; // domingo = 0
    final celdas = <Widget>[
      for (var i = 0; i < vacios; i++) const SizedBox.shrink(),
      for (var d = 1; d <= diasMes; d++) _dia(d),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
              onPressed: vm.puedeIrAtras ? vm.mesAnterior : null,
              icon: const Icon(Icons.chevron_left)),
          Text('${Fechas.meses[primero.month - 1]} ${primero.year}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          IconButton(
              onPressed: vm.puedeIrAdelante ? vm.mesSiguiente : null,
              icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 8),
        Row(
          children: ['Do', 'Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sa']
              .map((d) => Expanded(
                  child: Center(
                      child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)))))
              .toList(),
        ),
        const SizedBox(height: 8),
        if (vm.cargando)
          const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
        else
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: celdas,
          ),
        const SizedBox(height: 16),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Leyenda(color: AppColors.successLight, texto: 'Libre'),
          SizedBox(width: 12),
          _Leyenda(color: AppColors.bgApp, texto: 'Ocupado / Pasado', borde: true),
        ]),
      ]),
    );
  }

  Widget _dia(int d) {
    final iso = Fechas.iso(DateTime(vm.mes.year, vm.mes.month, d));
    final atiende = vm.disp.tieneDia(iso);
    final libre = vm.disp.tieneLibres(iso);
    final sel = vm.fechaSel == iso;
    return GestureDetector(
      onTap: atiende && !vm.reservando ? () => vm.seleccionarFecha(iso) : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: sel ? AppColors.primary : (libre ? AppColors.successLight : AppColors.bgApp),
          border: Border.all(color: sel ? AppColors.primary : Colors.transparent, width: 2),
        ),
        child: Text('$d',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: atiende && !libre ? TextDecoration.lineThrough : null,
                color: sel ? Colors.white : (libre ? AppColors.successDark : AppColors.disabled))),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto, this.borde = false});
  final Color color;
  final String texto;
  final bool borde;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: borde ? Border.all(color: AppColors.border) : null),
        ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
      ]);
}
