import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Système de design officiel ShieldNet : Identité Télécom & Cybersécurité (Standard Pro / WireGuard & Signal)
class AppTheme {
  // Brand Identity : Bleu Télécom Cobalt & Ardoise Institutionnelle
  static const Color primaryColor = Color(0xFF1D4ED8); // Bleu Cobalt Sécurité
  static const Color primaryDarkColor = Color(0xFF1E3A8A); // Bleu Marine Profond
  static const Color primaryLightColor = Color(0xFF3B82F6); // Bleu Ciel Professionnel

  // Sécurité & Protection Active (Émeraude Posée & Bleu Ardoise)
  static const Color accentGreen = Color(0xFF059669); // Vert de Confiance (WCAG AAA)
  static const Color accentCyan = Color(0xFF0284C7); // Bleu Acier Télécom

  // Alertes & Menaces (Rouge Alerte & Ambre Sobre)
  static const Color accentRed = Color(0xFFDC2626); // Rouge Sécurité Réglementaire
  static const Color accentOrange = Color(0xFFD97706); // Ambre Avertissement

  // Mode Sombre : Ardoise Neutre & Mat (Style Bitwarden / Proton)
  static const Color backgroundDark = Color(0xFF0F172A); // Ardoise 900 Neutre
  static const Color surfaceDark = Color(0xFF1E293B); // Ardoise 800 Structurée
  static const Color borderDark = Color(0xFF334155); // Bordure Subtile Ardoise 700
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Mode Clair : Fond Neutre & Surfaces Blanc Pur
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A); // Bleu Nuit Encre Profond
  static const Color textSecondaryLight = Color(0xFF475569);

  // Dégradés Professionnels Sobres (Ton sur Ton)
  static const LinearGradient shieldActiveGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shieldInactiveGradient = LinearGradient(
    colors: [Color(0xFFB91C1C), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Aides Sémantiques
  static Color cardBg(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color borderColor(bool isDark) => isDark ? borderDark : borderLight;

  // Accessibilité & Mode Interface Simplifiée (Seniors / Aînés)
  static const double seniorFontMultiplier = 1.25;
  static const double seniorMinButtonHeight = 58.0;
  static const Color seniorHighContrastBorder = Color(0xFF000000);
  static const Color seniorHighContrastBorderDark = Color(0xFFE2E8F0);

  static final ThemeData lightTheme = _buildLightTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildLightTheme() {
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

  static ThemeData _buildDarkTheme() {
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
