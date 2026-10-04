import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Greenhouse STEM: lá sâu + nước trong + nắng ấm
class HydroTheme {
  static const Color deep = Color(0xFF071A12);
  static const Color panel = Color(0xFF12281C);
  static const Color moss = Color(0xFF1B3D2A);
  static const Color leaf = Color(0xFF4ADE80);
  static const Color water = Color(0xFF2DD4BF);
  static const Color sun = Color(0xFFFBBF24);
  static const Color soft = Color(0xFFECFDF5);
  static const Color muted = Color(0xFF94B8A6);
  static const Color warn = Color(0xFFFB923C);

  static ThemeData dark() {
    final display = GoogleFonts.frauncesTextTheme();
    final body = GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deep,
      colorScheme: const ColorScheme.dark(
        primary: leaf,
        secondary: water,
        tertiary: sun,
        surface: panel,
        onPrimary: deep,
        onSecondary: deep,
        onSurface: soft,
        error: warn,
      ),
      textTheme: body.copyWith(
        displayLarge: display.displayLarge?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.6,
          height: 0.95,
        ),
        displayMedium: display.displayMedium?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 0.98,
        ),
        headlineMedium: display.headlineMedium?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: body.titleLarge?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        bodyLarge: body.bodyLarge?.copyWith(color: soft, height: 1.4),
        bodyMedium: body.bodyMedium?.copyWith(color: muted, height: 1.35),
        labelLarge: body.labelLarge?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
