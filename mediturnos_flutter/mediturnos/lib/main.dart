import 'package:flutter/material.dart';
import 'app.dart';
import 'core/di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final di = await Di.crear();
  runApp(MediTurnosApp(di: di));
}
