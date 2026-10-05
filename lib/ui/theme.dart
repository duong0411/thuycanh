import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Thủy canh STEM — lá sâu, nước trong, nắng ấm (không dùng purple / cream AI-default)
class HydroTheme {
  static const Color deep = Color(0xFF06140F);
  static const Color mist = Color(0xFF0B2218);
  static const Color panel = Color(0xFF132E22);
  static const Color panelSoft = Color(0xFF1A3A2B);
  static const Color leaf = Color(0xFF3DDC84);
  static const Color water = Color(0xFF2EC4B6);
  static const Color sun = Color(0xFFF2C14E);
  static const Color soft = Color(0xFFF0FDF6);
  static const Color muted = Color(0xFF8FB5A0);
  static const Color warn = Color(0xFFFF8A4C);
  static const Color line = Color(0x1AFFFFFF);

  static ThemeData dark() {
    final display = GoogleFonts.frauncesTextTheme();
    final body = GoogleFonts.dmSansTextTheme();

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
          letterSpacing: -1.8,
          height: 0.94,
        ),
        displayMedium: display.displayMedium?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.3,
          height: 0.96,
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
        bodyLarge: body.bodyLarge?.copyWith(color: soft, height: 1.45),
        bodyMedium: body.bodyMedium?.copyWith(color: muted, height: 1.4),
        labelLarge: body.labelLarge?.copyWith(
          color: soft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static BoxDecoration screenGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0E2A1C),
          deep,
          Color(0xFF04110C),
          Color(0xFF0A1C22),
        ],
        stops: [0.0, 0.38, 0.78, 1.0],
      ),
    );
  }
}
