class Paciente {
  final String dni;
  final String nombre;
  final String apellido;
  final String fechaNacimiento; // yyyy-MM-dd o ''
  final String email;
  final String telefono;
  final String domicilio;
  final String obraSocial;
  final String plan;
  final String nroAfiliado;
  final int? usuarioId;

  const Paciente({
    required this.dni,
    required this.nombre,
    this.apellido = '',
    this.fechaNacimiento = '',
    this.email = '',
    this.telefono = '',
    this.domicilio = '',
    this.obraSocial = '',
    this.plan = '',
    this.nroAfiliado = '',
    this.usuarioId,
  });

  String get nombreCompleto => apellido.isEmpty ? nombre : '$nombre $apellido';

  /// "María Laura Pérez" -> ("María Laura", "Pérez")
  static (String, String) partirNombre(String completo) {
    final t = completo.trim().split(RegExp(r'\s+'));
    if (t.length <= 1) return (t.first, '');
    return (t.sublist(0, t.length - 1).join(' '), t.last);
  }

  Paciente copyWith({
    String? dni,
    String? nombre,
    String? apellido,
    String? fechaNacimiento,
    String? email,
    String? telefono,
    String? domicilio,
    String? obraSocial,
    String? plan,
    String? nroAfiliado,
    int? usuarioId,
  }) =>
      Paciente(
        dni: dni ?? this.dni,
        nombre: nombre ?? this.nombre,
        apellido: apellido ?? this.apellido,
        fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
        email: email ?? this.email,
        telefono: telefono ?? this.telefono,
        domicilio: domicilio ?? this.domicilio,
        obraSocial: obraSocial ?? this.obraSocial,
        plan: plan ?? this.plan,
        nroAfiliado: nroAfiliado ?? this.nroAfiliado,
        usuarioId: usuarioId ?? this.usuarioId,
      );

  Map<String, dynamic> toJson() => {
        'dni': dni,
        'nombre': nombre,
        'apellido': apellido,
        'fechaNacimiento': fechaNacimiento,
        'email': email,
        'telefono': telefono,
        'domicilio': domicilio,
        'obraSocial': obraSocial,
        'plan': plan,
        'nroAfiliado': nroAfiliado,
        'usuarioId': usuarioId,
      };

  factory Paciente.fromJson(Map<String, dynamic> j) => Paciente(
        dni: j['dni'] as String,
        nombre: (j['nombre'] ?? '') as String,
        apellido: (j['apellido'] ?? '') as String,
        fechaNacimiento: (j['fechaNacimiento'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        telefono: (j['telefono'] ?? '') as String,
        domicilio: (j['domicilio'] ?? '') as String,
        obraSocial: (j['obraSocial'] ?? '') as String,
        plan: (j['plan'] ?? '') as String,
        nroAfiliado: (j['nroAfiliado'] ?? '') as String,
        usuarioId: j['usuarioId'] as int?,
      );
}
