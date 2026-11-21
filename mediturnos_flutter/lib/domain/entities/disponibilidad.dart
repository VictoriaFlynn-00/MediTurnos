enum EstadoHorario { libre, ocupado, pasado }

class HorarioAgenda {
  const HorarioAgenda(this.hora, this.estado);

  final String hora;
  final EstadoHorario estado;

  bool get libre => estado == EstadoHorario.libre;

  factory HorarioAgenda.fromJson(Object? json) {
    // Los datos guardados por versiones anteriores solo contienen horas libres.
    if (json is String) return HorarioAgenda(json, EstadoHorario.libre);
    final horario = json as Map<String, dynamic>;
    return HorarioAgenda(
      horario['hora'] as String,
      EstadoHorario.values.byName(horario['estado'] as String),
    );
  }

  Map<String, String> toJson() => {'hora': hora, 'estado': estado.name};
}

class Disponibilidad {
  final Map<String, List<HorarioAgenda>> horarios;

  /// true si los datos vienen de la caché local (sin conexión).
  final bool desdeCache;

  const Disponibilidad({this.horarios = const {}, this.desdeCache = false});

  factory Disponibilidad.fromJson(Map<String, dynamic> json) => Disponibilidad(
        horarios: json.map((dia, slots) => MapEntry(
            dia, (slots as List).map(HorarioAgenda.fromJson).toList())),
      );

  Map<String, dynamic> toJson() => horarios.map(
      (dia, slots) => MapEntry(dia, slots.map((slot) => slot.toJson()).toList()));

  List<HorarioAgenda> horariosDe(String iso) => horarios[iso] ?? const [];
  bool tieneDia(String iso) => horariosDe(iso).isNotEmpty;
  bool tieneLibres(String iso) => horariosDe(iso).any((h) => h.libre);
}

class SyncResultado {
  final String turnoId;
  final bool exito;
  final String mensaje;
  const SyncResultado(
      {required this.turnoId, required this.exito, required this.mensaje});
}
