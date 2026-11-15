import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_edition.dart';

class AppTheme {
  // ألوان نسخة التقنية الأصلية
  static const Color techPrimary = Color(0xFF38BDF8);
  static const Color techScaffold = Color(0xFF0F172A);
  static const Color techSurface = Color(0xFF1E293B);

  // ألوان نسخة الأمن السيبراني
  static const Color cyberPrimary = Color(0xFF10B981);
  static const Color cyberScaffold = Color(0xFF090D16);
  static const Color cyberSurface = Color(0xFF111827);

  // الألوان العامة
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  // ثوابت نقية زمن الترجمة (Compile-time constants)
  static const Color primaryBlue = AppEdition.isCyber ? cyberPrimary : techPrimary;
  static const Color scaffoldDark = AppEdition.isCyber ? cyberScaffold : techScaffold;
  static const Color surfaceDark = AppEdition.isCyber ? cyberSurface : techSurface;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldDark,
      primaryColor: primaryBlue,
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        surface: surfaceDark,
      ),
      useMaterial3: true,
    );
  }
}