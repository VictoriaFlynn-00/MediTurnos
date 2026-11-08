import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/connectivity_service.dart';
import '../../core/theme.dart';
import '../../domain/entities/especialista.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/inicio_viewmodel.dart';
import '../widgets/common.dart';
import 'agenda_screen.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InicioViewModel>();
    final auth = context.watch<AuthViewModel>();
    final conn = context.watch<ConnectivityService>();
    final nombre = auth.paciente?.nombre;

    return Pagina(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CabeceraMarca(acciones: [
          IconButton(
            tooltip: 'Simular modo sin conexión',
            onPressed: () => conn.simularOffline(!conn.simulandoOffline),
            icon: Icon(conn.online ? Icons.wifi : Icons.wifi_off,
                color: conn.online ? AppColors.success : AppColors.warning),
          ),
          TextButton.icon(
            onPressed: () => context.read<AuthViewModel>().cerrarSesion(),
            icon: const Icon(Icons.logout, size: 16, color: AppColors.danger),
            label: Text(auth.autenticado ? 'Salir' : 'Volver',
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
        const BannerOffline(),
        Titulo(nombre != null ? 'Hola, $nombre 👋' : 'Bienvenido'),
        const Subtitulo('¿Qué atención estás buscando hoy?'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            onChanged: vm.setQuery,
            decoration: InputDecoration(
              hintText: 'Buscar médico, especialidad...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            if (vm.esRegistrado) _chip(vm, 'Mis médicos', FiltroInicio.misMedicos),
            _chip(vm, 'Profesionales', FiltroInicio.profesionales),
            _chip(vm, 'Especialidades', FiltroInicio.especialidades),
          ]),
        ),
        const SizedBox(height: 24),
        Row(children: [
          const Text('Resultados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (vm.especialidadId != null)
            InputChip(
              label: Text(vm.especialidades.where((e) => e.id == vm.especialidadId).map((e) => e.nombre).firstOrNull ?? ''),
              onDeleted: vm.quitarFiltroEspecialidad,
            ),
        ]),
        const SizedBox(height: 16),
        if (vm.cargando)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (vm.filtro == FiltroInicio.especialidades)
          ..._especialidades(context, vm)
        else
          ..._profesionales(context, vm),
      ]),
    );
  }

  Widget _chip(InicioViewModel vm, String texto, FiltroInicio f) {
    final activo = vm.filtro == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: activo ? AppColors.primary : AppColors.textMuted)),
        selected: activo,
        showCheckmark: false,
        selectedColor: AppColors.primaryLight,
        backgroundColor: Colors.white,
        side: BorderSide(color: activo ? AppColors.primaryLight : AppColors.border),
        shape: const StadiumBorder(),
        onSelected: (_) => vm.setFiltro(f),
      ),
    );
  }

  List<Widget> _profesionales(BuildContext context, InicioViewModel vm) {
    final l = vm.profesionales;
    if (l.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text('No encontramos profesionales para mostrar.', style: TextStyle(color: AppColors.textMuted))),
        )
      ];
    }
    return l
        .map((m) => AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgendaScreen(especialista: m))),
              child: Row(children: [
                Avatar(m.iniciales),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(m.especialidad, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primary),
              ]),
            ))
        .toList();
  }

  List<Widget> _especialidades(BuildContext context, InicioViewModel vm) => vm.especialidadesFiltradas
      .map((Especialidad e) => AppCard(
            onTap: () => vm.filtrarPorEspecialidad(e.id),
            child: Row(children: [
              const Avatar('', child: Icon(Icons.monitor_heart_outlined, color: AppColors.textMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Ver ${vm.contar(e.id)} profesionales', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ))
      .toList();
}
