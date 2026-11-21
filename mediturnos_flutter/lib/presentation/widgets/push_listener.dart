import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di.dart';
import '../../core/push_service.dart';
import '../viewmodels/auth_viewmodel.dart';

class PushListener extends StatefulWidget {
  const PushListener(
      {super.key, required this.child, required this.messengerKey});

  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  State<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends State<PushListener>
    with WidgetsBindingObserver {
  late final AuthViewModel _auth;
  late final PushService _push;
  late final StreamSubscription<AvisoPush> _avisos;
  late final StreamSubscription<bool> _conexion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final di = context.read<Di>();
    _push = di.push;
    _avisos = _push.avisos.listen(_mostrar);
    _conexion = di.connectivity.onChange.listen((online) {
      if (online) _push.reintentar();
    });
    _push.iniciar();
    _auth = context.read<AuthViewModel>()..addListener(_actualizarAcceso);
    _actualizarAcceso();
  }

  void _actualizarAcceso() {
    if (!_auth.restaurando) {
      _push.actualizarAcceso(_auth.session, invitado: _auth.invitado);
    }
  }

  void _mostrar(AvisoPush aviso) {
    final texto = switch (aviso) {
      AvisoPush.confirmacion => 'Tu turno se guardó correctamente.',
      AvisoPush.conflicto =>
        'El horario solicitado ya no está disponible. Elegí otro.',
    };
    widget.messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _push.reintentar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_actualizarAcceso);
    unawaited(_avisos.cancel());
    unawaited(_conexion.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
