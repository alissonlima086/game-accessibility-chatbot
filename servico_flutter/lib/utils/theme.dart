// lib/utils/theme.dart
import 'package:flutter/material.dart';

const String kBaseUrl = 'http://localhost:8080';

class AppTheme {
  // Paleta: verde-esmeralda escuro — distinta, técnica, sem ChatGPT
  static const Color bgDark       = Color(0xFF0D1117); // GitHub dark
  static const Color bgSidebar    = Color(0xFF080D13);
  static const Color bgCard       = Color(0xFF13181F);
  static const Color bgInput      = Color(0xFF161C25);
  static const Color bgUserBubble = Color(0xFF0F2620); // verde escuro

  static const Color accent      = Color(0xFF2DD4BF); // teal/esmeralda
  static const Color accentDim   = Color(0xFF1A6B62);
  static const Color accentGlow  = Color(0x222DD4BF);
  static const Color accentMid   = Color(0xFF14B8A5);

  static const Color textPrimary   = Color(0xFFCDD5E0);
  static const Color textSecondary = Color(0xFF566475);
  static const Color divider       = Color(0xFF1A2130);
  static const Color iconColor     = Color(0xFF3D5066);
  static const Color sourceChip    = Color(0xFF13181F);

  // Syntax highlight colors
  static const Color codeText      = Color(0xFF7EE8A2); // verde claro
  static const Color codeBg        = Color(0xFF0A0F15);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        fontFamily: 'Inter',
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
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
          ),
        ),
        dividerColor: divider,
      );
}
