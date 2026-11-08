class Disponibilidad {
  /// Clave: fecha yyyy-MM-dd. Valor: horarios libres HH:mm.
  final Map<String, List<String>> libres;

  /// true si los datos vienen de la caché local (sin conexión).
  final bool desdeCache;

  const Disponibilidad({required this.libres, this.desdeCache = false});

  bool tieneDia(String iso) => (libres[iso] ?? const []).isNotEmpty;
  List<String> horariosDe(String iso) => libres[iso] ?? const [];
}

class SyncResultado {
  final String turnoId;
  final bool exito;
  final String mensaje;
  const SyncResultado(
      {required this.turnoId, required this.exito, required this.mensaje});
}
