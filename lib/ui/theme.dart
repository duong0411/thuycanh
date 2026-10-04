import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// STEM greenhouse: deep foliage + leaf + sunlight (không purple / cream mặc định)
class HydroTheme {
  static const Color deep = Color(0xFF0B1F14);
  static const Color panel = Color(0xFF143023);
  static const Color moss = Color(0xFF1F4A34);
  static const Color leaf = Color(0xFF3DDC97);
  static const Color water = Color(0xFF4ECDC4);
  static const Color sun = Color(0xFFF2C14E);
  static const Color soft = Color(0xFFE6F5EC);

  static ThemeData dark() {
    final display = GoogleFonts.frauncesTextTheme();
    final body = GoogleFonts.sourceSans3TextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deep,
      colorScheme: const ColorScheme.dark(
        primary: leaf,
        secondary: sun,
        surface: panel,
        onPrimary: deep,
        onSecondary: deep,
        onSurface: soft,
      ),
      textTheme: body.copyWith(
        displayLarge: display.displayLarge?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        displayMedium: display.displayMedium?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: display.headlineMedium?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: display.titleLarge?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: body.bodyLarge?.copyWith(color: soft),
        bodyMedium: body.bodyMedium?.copyWith(color: soft.withValues(alpha: 0.88)),
        labelLarge: body.labelLarge?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
