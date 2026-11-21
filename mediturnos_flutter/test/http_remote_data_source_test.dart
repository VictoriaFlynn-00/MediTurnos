import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediturnos/core/errors.dart';
import 'package:mediturnos/data/datasources/http_remote_data_source.dart';
import 'package:mediturnos/domain/entities/disponibilidad.dart';
import 'package:mediturnos/domain/entities/paciente.dart';
import 'package:mediturnos/domain/entities/turno.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

HttpRemoteDataSource _crear(MockClientHandler h, {String? token}) =>
    HttpRemoteDataSource('http://api.test/api', () async => token, client: MockClient(h));

const _paciente = Paciente(dni: '34123456', nombre: 'Camila');

Future<int> _pedir(HttpRemoteDataSource ds) => ds.solicitarTurno(
    especialistaId: 1, fecha: '2030-01-07', hora: '09:00', paciente: _paciente);

void main() {
  test('login arma la sesión y NO manda el token', () async {
    late http.Request visto;
    final ds = _crear((req) async {
      visto = req;
      return _json({
        'token': 'abc',
        'usuario': {'id': 1, 'usuario': 'camilaf_99', 'rol': 'paciente'},
        'paciente': {'dni': '34123456', 'nombre': 'Camila'},
      });
    }, token: 'viejo');
    final s = await ds.login(' camilaf_99 ', '12345678');
    expect(s.token, 'abc');
    expect(s.paciente?.dni, '34123456');
    expect(visto.url.toString(), 'http://api.test/api/auth/login');
    expect(visto.headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(visto.body)['usuario'], 'camilaf_99');
  });

  test('solicitarTurno manda el Bearer y devuelve el id', () async {
    late http.Request visto;
    final ds = _crear((req) async {
      visto = req;
      return _json({'id': 15}, 201);
    }, token: 'abc');
    expect(await _pedir(ds), 15);
    expect(visto.headers['Authorization'], 'Bearer abc');
  });

  test('409 HORARIO_NO_DISPONIBLE -> HorarioNoDisponibleException', () async {
    final ds = _crear((_) async => _json({'error': 'x', 'code': 'HORARIO_NO_DISPONIBLE'}, 409));
    expect(() => _pedir(ds), throwsA(isA<HorarioNoDisponibleException>()));
  });

  test('409 USUARIO_EXISTENTE conserva el mensaje del servidor', () async {
    final ds = _crear((_) async => _json({'error': 'Ese DNI ya tiene un usuario', 'code': 'USUARIO_EXISTENTE'}, 409));
    expect(
      () => ds.registrar('camilaf_99', '12345678', _paciente),
      throwsA(isA<UsuarioExistenteException>().having((e) => e.mensaje, 'mensaje', 'Ese DNI ya tiene un usuario')),
    );
  });

  test('401 de login -> credenciales; 401 de token -> sesión expirada', () async {
    final a = _crear((_) async => _json({'error': 'x', 'code': 'CREDENCIALES_INVALIDAS'}, 401));
    expect(() => a.login('x', 'y'), throwsA(isA<CredencialesInvalidasException>()));
    final b = _crear((_) async => _json({'error': 'x', 'code': 'TOKEN_INVALIDO'}, 401));
    expect(() => b.cancelarTurno(1), throwsA(isA<SesionExpiradaException>()));
  });

  test('servidor caído (503) y sin red se tratan como SIN CONEXIÓN (para reintentar)', () async {
    final caido = _crear((_) async => http.Response('<html>Service Unavailable</html>', 503));
    expect(() => _pedir(caido), throwsA(isA<SinConexionException>()));
    final sinRed = _crear((_) async => throw const SocketException('sin red'));
    expect(() => _pedir(sinRed), throwsA(isA<SinConexionException>()));
  });

  test('buscarPaciente: 404 -> null', () async {
    final ds = _crear((_) async => _json({'error': 'x', 'code': 'NO_ENCONTRADO'}, 404));
    expect(await ds.buscarPaciente('40111222'), isNull);
  });

  test('disponibilidadMes y turnosPaciente mapean el JSON', () async {
    final ds = _crear((req) async {
      if (req.url.path.endsWith('/disponibilidad')) {
        expect(req.url.queryParameters, {'anio': '2026', 'mes': '11', 'detalle': '1'});
        return _json({'2026-11-16': [
          {'hora': '09:00', 'estado': 'pasado'},
          {'hora': '10:15', 'estado': 'ocupado'},
          {'hora': '15:30', 'estado': 'libre'},
        ]});
      }
      return _json([
        {
          'id': 7,
          'especialistaId': 3,
          'especialistaNombre': 'Dra. María Ríos',
          'especialidad': 'Pediatría',
          'fecha': '2026-11-20',
          'hora': '16:00',
          'estado': 'activo',
        }
      ]);
    });
    final disp = await ds.disponibilidadMes(3, 2026, 11);
    final slots = disp.horariosDe('2026-11-16');
    expect(slots.map((h) => h.hora), ['09:00', '10:15', '15:30']);
    expect(slots.map((h) => h.estado), [EstadoHorario.pasado, EstadoHorario.ocupado, EstadoHorario.libre]);
    final turnos = await ds.turnosPaciente('34123456');
    expect(turnos.single.remoteId, 7);
    expect(turnos.single.id, 'r7');
    expect(turnos.single.estado, EstadoTurno.activo);
    expect(turnos.single.fecha, DateTime(2026, 11, 20));
  });

  test('crea y libera la reserva temporal con el código en el cuerpo', () async {
    final urls = <String>[];
    final token = 'a' * 64;
    final ds = _crear((req) async {
      urls.add(req.url.path);
      expect(req.method, 'POST');
      expect(jsonDecode(req.body), {
        'especialistaId': 3, 'fecha': '2030-01-07', 'hora': '09:00', 'reservaToken': token,
      });
      if (req.url.path.endsWith('/liberar')) return http.Response('', 204);
      return _json({'venceEn': '2030-01-06T10:07:00.000000Z'}, 201);
    });
    expect(await ds.reservarHorario(3, '2030-01-07', '09:00', token), DateTime.utc(2030, 1, 6, 10, 7));
    await ds.liberarHorario(3, '2030-01-07', '09:00', token);
    expect(urls, ['/api/turnos/reservas', '/api/turnos/reservas/liberar']);
  });
}
