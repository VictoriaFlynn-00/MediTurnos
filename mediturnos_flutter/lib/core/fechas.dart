class Fechas {
  static const meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio',
    'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  static const dias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// yyyy-MM-dd
  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_dos(d.month)}-${_dos(d.day)}';

  static DateTime parse(String iso) {
    final parts = iso.split('-');
    if (parts.length >= 3) {
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2].split('T')[0].split(' ')[0]);
      return DateTime(year, month, day);
    }
    return DateTime.parse(iso);
  }

  static DateTime hoy() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// "Viernes 18 Octubre"
  static String corta(DateTime d) =>
      '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';

  /// "Viernes 18 Octubre · 09:30 hs"
  static String larga(DateTime d, String hora) => '${corta(d)} · $hora hs';

  /// "18/10/2026" a partir de "2026-10-18"
  static String deIsoAVista(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = parse(iso);
    return '${_dos(d.day)}/${_dos(d.month)}/${d.year}';
  }
}
