import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'fechas.dart';

const _zona = 'America/Argentina/Buenos_Aires';
const _titulo = 'Turno médico · MediTurnos';
const _duracion = Duration(minutes: 30);
const _canal = MethodChannel('com.mediturnos.mediturnos/calendario');

Future<bool> abrirCalendarioDelTurno(DateTime fecha, String hora) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final abierto = await _canal.invokeMethod<bool>('crearEvento', {
      'fechaHora': '${Fechas.iso(fecha)} $hora',
      'zona': _zona,
      'titulo': _titulo,
      'duracionMs': _duracion.inMilliseconds,
    });
    if (abierto == true) return true;
  }
  // En el teléfono el navegador conserva los parámetros del formulario web.
  final movil = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS);
  return launchUrl(enlaceGoogleCalendar(fecha, hora),
      mode: movil ? LaunchMode.inAppBrowserView : LaunchMode.platformDefault);
}

Uri enlaceGoogleCalendar(DateTime fecha, String hora) {
  final partes = hora.split(':');
  // UTC permite sumar minutos de reloj independientemente de la zona del teléfono.
  final inicio = DateTime.utc(fecha.year, fecha.month, fecha.day,
      int.parse(partes[0]), int.parse(partes[1]));
  final fin = inicio.add(_duracion);
  String marca(DateTime reloj) =>
      reloj.toIso8601String().substring(0, 19).replaceAll(RegExp('[-:]'), '');

  return Uri.https('calendar.google.com', '/calendar/r/eventedit', {
    'action': 'TEMPLATE',
    'text': _titulo,
    'dates': '${marca(inicio)}/${marca(fin)}',
    'ctz': _zona,
    'stz': _zona,
    'etz': _zona,
  });
}
