import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/di.dart';
import '../../core/theme.dart';

/// Escucha los resultados de sincronización y los muestra al usuario
/// ("turno confirmado" / "el horario ya no está disponible, elegí otro").
/// También reintenta sincronizar cuando la app vuelve a primer plano
/// (resumed), tras haber estado en segundo plano.
class SyncListener extends StatefulWidget {
  const SyncListener({super.key, required this.child, required this.messengerKey});
  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  @override
  State<SyncListener> createState() => _SyncListenerState();
}

class _SyncListenerState extends State<SyncListener> with WidgetsBindingObserver {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final di = context.read<Di>();
    _sub = di.turnoRepo.resultadosSync.listen((res) {
      final m = widget.messengerKey.currentState;
      if (m == null) return;
      for (final r in res) {
        m.showSnackBar(SnackBar(
          content: Text(r.mensaje),
          backgroundColor: r.exito ? AppColors.success : AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // TODO(sesión siguiente): verificar/renovar el JWT antes de nuevas acciones.
      context.read<Di>().sincronizar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
