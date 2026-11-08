import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/fechas.dart';
import '../../core/theme.dart';
import '../../domain/entities/turno.dart';
import '../viewmodels/turnos_viewmodel.dart';
import '../widgets/common.dart';

class CancelarTurnoScreen extends StatefulWidget {
  const CancelarTurnoScreen({super.key, required this.turno});
  final Turno turno;
  @override
  State<CancelarTurnoScreen> createState() => _CancelarTurnoScreenState();
}

class _CancelarTurnoScreenState extends State<CancelarTurnoScreen> {
  bool _enviando = false;

  Future<void> _cancelar() async {
    setState(() => _enviando = true);
    final err = await context.read<TurnosViewModel>().cancelar(widget.turno);
    if (!mounted) return;
    setState(() => _enviando = false);
    Navigator.of(context).pop();
    if (err != null) {
      mostrarSnack(context, err, error: true);
    } else {
      mostrarSnack(context, 'Turno cancelado exitosamente. La disponibilidad ha sido liberada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.turno;
    return Scaffold(
      body: Pagina(
        child: Column(children: [
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.dangerLight),
            child: const Icon(Icons.warning_amber_rounded, size: 32, color: AppColors.danger),
          ),
          const SizedBox(height: 16),
          const Titulo('Cancelar turno'),
          const Text('¿Realmente deseas cancelar este turno?', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 24),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.especialistaNombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text(t.especialidad, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const Divider(height: 24),
              Text(Fechas.larga(t.fecha, t.hora), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 12),
          const Aviso(
            titulo: 'Se liberará esta disponibilidad en la agenda médica.',
            detalle: 'Si cambias de idea, deberás pedir un turno nuevo.',
            borde: AppColors.warningBorder,
          ),
          const SizedBox(height: 16),
          Boton('No, conservar mi turno', tipo: TipoBoton.contorno, onPressed: () => Navigator.of(context).pop()),
          const SizedBox(height: 12),
          Boton('Sí, cancelar', tipo: TipoBoton.peligro, onPressed: _cancelar, cargando: _enviando),
        ]),
      ),
    );
  }
}
