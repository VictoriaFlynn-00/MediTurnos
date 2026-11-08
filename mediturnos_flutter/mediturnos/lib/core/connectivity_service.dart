import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Detecta conectividad real y permite SIMULAR modo sin conexión
/// (requisito del prototipo: "Simular modo sin conexión").
/// Perder la red NO es un cambio del ciclo de vida de la app: es un evento
/// de red que ocurre mientras la app sigue en `resumed`.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _c = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _ctrl = StreamController<bool>.broadcast();

  bool _hayRed = true;
  bool _simulado = false;

  bool get online => _hayRed && !_simulado;
  bool get simulandoOffline => _simulado;
  Stream<bool> get onChange => _ctrl.stream;

  Future<void> init() async {
    _hayRed = _tiene(await _c.checkConnectivity());
    _sub = _c.onConnectivityChanged.listen((r) => _cambiar(() => _hayRed = _tiene(r)));
  }

  void simularOffline(bool valor) => _cambiar(() => _simulado = valor);

  bool _tiene(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  void _cambiar(void Function() mutar) {
    final antes = online;
    mutar();
    if (online != antes) {
      _ctrl.add(online);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.close();
    super.dispose();
  }
}
