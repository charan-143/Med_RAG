import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Manrope via google_fonts
TextStyle _manrope(double size, FontWeight weight, [Color? color]) =>
    GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.5);

// ─── Colour Tokens ─────────────────────────────────────────────────────────────
class AppColors {
  // Primaries
  static const primary            = Color(0xFF005DAC);
  static const primaryContainer   = Color(0xFF1976D2);
  static const onPrimary          = Color(0xFFFFFFFF);
  static const primaryFixed       = Color(0xFFD4E3FF);
  static const primaryFixedDim    = Color(0xFFA5C8FF);
  static const onPrimaryFixed     = Color(0xFF001C3A);
  static const onPrimaryFixedVar  = Color(0xFF004786);

  // Tertiary (amber / human-moments)
  static const tertiary           = Color(0xFF944700);
  static const tertiaryFixed      = Color(0xFFFFDBC7);
  static const tertiaryFixedDim   = Color(0xFFFFB688);
  static const onTertiaryFixedVar = Color(0xFF733600);

  // Surfaces
  static const surface            = Color(0xFFF9F9F9);
  static const surfaceContainer   = Color(0xFFEEEEEE);
  static const surfaceContainerLow     = Color(0xFFF3F3F3);
  static const surfaceContainerHigh    = Color(0xFFE8E8E8);
  static const surfaceContainerHighest = Color(0xFFE2E2E2);
  static const surfaceContainerLowest  = Color(0xFFFFFFFF);

  // On-Surface
  static const onSurface          = Color(0xFF1A1C1C);
  static const onSurfaceVariant   = Color(0xFF414752);
  static const outline            = Color(0xFF717783);
  static const outlineVariant     = Color(0xFFC1C6D4);

  // Secondary
  static const secondary          = Color(0xFF5E5E5E);
  static const secondaryFixed     = Color(0xFFE3E2E2);

  // Error
  static const error              = Color(0xFFBA1A1A);
  static const errorContainer     = Color(0xFFFFDAD6);
}

// ─── Text Styles ───────────────────────────────────────────────────────────────
class AppTextStyles {
  static TextStyle headline(double size, FontWeight weight, [Color? color]) =>
      _manrope(size, weight, color ?? AppColors.onSurface);

  static TextStyle body(double size, [FontWeight weight = FontWeight.w400, Color? color]) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.onSurface,
      );

  static TextStyle label(double size, [Color? color]) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.onSurfaceVariant,
        letterSpacing: 0.1,
      );
}

// ─── Radius Tokens ─────────────────────────────────────────────────────────────
class AppRadius {
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 24.0;
  static const double full = 9999.0;

  /// Asymmetric "Clinical Atelier" card shape: TL+BR=xl, TR+BL=md
  static const asymmetric = RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft:     Radius.circular(xl),
      bottomRight: Radius.circular(xl),
      topRight:    Radius.circular(md),
      bottomLeft:  Radius.circular(md),
    ),
  );

  static BorderRadius get asymmetricBR => const BorderRadius.only(
    topLeft:     Radius.circular(xl),
    bottomRight: Radius.circular(xl),
    topRight:    Radius.circular(md),
    bottomLeft:  Radius.circular(md),
  );
}

// ─── Theme ─────────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.tertiary,
      onSecondary: AppColors.onPrimary,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    cardTheme: CardThemeData(
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerColor: Colors.transparent,
    dividerTheme: const DividerThemeData(color: Colors.transparent, space: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: AppTextStyles.body(14, FontWeight.w600),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
