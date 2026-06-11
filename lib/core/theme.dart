import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography: "Built by money to show you money."
/// Playfair Display carries the wordmark and headings (old-money serif),
/// Inter handles body copy, JetBrains Mono handles numbers and tickers.
abstract final class KFonts {
  static TextStyle wordmark(Color color) => GoogleFonts.playfairDisplay(
        color: color,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );

  static TextStyle heading({Color? color, double size = 20}) =>
      GoogleFonts.playfairDisplay(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w500,
      );

  /// Monospace for prices, P&L, Greeks, tickers.
  static TextStyle data(
          {Color? color, double size = 13, FontWeight? weight}) =>
      GoogleFonts.jetBrainsMono(color: color, fontSize: size, fontWeight: weight);
}

TextTheme _textTheme(TextTheme base) =>
    GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.playfairDisplay(textStyle: base.displayLarge),
      displayMedium: GoogleFonts.playfairDisplay(textStyle: base.displayMedium),
      displaySmall: GoogleFonts.playfairDisplay(textStyle: base.displaySmall),
      headlineLarge: GoogleFonts.playfairDisplay(textStyle: base.headlineLarge),
      headlineMedium:
          GoogleFonts.playfairDisplay(textStyle: base.headlineMedium),
      headlineSmall: GoogleFonts.playfairDisplay(textStyle: base.headlineSmall),
      titleLarge: GoogleFonts.playfairDisplay(textStyle: base.titleLarge),
    );

/// Two-theme system:
/// - Auth shell (landing, invite, register, login): black + gold.
/// - Member app (behind login): cream + gold.
/// Shared semantic colors (P&L win/loss) are identical in both.
abstract final class KColors {
  // Shared
  static const accent = Color(0xFFC9A84C);
  static const positive = Color(0xFF27AE60);
  static const negative = Color(0xFFC0392B);
  static const neutral = Color(0xFF7F8C8D);
  static const pending = Color(0xFFD4A017);

  // Auth (black) theme
  static const authBgBase = Color(0xFF000000);
  static const authBgSurface = Color(0xFF0A0A0A);
  static const authBgElevated = Color(0xFF111111);
  static const authBorder = Color(0x14FFFFFF); // white @ 8%
  static const authTextPrimary = Color(0xFFF0F0F0);
  static const authTextSecondary = Color(0xFF808080);
  static const authAccentHover = Color(0xFFE0BE6A);

  // Member (cream) theme
  static const memberBgBase = Color(0xFFF7F3EA);
  static const memberBgSurface = Color(0xFFFFFDF8);
  static const memberBgElevated = Color(0xFFFFFFFF);
  static const memberBorder = Color(0x14000000); // black @ 8%
  static const memberTextPrimary = Color(0xFF1A1A1A);
  static const memberTextSecondary = Color(0xFF6B6558);
  static const memberAccentHover = Color(0xFFB5933D);
}

ThemeData buildAuthTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    textTheme: _textTheme(base.textTheme),
    scaffoldBackgroundColor: KColors.authBgBase,
    colorScheme: const ColorScheme.dark(
      primary: KColors.accent,
      surface: KColors.authBgSurface,
      onSurface: KColors.authTextPrimary,
    ),
    cardTheme: const CardThemeData(
      color: KColors.authBgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: KColors.authBorder),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: KColors.authBorder),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: KColors.accent),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
  );
}

ThemeData buildMemberTheme() {
  final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
  // Glossy member surface language: rounded corners everywhere below the
  // nav, soft shadows, gold hairlines. No sharp edges.
  return base.copyWith(
    textTheme: _textTheme(base.textTheme),
    scaffoldBackgroundColor: KColors.memberBgBase,
    colorScheme: const ColorScheme.light(
      primary: KColors.accent,
      surface: KColors.memberBgSurface,
      onSurface: KColors.memberTextPrimary,
    ),
    cardTheme: CardThemeData(
      color: KColors.memberBgSurface,
      elevation: 3,
      shadowColor: const Color(0x1F000000),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0x2EC9A84C)),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: KColors.memberBgElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: KColors.memberBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: KColors.memberBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: KColors.accent),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KColors.accent,
        foregroundColor: Colors.black,
        elevation: 2,
        shadowColor: const Color(0x66C9A84C),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KColors.memberTextPrimary,
        side: const BorderSide(color: KColors.accent, width: 0.8),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KColors.memberAccentHover,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}
