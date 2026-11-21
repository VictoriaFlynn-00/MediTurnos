import '../../core/fechas.dart';

enum EstadoTurno {
  activo,
  cancelado,
  reprogramado,
  pendienteSync,
  rechazado;

  static EstadoTurno desde(String s) => EstadoTurno.values
      .firstWhere((e) => e.name == s, orElse: () => EstadoTurno.activo);
}

class Turno {
  /// Id local (único en el dispositivo). Los turnos creados offline tienen
  /// remoteId == null hasta que se sincronizan.
  final String id;
  final int? remoteId;
  final String pacienteDni;
  final int especialistaId;
  final String especialistaNombre;
  final String especialidad;
  final DateTime fecha;
  final String hora; // HH:mm
  final EstadoTurno estado;

  const Turno({
    required this.id,
    this.remoteId,
    required this.pacienteDni,
    required this.especialistaId,
    required this.especialistaNombre,
    required this.especialidad,
    required this.fecha,
    required this.hora,
    required this.estado,
  });

  DateTime get fechaHora {
    final p = hora.split(':');
    return DateTime(
        fecha.year, fecha.month, fecha.day, int.parse(p[0]), int.parse(p[1]));
  }

  bool get esFuturo => fechaHora.isAfter(DateTime.now());

  bool get esProximo =>
      (estado == EstadoTurno.activo || estado == EstadoTurno.pendienteSync) &&
      esFuturo;

  Turno copyWith({String? id, int? remoteId, EstadoTurno? estado}) => Turno(
        id: id ?? this.id,
        remoteId: remoteId ?? this.remoteId,
        pacienteDni: pacienteDni,
        especialistaId: especialistaId,
        especialistaNombre: especialistaNombre,
        especialidad: especialidad,
        fecha: fecha,
        hora: hora,
        estado: estado ?? this.estado,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'remote_id': remoteId,
        'paciente_dni': pacienteDni,
        'especialista_id': especialistaId,
        'especialista_nombre': especialistaNombre,
        'especialidad': especialidad,
        'fecha': Fechas.iso(fecha),
        'hora': hora,
        'estado': estado.name,
      };

  factory Turno.fromMap(Map<String, Object?> m) => Turno(
        id: m['id'] as String,
        remoteId: m['remote_id'] as int?,
        pacienteDni: m['paciente_dni'] as String,
        especialistaId: m['especialista_id'] as int,
        especialistaNombre: m['especialista_nombre'] as String,
        especialidad: m['especialidad'] as String,
        fecha: DateTime.parse(m['fecha'] as String),
        hora: m['hora'] as String,
        estado: EstadoTurno.desde(m['estado'] as String),
      );
}
