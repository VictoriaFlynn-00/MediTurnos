class Especialidad {
  final int id;
  final String nombre;
  const Especialidad({required this.id, required this.nombre});

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre};
  factory Especialidad.fromJson(Map<String, dynamic> j) =>
      Especialidad(id: j['id'] as int, nombre: j['nombre'] as String);
}

class Especialista {
  final int id;
  final String prefijo; // Dr. / Dra.
  final String nombre;
  final String apellido;
  final int especialidadId;
  final String especialidad;

  const Especialista({
    required this.id,
    required this.prefijo,
    required this.nombre,
    required this.apellido,
    required this.especialidadId,
    required this.especialidad,
  });

  String get nombreCompleto => '$prefijo $nombre $apellido';

  String get iniciales =>
      '${nombre.isNotEmpty ? nombre[0] : ''}${apellido.isNotEmpty ? apellido[0] : ''}'
          .toUpperCase();

  Map<String, dynamic> toJson() => {
        'id': id,
        'prefijo': prefijo,
        'nombre': nombre,
        'apellido': apellido,
        'especialidadId': especialidadId,
        'especialidad': especialidad,
      };

  factory Especialista.fromJson(Map<String, dynamic> j) => Especialista(
        id: j['id'] as int,
        prefijo: j['prefijo'] as String,
        nombre: j['nombre'] as String,
        apellido: j['apellido'] as String,
        especialidadId: j['especialidadId'] as int,
        especialidad: j['especialidad'] as String,
      );
}
