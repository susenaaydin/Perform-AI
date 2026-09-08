import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF8B4D4D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFD48A8A);
  static const Color onPrimaryContainer = Color(0xFF592526);

  static const Color secondary = Color(0xFF735858);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFCD7D7);
  static const Color onSecondaryContainer = Color(0xFF785C5C);

  static const Color tertiary = Color(0xFF70585B);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFB3979A);
  static const Color onTertiaryContainer = Color(0xFF443032);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color background = Color(0xFFFFF8F7);
  static const Color onBackground = Color(0xFF251819);

  static const Color surface = Color(0xFFFFF8F7);
  static const Color onSurface = Color(0xFF251819);
  static const Color surfaceVariant = Color(0xFFF4DDDD);
  static const Color onSurfaceVariant = Color(0xFF524343);

  static const Color outline = Color(0xFF857372);
  static const Color outlineVariant = Color(0xFFD7C1C1);

  // Surface container roles from Material 3 (used in specs)
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFFF0F0);
  static const Color surfaceContainer = Color(0xFFFFE9E8);
  static const Color surfaceContainerHigh = Color(0xFFFAE3E2);
  static const Color surfaceContainerHighest = Color(0xFFF4DDDD);

  static const Color primaryFixed = Color(0xFFFFDAD9);
  static const Color primaryFixedDim = Color(0xFFFFB3B2);
  static const Color onPrimaryFixed = Color(0xFF380B0F);
  static const Color onPrimaryFixedVariant = Color(0xFF6F3637);

  static const Color secondaryFixed = Color(0xFFFFDADA);
  static const Color secondaryFixedDim = Color(0xFFE2BEBE);
  static const Color onSecondaryFixed = Color(0xFF2A1617);
  static const Color onSecondaryFixedVariant = Color(0xFF5A4041);

  static const Color tertiaryFixed = Color(0xFFFBDBDE);
  static const Color tertiaryFixedDim = Color(0xFFDEBFC2);
  static const Color onTertiaryFixed = Color(0xFF281719);
  static const Color onTertiaryFixedVariant = Color(0xFF574144);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      scaffoldBackgroundColor: AppColors.background,
      
      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x33D7C1C1), width: 1), // outline-variant/30
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x80D7C1C1), width: 1), // outline-variant/50
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x80D7C1C1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.secondary,
          letterSpacing: 0.02,
        ),
        prefixIconColor: AppColors.outlineVariant,
      ),

      // Buttons Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.02,
          ),
          elevation: 0,
        ),
      ),

      // Typography Configuration
      textTheme: TextTheme(
        // display (48px, bold, Manrope)
        displayLarge: GoogleFonts.manrope(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.96, // -0.02em
          height: 1.16, // 56px line-height
          color: AppColors.primary,
        ),
        // headline-lg (32px, semi-bold, Manrope)
        headlineLarge: GoogleFonts.manrope(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.32, // -0.01em
          height: 1.25, // 40px line-height
          color: AppColors.onSurface,
        ),
        // headline-md (24px, semi-bold, Manrope)
        headlineMedium: GoogleFonts.manrope(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.33, // 32px line-height
          color: AppColors.onSurface,
        ),
        // body-lg (18px, regular, Manrope)
        bodyLarge: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.55, // 28px line-height
          color: AppColors.onSurface,
        ),
        // body-md (16px, regular, Manrope)
        bodyMedium: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5, // 24px line-height
          color: AppColors.onSurface,
        ),
        // label-md (14px, semi-bold, Hanken Grotesk)
        labelLarge: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.28, // 0.02em
          height: 1.42, // 20px line-height
          color: AppColors.secondary,
        ),
        // label-sm (12px, medium, Hanken Grotesk)
        labelMedium: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6, // 0.05em
          height: 1.33, // 16px line-height
          color: AppColors.secondary,
        ),
      ),
    );
  }
}
