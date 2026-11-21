class ReservaTemporal {
  const ReservaTemporal(this.token, this.venceEn);

  final String token;

  /// Puede faltar si se perdió la respuesta al intentar obtener la reserva.
  final DateTime? venceEn;

  bool get tentativa => venceEn == null;
}
