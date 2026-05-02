import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF6C63FF); // vibrant indigo-purple
  static const _accentColor = Color(0xFF00D4AA); // teal accent

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        cardTheme: const CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(200, 56),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        cardTheme: const CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(200, 56),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      );

  // Semantic colors used across the app
  static const Color listeningColor = Color(0xFF4CAF50);
  static const Color translatingColor = Color(0xFFFF9800);
  static const Color speakingColor = _accentColor;
  static const Color errorColor = Color(0xFFE53935);
  static const Color user1Color = Color(0xFF6C63FF);
  static const Color user2Color = Color(0xFF00D4AA);
}
