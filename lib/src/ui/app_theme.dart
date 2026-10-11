import 'dart:io';

import 'package:flutter/material.dart';

const brandPurple = Color(0xFF863BFF);
const brandBlue = Color(0xFF47BFFF);

ThemeData buildMerchantTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: brandPurple,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(secondary: brandBlue);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: Platform.isWindows ? 'Segoe UI' : null,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF111116)
        : const Color(0xFFF7F7FA),
    canvasColor: dark ? const Color(0xFF18181F) : Colors.white,
    dividerColor: scheme.outlineVariant.withValues(alpha: 0.7),
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF202028) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF1B1B22) : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.75)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFFF1F0F5) : const Color(0xFF24212A),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(
        color: dark ? const Color(0xFF24212A) : Colors.white,
        fontSize: 12,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? const Color(0xFF17171D) : Colors.white,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      selectedLabelTextStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

IconData materialIconForCategory(String? sfSymbol) {
  return switch (sfSymbol) {
    'cup.and.saucer.fill' => Icons.coffee_rounded,
    'takeoutbag.and.cup.and.straw.fill' => Icons.local_drink_rounded,
    'fork.knife' => Icons.restaurant_rounded,
    'birthday.cake.fill' => Icons.cake_rounded,
    'carrot.fill' => Icons.eco_rounded,
    'book.closed.fill' => Icons.menu_book_rounded,
    'tshirt.fill' => Icons.checkroom_rounded,
    _ => Icons.category_rounded,
  };
}

Color materialColorForCategory(String? colorName, ColorScheme scheme) {
  return switch (colorName) {
    'brown' => const Color(0xFF8D5A3B),
    'orange' => const Color(0xFFF18F32),
    'red' => const Color(0xFFE05252),
    'pink' => const Color(0xFFE85D9E),
    'green' => const Color(0xFF4B9B65),
    'blue' => const Color(0xFF4387D8),
    'purple' => brandPurple,
    _ => scheme.primary,
  };
}
