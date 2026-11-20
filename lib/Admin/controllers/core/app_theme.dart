import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.navy,
      primary: C.navy,
      secondary: C.yellow,
    ),
    fontFamily: 'Roboto',
    dividerColor: C.line,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: C.navy, width: 1.6),
      ),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.yellow,
        foregroundColor: C.navy,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.navy,
        side: const BorderSide(color: C.navy),
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(),
      backgroundColor: Colors.white,
    ),
  );
}
