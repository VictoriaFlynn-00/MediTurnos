import 'paciente.dart';

enum Rol {
  paciente,
  especialista,
  secretario,
  admin;

  static Rol desde(String s) =>
      Rol.values.firstWhere((r) => r.name == s, orElse: () => Rol.paciente);
}

class Usuario {
  final int id;
  final String usuario;
  final Rol rol;
  const Usuario({required this.id, required this.usuario, required this.rol});

  Map<String, dynamic> toJson() =>
      {'id': id, 'usuario': usuario, 'rol': rol.name};
  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
      id: j['id'] as int,
      usuario: j['usuario'] as String,
      rol: Rol.desde(j['rol'] as String));
}

class Session {
  final String token; // JWT emitido por la API
  final Usuario usuario;
  final Paciente? paciente;
  const Session({required this.token, required this.usuario, this.paciente});
}
