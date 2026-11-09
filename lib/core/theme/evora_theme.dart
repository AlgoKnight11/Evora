import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'evora_colors.dart';
import 'evora_typography.dart';

/// Complete ThemeData for EVORA — Himalayan Modernism
class EvoraTheme {
  static ThemeData lightTheme({bool isHindi = false}) {
    final textTheme = EvoraTypography.createTextTheme(isHindi: isHindi);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: EvoraColors.primary,
      scaffoldBackgroundColor: EvoraColors.background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: EvoraColors.primary,
        onPrimary: EvoraColors.onPrimary,
        primaryContainer: EvoraColors.primaryContainer,
        onPrimaryContainer: EvoraColors.onPrimaryContainer,
        secondary: EvoraColors.secondary,
        onSecondary: EvoraColors.onSecondary,
        secondaryContainer: EvoraColors.secondaryContainer,
        onSecondaryContainer: EvoraColors.onSecondaryContainer,
        tertiary: EvoraColors.tertiary,
        onTertiary: EvoraColors.onTertiary,
        tertiaryContainer: EvoraColors.tertiaryContainer,
        onTertiaryContainer: EvoraColors.onTertiaryContainer,
        error: EvoraColors.error,
        onError: EvoraColors.onError,
        errorContainer: EvoraColors.errorContainer,
        onErrorContainer: EvoraColors.onErrorContainer,
        surface: EvoraColors.surface,
        onSurface: EvoraColors.onSurface,
        onSurfaceVariant: EvoraColors.onSurfaceVariant,
        outline: EvoraColors.outline,
        outlineVariant: EvoraColors.outlineVariant,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: EvoraColors.onSurface),
        titleTextStyle: TextStyle(
          color: EvoraColors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EvoraColors.primary,
          foregroundColor: EvoraColors.onPrimary,
          elevation: 0,
          shape: const StadiumBorder(), // Pill button
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EvoraColors.onSurface,
          side: const BorderSide(color: EvoraColors.outlineVariant, width: 1.5),
          shape: const StadiumBorder(), // Pill button
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EvoraColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EvoraColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100), // Pill contour for single line
          borderSide: const BorderSide(color: EvoraColors.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: EvoraColors.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: EvoraColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: const BorderSide(color: EvoraColors.error, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: EvoraColors.outline,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: EvoraColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // rounded-xl
          side: const BorderSide(color: Color(0x0F0F172A), width: 1),
        ),
      ),
    );
  }
}
