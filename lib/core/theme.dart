import 'package:flutter/material.dart';

/// Tema global de la aplicación Py55.
class AppTheme {
  AppTheme._();

  // ── Colores primarios ──────────────────────────────────────────
  static const Color primaryColor = Color(0xFF1B5E20); // Verde oscuro
  static const Color secondaryColor = Color(0xFFFFC107); // Ámbar / amarillo

  // ── ThemeData ──────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.black,
      ),
    );
  }
}
