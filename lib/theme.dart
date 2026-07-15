import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Charte SNIE — émeraude profond / lime / or (identique à la plateforme web).
class SnieColors {
  static const bg = Color(0xFF0A1F17);
  static const panel = Color(0xFF0F2A1F);
  static const panel2 = Color(0xFF123626);
  static const edge = Color(0xFF1D4A35);
  static const ink = Color(0xFFE8F2EC);
  static const dim = Color(0xFF8FB3A2);
  static const faint = Color(0xFF5D8272);
  static const jade = Color(0xFF2E8B6A);
  static const lime = Color(0xFFA6C93B);
  static const gold = Color(0xFFC9A227);
  static const red = Color(0xFFE05D5D);
  static const amber = Color(0xFFE0A94F);
  static const ok = Color(0xFF4FC98A);
}

ThemeData snieTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: SnieColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: SnieColors.lime,
      secondary: SnieColors.gold,
      surface: SnieColors.panel,
      error: SnieColors.red,
    ),
    textTheme: GoogleFonts.archivoTextTheme(base.textTheme)
        .apply(bodyColor: SnieColors.ink, displayColor: SnieColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: SnieColors.panel,
      foregroundColor: SnieColors.ink,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SnieColors.panel2,
      labelStyle: const TextStyle(color: SnieColors.dim, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SnieColors.edge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SnieColors.edge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SnieColors.jade, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SnieColors.gold,
        foregroundColor: const Color(0xFF082C21),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: SnieColors.panel2,
      contentTextStyle: TextStyle(color: SnieColors.ink),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
