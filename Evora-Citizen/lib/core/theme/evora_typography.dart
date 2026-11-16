import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'evora_colors.dart';

/// EVORA Bilingual Typography System
/// Powered by Plus Jakarta Sans with special +2px line-height balance
/// to prevent clipping of upper Hindi Devanagari vowel matras.
class EvoraTypography {
  static TextTheme createTextTheme({bool isHindi = false}) {
    // Add +2px line-height when rendering Hindi text to prevent matra clipping
    final double extraHeight = isHindi ? 2.0 : 0.0;

    TextStyle baseStyle({
      required double fontSize,
      required FontWeight fontWeight,
      required double lineHeight,
      double letterSpacing = 0.0,
      bool tabular = false,
    }) {
      return GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: (lineHeight + extraHeight) / fontSize,
        letterSpacing: letterSpacing,
        color: EvoraColors.onSurface,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );
    }

    return TextTheme(
      displayLarge: baseStyle(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        lineHeight: 56,
        letterSpacing: -1.44,
      ),
      headlineLarge: baseStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        lineHeight: 40,
        letterSpacing: -0.64,
      ),
      headlineMedium: baseStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        lineHeight: 30,
        letterSpacing: -0.33,
      ),
      headlineSmall: baseStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        lineHeight: 26,
        letterSpacing: -0.18,
      ),
      bodyLarge: baseStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        lineHeight: 24,
        letterSpacing: -0.08,
      ),
      bodyMedium: baseStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        lineHeight: 22,
      ),
      bodySmall: baseStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        lineHeight: 18,
        letterSpacing: 0.12,
      ),
      labelLarge: baseStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        lineHeight: 20,
        letterSpacing: 0.14,
      ),
      labelMedium: baseStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        lineHeight: 16,
        letterSpacing: 0.24,
      ),
      labelSmall: baseStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        lineHeight: 14,
        letterSpacing: 0.5,
      ),
    );
  }

  /// High-emphasis tabular numbers for live counters, CO2e savings, streaks
  static TextStyle metricStyle({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w800,
    Color color = EvoraColors.onSurface,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
