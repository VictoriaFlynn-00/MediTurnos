import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/fechas.dart';
import '../../core/google_calendar.dart';
import '../../core/theme.dart';
import '../../domain/entities/turno.dart';
import '../widgets/common.dart';

class ExitoScreen extends StatelessWidget {
  const ExitoScreen({super.key, required this.turno, required this.email});
  final Turno turno;
  final String email;

  Future<void> _abrirCalendario(BuildContext context) async {
    try {
      if (await abrirCalendarioDelTurno(turno.fecha, turno.hora)) return;
    } on PlatformException {
      // La plataforma puede rechazar la apertura de un enlace externo.
    }
    if (context.mounted) {
      mostrarSnack(context, 'No se pudo abrir Google Calendar.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendiente = turno.estado == EstadoTurno.pendienteSync;
    final color = pendiente ? AppColors.warning : AppColors.success;
    return Scaffold(
      body: Pagina(
        child: Column(children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, color: pendiente ? AppColors.warningLight : AppColors.successLight),
            child: Icon(pendiente ? Icons.cloud_off : Icons.check, size: 40, color: color),
          ),
          const SizedBox(height: 24),
          Text(pendiente ? 'Turno guardado' : '¡Tu turno está confirmado!',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (pendiente)
            const Subtitulo('Al recuperar la conexión, verificaremos si el horario sigue disponible.', centrado: true),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(turno.especialistaNombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text(turno.especialidad, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const Divider(height: 24),
              Text(Fechas.larga(turno.fecha, turno.hora),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 12),
          if (!pendiente && email.isNotEmpty)
            Aviso(
              titulo: 'Correo para la confirmación',
              detalle: email,
              fondo: AppColors.primaryLight,
              color: AppColors.textMain,
            ),
          const SizedBox(height: 12),
          if (turno.estado == EstadoTurno.activo && turno.remoteId != null) ...[
            OutlinedButton.icon(
              onPressed: () => _abrirCalendario(context),
              icon: const Icon(Icons.event_outlined),
              label: const Text('Agregar a Google Calendar'),
            ),
            const SizedBox(height: 12),
          ],
          Boton('Volver al inicio', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
        ]),
      ),
    );
  }
}
