import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand colours ─────────────────────────────────────────────────────────
  static const Color magenta   = Color(0xFFCC39A4); // primary accent
  static const Color cream     = Color(0xFFF5F0E8); // main background
  static const Color dark      = Color(0xFF1A1A1A); // app bar / bottom nav
  static const Color darkCard  = Color(0xFF2C2C2E); // dark surface
  static const Color redEnd    = Color(0xFFE53935); // End-session button

  // ── Speaker bubble colours (kept for logic that references them) ──────────
  static const Color user1Color = Color(0xFF6C63FF);
  static const Color user2Color = Color(0xFFCC39A4);

  // ── Status colours ────────────────────────────────────────────────────────
  static const Color listeningColor  = magenta;
  static const Color translatingColor = Color(0xFFFF9800);
  static const Color speakingColor   = Color(0xFF00BCD4);
  static const Color errorColor      = Color(0xFFE53935);

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: magenta,
          brightness: Brightness.light,
          surface: cream,
        ),
        scaffoldBackgroundColor: cream,
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          backgroundColor: dark,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
        ),
        cardTheme: const CardTheme(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: magenta,
            foregroundColor: Colors.white,
            minimumSize: const Size(160, 52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
      );

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static ThemeData get dark_ => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: magenta,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF111111),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: dark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      );
}
