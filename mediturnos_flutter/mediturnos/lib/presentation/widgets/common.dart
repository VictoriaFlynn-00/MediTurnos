import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/connectivity_service.dart';
import '../../core/fechas.dart';
import '../../core/theme.dart';
import '../../domain/entities/turno.dart';

OutlineInputBorder _borde(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: 1.5));

/// Estilo común de los campos de texto (según el mockup).
InputDecoration decoracionCampo(String? hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      border: _borde(AppColors.border),
      enabledBorder: _borde(AppColors.border),
      focusedBorder: _borde(AppColors.primary),
      disabledBorder: _borde(AppColors.border),
    );

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 32});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Icon(Icons.add, color: AppColors.primary, size: size * 0.6, weight: 900),
      );
}

class CabeceraMarca extends StatelessWidget {
  const CabeceraMarca({super.key, this.acciones = const []});
  final List<Widget> acciones;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          const LogoMark(),
          const SizedBox(width: 10),
          const Text('MediTurnos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: -0.5)),
          const Spacer(),
          ...acciones,
        ]),
      );
}

class BarraSuperior extends StatelessWidget {
  const BarraSuperior({super.key, required this.titulo, this.onBack});
  final String titulo;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(children: [
          InkWell(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border)),
              child: const Icon(Icons.chevron_left, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(titulo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        ]),
      );
}

/// Contenedor de página: padding, scroll y ancho máximo (responsive en tablets).
class Pagina extends StatelessWidget {
  const Pagina({super.key, required this.child, this.bottom = 24});
  final Widget child;
  final double bottom;
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, bottom),
              child: child,
            ),
          ),
        ),
      );
}

class Titulo extends StatelessWidget {
  const Titulo(this.texto, {super.key, this.size = 24});
  final String texto;
  final double size;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texto,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w800)),
      );
}

class Subtitulo extends StatelessWidget {
  const Subtitulo(this.texto, {super.key, this.centrado = false});
  final String texto;
  final bool centrado;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(texto,
            textAlign: centrado ? TextAlign.center : TextAlign.start,
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textMuted)),
      );
}

class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.tipo,
    this.oculto = false,
    this.habilitado = true,
    this.onChanged,
  });
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final TextInputType? tipo;
  final bool oculto;
  final bool habilitado;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(label!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
          TextField(
            controller: controller,
            keyboardType: tipo,
            obscureText: oculto,
            enabled: habilitado,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14),
            decoration: decoracionCampo(hint),
          ),
        ]),
      );
}

/// Campo de fecha (abre selector). Guarda yyyy-MM-dd en [valor].
class CampoFecha extends StatelessWidget {
  const CampoFecha({super.key, required this.label, required this.valor, required this.onChanged});
  final String label;
  final String valor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final ini = DateTime.tryParse(valor) ?? DateTime(1990, 1, 1);
              final r = await showDatePicker(
                context: context,
                initialDate: ini,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (r != null) onChanged(Fechas.iso(r));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.5)),
              child: Text(valor.isEmpty ? 'dd/mm/aaaa' : Fechas.deIsoAVista(valor),
                  style: TextStyle(fontSize: 14, color: valor.isEmpty ? AppColors.textMuted : AppColors.textMain)),
            ),
          ),
        ]),
      );
}

enum TipoBoton { primario, contorno, peligro, peligroContorno }

class Boton extends StatelessWidget {
  const Boton(this.texto, {super.key, this.onPressed, this.tipo = TipoBoton.primario, this.cargando = false, this.subtexto});
  final String texto;
  final String? subtexto;
  final VoidCallback? onPressed;
  final TipoBoton tipo;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final pequeno = tipo == TipoBoton.peligroContorno;
    final (Color bg, Color fg, BorderSide? borde) = switch (tipo) {
      TipoBoton.primario => (AppColors.primary, Colors.white, null),
      TipoBoton.contorno => (Colors.transparent, AppColors.primary, const BorderSide(color: AppColors.primary, width: 2)),
      TipoBoton.peligro => (AppColors.danger, Colors.white, null),
      TipoBoton.peligroContorno => (Colors.transparent, AppColors.danger, const BorderSide(color: AppColors.danger, width: 1.5)),
    };
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg == Colors.transparent ? Colors.transparent : AppColors.disabled,
          elevation: 0,
          side: borde,
          padding: EdgeInsets.symmetric(vertical: pequeno ? 8 : 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pequeno ? 8 : 14)),
        ),
        child: cargando
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text(texto, style: TextStyle(fontSize: pequeno ? 13 : 15, fontWeight: FontWeight.w700)),
                if (subtexto != null)
                  Text(subtexto!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
              ]),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.color = Colors.white, this.borderColor = AppColors.border, this.margin = const EdgeInsets.only(bottom: 12)});
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final EdgeInsets margin;
  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor)),
              child: child,
            ),
          ),
        ),
      );
}

class Avatar extends StatelessWidget {
  const Avatar(this.texto, {super.key, this.size = 48, this.child});
  final String texto;
  final double size;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
        child: child ??
            Text(texto,
                style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: AppColors.primary)),
      );
}

class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, required this.fondo, required this.color});
  final String texto;
  final Color fondo;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
        child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  /// Etiqueta según el estado del turno (confirmado, pendiente, etc.).
  factory Etiqueta.deTurno(Turno t) {
    switch (t.estado) {
      case EstadoTurno.activo:
        return t.esFuturo
            ? const Etiqueta('Confirmado', fondo: Color(0xFFE0F2FE), color: AppColors.primary)
            : const Etiqueta('Completado', fondo: AppColors.bgApp, color: AppColors.textMuted);
      case EstadoTurno.pendienteSync:
        return const Etiqueta('Pendiente de sincronizar', fondo: AppColors.warningLight, color: AppColors.warningText);
      case EstadoTurno.cancelado:
        return const Etiqueta('Cancelado', fondo: AppColors.dangerLight, color: AppColors.danger);
      case EstadoTurno.rechazado:
        return const Etiqueta('Horario no disponible', fondo: AppColors.dangerLight, color: AppColors.danger);
      case EstadoTurno.reprogramado:
        return const Etiqueta('Reprogramado', fondo: AppColors.warningLight, color: AppColors.warningText);
    }
  }
}

class Aviso extends StatelessWidget {
  const Aviso({super.key, required this.titulo, this.detalle, this.fondo = AppColors.warningLight, this.color = AppColors.warningText, this.borde});
  final String titulo;
  final String? detalle;
  final Color fondo;
  final Color color;
  final Color? borde;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(12),
            border: borde == null ? null : Border.all(color: borde!)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          if (detalle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(detalle!, style: TextStyle(fontSize: 13, color: color)),
            ),
        ]),
      );
}

class SeccionForm extends StatelessWidget {
  const SeccionForm(this.titulo, {super.key});
  final String titulo;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );
}

/// Franja visible cuando no hay conexión (real o simulada).
class BannerOffline extends StatelessWidget {
  const BannerOffline({super.key});
  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().online;
    if (online) return const SizedBox.shrink();
    return const Aviso(
      titulo: 'Sin conexión · modo offline',
      detalle: 'Ves datos guardados en tu dispositivo. Lo que hagas se sincronizará al recuperar la señal.',
    );
  }
}

void mostrarSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.textMain,
      behavior: SnackBarBehavior.floating,
    ));
}
