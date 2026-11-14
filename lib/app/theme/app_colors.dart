import 'package:flutter/material.dart';

import '../../core/constants/category_palette.dart';

class AppColors {
  const AppColors._();

  static const Color background = Color(0xFFF5F8FF);
  static const Color backgroundSoft = Color(0xFFEDF3FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFEFF4FC);
  static const Color surfaceBlue = Color(0xFFE8F1FF);
  static const Color borderSubtle = Color(0xFFDCE6F5);
  static const Color frameBorder = Color(0xFFCDDCF2);

  static const Color textPrimary = Color(0xFF10213D);
  static const Color textSecondary = Color(0xFF50617C);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color onDark = Color(0xFFFFFFFF);
  static const Color onDarkMuted = Color(0xE6FFFFFF);
  static const Color onDarkFaint = Color(0xD9FFFFFF);
  static const Color onDarkSubtle = Color(0x1FFFFFFF);
  static const Color onDarkBorder = Color(0x24FFFFFF);
  static const Color scrim = Color(0x61000000);

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color deepNavy = Color(0xFF102A56);
  static const Color brightBlue = Color(0xFF38BDF8);
  static const Color softBlue = Color(0xFFBFDBFE);

  static const Color infoBlue = Color(0xFF2563EB);
  static const Color incomeBlue = Color(0xFF0369A1);
  static const Color expenseBlue = Color(0xFF1D4ED8);
  static const Color warningOrange = Color(0xFFC2410C);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color cashflowIncome = Color(0xFF15803D);
  static const Color cashflowExpense = dangerRed;

  static const expenseChartPalette = [
    Color(0xFF16A34A),
    Color(0xFF84CC16),
    Color(0xFFEAB308),
    Color(0xFFF97316),
    dangerRed,
  ];

  static const Color darkBackground = Color(0xFF081222);
  static const Color darkBackgroundSoft = Color(0xFF0C182B);
  static const Color darkSurface = Color(0xFF101E34);
  static const Color darkSurfaceElevated = Color(0xFF162842);
  static const Color darkSurfaceSoft = Color(0xFF1C3250);
  static const Color darkBorderSubtle = Color(0xFF2B4263);
  static const Color darkFrameBorder = Color(0xFF284061);
  static const Color darkTextPrimary = Color(0xFFF3F7FF);
  static const Color darkTextSecondary = Color(0xFFC3D3EB);
  static const Color darkTextTertiary = Color(0xFF9EB5D4);

  static const categoryPalette = [
    Color(CategoryPalette.royal),
    Color(CategoryPalette.ocean),
    Color(CategoryPalette.blue),
    Color(CategoryPalette.navy),
    Color(CategoryPalette.sky),
    Color(CategoryPalette.slate),
  ];

  static Color categoryColor(int value, Brightness brightness) =>
      readableAccent(Color(CategoryPalette.resolve(value)), brightness);

  static Color readableAccent(Color color, Brightness brightness) {
    if (brightness == Brightness.light) return color;
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(hsl.lightness.clamp(0.74, 1.0)).toColor();
  }
}
