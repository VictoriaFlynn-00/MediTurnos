import 'package:flutter_test/flutter_test.dart';
import 'package:mediturnos/core/fechas.dart';
import 'package:mediturnos/domain/entities/paciente.dart';
import 'package:mediturnos/domain/entities/turno.dart';

void main() {
  test('Paciente.partirNombre separa nombre y apellido', () {
    expect(Paciente.partirNombre('Camila Fernández'), ('Camila', 'Fernández'));
    expect(Paciente.partirNombre('María Laura Pérez'), ('María Laura', 'Pérez'));
    expect(Paciente.partirNombre('Cher'), ('Cher', ''));
  });

  test('Fechas formatea correctamente', () {
    expect(Fechas.iso(DateTime(2026, 10, 5)), '2026-10-05');
    expect(Fechas.deIsoAVista('2026-10-05'), '05/10/2026');
  });

  test('Turno: próximo solo si está activo/pendiente y es futuro', () {
    final futuro = DateTime.now().add(const Duration(days: 2));
    Turno t(EstadoTurno e, DateTime f) => Turno(
        id: '1', pacienteDni: '1', especialistaId: 1, especialistaNombre: 'X',
        especialidad: 'Y', fecha: DateTime(f.year, f.month, f.day), hora: '23:59', estado: e);
    expect(t(EstadoTurno.activo, futuro).esProximo, true);
    expect(t(EstadoTurno.pendienteSync, futuro).esProximo, true);
    expect(t(EstadoTurno.cancelado, futuro).esProximo, false);
    expect(t(EstadoTurno.activo, DateTime.now().subtract(const Duration(days: 2))).esProximo, false);
  });
}
