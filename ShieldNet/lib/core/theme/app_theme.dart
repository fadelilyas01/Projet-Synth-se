import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Système de design officiel ShieldNet : Identité Cyber Indigo & Émeraude (Style Linear / Proton)
class AppTheme {
  // Brand Identity : Indigo Électrique & Cyber Indigo
  static const Color primaryColor = Color(0xFF6366F1); // Indigo Électrique
  static const Color primaryDarkColor = Color(0xFF4F46E5); // Indigo Profond
  static const Color primaryLightColor = Color(0xFF818CF8); // Indigo Lumineux

  // Sécurité & Protection Active (Émeraude & Mint Néon)
  static const Color accentGreen = Color(0xFF10B981); // Émeraude Cyber
  static const Color accentCyan = Color(0xFF00F5D4); // Cyan / Néon Mint

  // Alertes & Menaces (Crimson & Sunset Coral)
  static const Color accentRed = Color(0xFFF43F5E); // Rose-Crimson Moderne
  static const Color accentOrange = Color(0xFFFB923C); // Ambre / Coral Vif

  // Mode Sombre : Obsidienne OLED Profonde (Non gris terne)
  static const Color backgroundDark = Color(0xFF0A0E1A); // Noir Obsidienne Espace Profond
  static const Color surfaceDark = Color(0xFF141B2D); // Surface Bleu-Nuit Saphir
  static const Color borderDark = Color(0xFF222F4C); // Bordure Subtile Électrique
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Mode Clair : Perle & Snow Moderne
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0B132B); // Bleu Nuit Encre Profond
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Dégradés Cyber Signature
  static const LinearGradient shieldActiveGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF10B981), Color(0xFF00F5D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shieldInactiveGradient = LinearGradient(
    colors: [Color(0xFF9F1239), Color(0xFFE11D48), Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Aides Sémantiques
  static Color cardBg(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color borderColor(bool isDark) => isDark ? borderDark : borderLight;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: textPrimaryLight,
      displayColor: textPrimaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundLight,
      textTheme: baseTextTheme,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentGreen,
        surface: surfaceLight,
        error: accentRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundLight,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimaryLight),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondaryLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceLight,
        indicatorColor: primaryColor.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return GoogleFonts.plusJakartaSans(color: textSecondaryLight, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor);
          }
          return const IconThemeData(color: textSecondaryLight);
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseDarkTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: textPrimaryDark,
      displayColor: textPrimaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundDark,
      textTheme: baseDarkTextTheme,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentGreen,
        surface: surfaceDark,
        error: accentRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimaryDark),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryLightColor, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondaryDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(color: primaryLightColor, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return GoogleFonts.plusJakartaSans(color: textSecondaryDark, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryLightColor);
          }
          return const IconThemeData(color: textSecondaryDark);
        }),
      ),
    );
  }
}
