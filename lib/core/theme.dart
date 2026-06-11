import 'package:flutter/material.dart';

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
  return base.copyWith(
    scaffoldBackgroundColor: KColors.memberBgBase,
    colorScheme: const ColorScheme.light(
      primary: KColors.accent,
      surface: KColors.memberBgSurface,
      onSurface: KColors.memberTextPrimary,
    ),
    cardTheme: const CardThemeData(
      color: KColors.memberBgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: KColors.memberBorder),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: KColors.memberBorder),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: KColors.accent),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
  );
}
