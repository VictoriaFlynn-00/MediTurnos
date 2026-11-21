import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const bgApp = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const successDark = Color(0xFF047857);
  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFEF2F2);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFEF3C7);
  static const warningText = Color(0xFF92400E);
  static const disabled = Color(0xFFCBD5E1);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary, primary: AppColors.primary),
    scaffoldBackgroundColor: AppColors.bgApp,
  );
  return base.copyWith(
    textTheme: GoogleFonts.soraTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.textMain, displayColor: AppColors.textMain),
  );
}
