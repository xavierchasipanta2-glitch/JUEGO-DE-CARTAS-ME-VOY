import 'package:flutter/material.dart';

/// Tema visual de «Me Voy» diseñado para alta legibilidad durante partidas de Rummy.
class MeVoyTheme {
  const MeVoyTheme._();

  static const Color feltDarkGreen = Color(0xFF0A2E23);
  static const Color feltEmerald = Color(0xFF114B3A);
  static const Color cardSurface = Color(0xFF163D31);
  static const Color goldAccent = Color(0xFFF4C430);
  static const Color goldSoft = Color(0xFFFFE58F);
  static const Color creditPositive = Color(0xFF34D399);
  static const Color debtNegative = Color(0xFFF87171);
  static const Color warningAmber = Color(0xFFFBBF24);

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: feltEmerald,
      brightness: Brightness.dark,
      primary: goldAccent,
      onPrimary: const Color(0xFF1A1600),
      secondary: creditPositive,
      surface: feltDarkGreen,
      error: debtNegative,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: feltDarkGreen,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF072119),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.09),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0D2920),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: goldAccent, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldAccent,
          foregroundColor: const Color(0xFF1A1600),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldSoft,
          side: const BorderSide(color: goldAccent),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
