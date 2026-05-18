// lib/utils/theme.dart
import 'package:flutter/material.dart';

const String kBaseUrl = 'http://localhost:8080'; // Altere para seu servidor

class AppTheme {
  // Paleta: fundo azul-chumbo escuro, accent violeta-índigo
  static const Color bgDark       = Color(0xFF0F1117);
  static const Color bgSidebar    = Color(0xFF090C12);
  static const Color bgCard       = Color(0xFF161B27);
  static const Color bgInput      = Color(0xFF1C2233);
  static const Color bgUserBubble = Color(0xFF1E2A45);
  static const Color bgBotBubble  = Colors.transparent;

  static const Color accent      = Color(0xFF6C63FF); // violeta/índigo
  static const Color accentDim   = Color(0xFF3D3875);
  static const Color accentGlow  = Color(0x336C63FF);

  static const Color textPrimary   = Color(0xFFE8EAF0);
  static const Color textSecondary = Color(0xFF7A8099);
  static const Color divider       = Color(0xFF1F2435);
  static const Color iconColor     = Color(0xFF5A6282);
  static const Color sourceChip    = Color(0xFF161B27);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: bgSidebar,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: textPrimary, fontSize: 15, height: 1.65),
          bodySmall:  TextStyle(color: textSecondary, fontSize: 12),
          titleMedium: TextStyle(
              color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: false,
          border: OutlineInputBorder(borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide.none),
          disabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
          hintStyle: TextStyle(color: textSecondary),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
          ),
        ),
        dividerColor: divider,
      );
}
