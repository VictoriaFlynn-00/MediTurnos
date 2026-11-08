import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/turno.dart';

class ColaItem {
  final int id;
  final String tipo; // 'solicitar' | 'cancelar'
  final String? localId;
  final Map<String, dynamic> payload;
  final int intentos;
  ColaItem(this.id, this.tipo, this.localId, this.payload, this.intentos);
}

/// SQLite en el dispositivo: turnos propios, cola de sincronización y caché
/// genérica (catálogo, disponibilidad, perfil, borrador de formulario).
class LocalDb {
  Future<Database>? _abriendo;
  Future<Database> get _d => _abriendo ??= _abrir();

  Future<Database> _abrir() async {
    final path = p.join(await getDatabasesPath(), 'mediturnos.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE turnos(
          id TEXT PRIMARY KEY,
          remote_id INTEGER,
          paciente_dni TEXT NOT NULL,
          especialista_id INTEGER NOT NULL,
          especialista_nombre TEXT NOT NULL,
          especialidad TEXT NOT NULL,
          fecha TEXT NOT NULL,
          hora TEXT NOT NULL,
          estado TEXT NOT NULL)''');
      await db.execute('''
        CREATE TABLE sync_queue(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tipo TEXT NOT NULL,
          local_id TEXT,
          payload TEXT NOT NULL,
          intentos INTEGER NOT NULL DEFAULT 0,
          creado TEXT NOT NULL)''');
      await db.execute(
          'CREATE TABLE cache(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    });
  }

  // ---- Turnos ----
  Future<void> upsertTurno(Turno t) async => (await _d)
      .insert('turnos', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Turno>> turnosDe(String dni) async {
    final rows = await (await _d).query('turnos',
        where: 'paciente_dni = ?',
        whereArgs: [dni],
        orderBy: 'fecha DESC, hora DESC');
    return rows.map(Turno.fromMap).toList();
  }

  Future<List<Turno>> turnosActivosDeEspecialista(int espId) async {
    final rows = await (await _d).query('turnos',
        where: "especialista_id = ? AND estado IN ('activo','pendienteSync')",
        whereArgs: [espId]);
    return rows.map(Turno.fromMap).toList();
  }

  Future<void> actualizarEstado(String id, EstadoTurno e, {int? remoteId}) async {
    final vals = <String, Object?>{'estado': e.name};
    if (remoteId != null) vals['remote_id'] = remoteId;
    await (await _d).update('turnos', vals, where: 'id = ?', whereArgs: [id]);
  }

  /// Reemplaza los turnos ya sincronizados del paciente por los del servidor,
  /// preservando los pendientes/rechazados locales.
  Future<void> reemplazarSincronizados(String dni, List<Turno> nuevos) async {
    final db = await _d;
    await db.transaction((txn) async {
      await txn.delete('turnos',
          where:
              "paciente_dni = ? AND estado IN ('activo','cancelado','reprogramado')",
          whereArgs: [dni]);
      for (final t in nuevos) {
        await txn.insert('turnos', t.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ---- Cola de sincronización ----
  Future<int> encolar(String tipo, String? localId, Map<String, dynamic> payload) async =>
      (await _d).insert('sync_queue', {
        'tipo': tipo,
        'local_id': localId,
        'payload': jsonEncode(payload),
        'intentos': 0,
        'creado': DateTime.now().toIso8601String(),
      });

  Future<List<ColaItem>> cola() async {
    final rows = await (await _d).query('sync_queue', orderBy: 'id ASC');
    return rows
        .map((r) => ColaItem(
            r['id'] as int,
            r['tipo'] as String,
            r['local_id'] as String?,
            Map<String, dynamic>.from(jsonDecode(r['payload'] as String) as Map),
            r['intentos'] as int))
        .toList();
  }

  Future<int> cantidadCola() async {
    final r = await (await _d).rawQuery('SELECT COUNT(*) c FROM sync_queue');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<void> borrarCola(int id) async =>
      (await _d).delete('sync_queue', where: 'id = ?', whereArgs: [id]);

  Future<void> borrarColaDeTurno(String localId) async => (await _d)
      .delete('sync_queue', where: 'local_id = ?', whereArgs: [localId]);

  Future<void> sumarIntento(int id) async => (await _d)
      .rawUpdate('UPDATE sync_queue SET intentos = intentos + 1 WHERE id = ?', [id]);

  // ---- Caché clave/valor ----
  Future<void> putCache(String key, String value) async => (await _d).insert(
      'cache', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<String?> getCache(String key) async {
    final r = await (await _d)
        .query('cache', where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  Future<void> borrarCache(String key) async =>
      (await _d).delete('cache', where: 'key = ?', whereArgs: [key]);

  /// Al cerrar sesión se elimina todo lo propio del usuario (no el catálogo).
  Future<void> limpiarDatosUsuario() async {
    final db = await _d;
    await db.delete('turnos');
    await db.delete('sync_queue');
    await db.delete('cache', where: "key LIKE 'user:%' OR key LIKE 'draft:%'");
  }
}
