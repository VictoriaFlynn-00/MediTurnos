import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/fechas.dart';
import '../../core/theme.dart';
import '../../domain/entities/turno.dart';
import '../viewmodels/turnos_viewmodel.dart';
import '../widgets/common.dart';
import 'cancelar_turno_screen.dart';

class TurnosScreen extends StatelessWidget {
  const TurnosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TurnosViewModel>();
    final lista = vm.tab == TabTurnos.proximos ? vm.proximos : vm.historial;
    return Pagina(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CabeceraMarca(),
        const Titulo('Mis turnos'),
        const SizedBox(height: 8),
        const BannerOffline(),
        Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _tab(vm, 'Próximos', TabTurnos.proximos),
            _tab(vm, 'Historial', TabTurnos.historial),
          ]),
        ),
        if (vm.cargando && vm.turnos.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                  vm.tab == TabTurnos.proximos ? 'No tienes turnos próximos agendados.' : 'Todavía no tenés historial de turnos.',
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
          )
        else
          ...lista.map((t) => _TarjetaTurno(turno: t)),
      ]),
    );
  }

  Widget _tab(TurnosViewModel vm, String texto, TabTurnos t) {
    final activo = vm.tab == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => vm.setTab(t),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: activo ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1))] : null,
          ),
          child: Text(texto,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: activo ? AppColors.primary : AppColors.textMuted)),
        ),
      ),
    );
  }
}

class _TarjetaTurno extends StatelessWidget {
  const _TarjetaTurno({required this.turno});
  final Turno turno;

  @override
  Widget build(BuildContext context) {
    final puedeCancelar = turno.esProximo;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(turno.especialistaNombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text(turno.especialidad, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ]),
          ),
          Etiqueta.deTurno(turno),
        ]),
        const SizedBox(height: 12),
        Text(Fechas.larga(turno.fecha, turno.hora),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: puedeCancelar ? AppColors.textMain : AppColors.textMuted)),
        if (puedeCancelar) ...[
          const SizedBox(height: 16),
          Boton('Cancelar turno',
              tipo: TipoBoton.peligroContorno,
              onPressed: () {
                final vm = context.read<TurnosViewModel>();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: vm,
                    child: CancelarTurnoScreen(turno: turno),
                  ),
                ));
              }),
        ],
      ]),
    );
  }
}
