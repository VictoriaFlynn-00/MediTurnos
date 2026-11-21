import 'package:flutter/foundation.dart';

/// ChangeNotifier que ignora notificaciones tras dispose (evita errores en
/// operaciones asíncronas que terminan cuando la pantalla ya no existe).
class SafeNotifier extends ChangeNotifier {
  bool _muerto = false;
  bool get muerto => _muerto;

  @override
  void dispose() {
    _muerto = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_muerto) super.notifyListeners();
  }
}
