import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/appearance.dart';

class MerchantThemeDefinition {
  const MerchantThemeDefinition({
    required this.name,
    required this.description,
    required this.seed,
    required this.secondary,
    required this.tertiary,
  });

  final String name;
  final String description;
  final Color seed;
  final Color secondary;
  final Color tertiary;

  List<Color> get swatches => [seed, secondary, tertiary];
}

extension MerchantThemePresetVisuals on MerchantThemePreset {
  MerchantThemeDefinition get definition => switch (this) {
    MerchantThemePreset.signatureOrange => const MerchantThemeDefinition(
      name: '招牌暖橙',
      description: '热食、咖啡与校园零售都适合',
      seed: Color(0xFFE85D04),
      secondary: Color(0xFFF4B400),
      tertiary: Color(0xFF168B65),
    ),
    MerchantThemePreset.honeyGold => const MerchantThemeDefinition(
      name: '蜂蜜金黄',
      description: '明亮温暖，但保持文字清晰',
      seed: Color(0xFFD99000),
      secondary: Color(0xFFED6A24),
      tertiary: Color(0xFF008E83),
    ),
    MerchantThemePreset.sunset => const MerchantThemeDefinition(
      name: '日落橙黄',
      description: '更活跃的橙黄组合',
      seed: Color(0xFFF06A24),
      secondary: Color(0xFFF2C037),
      tertiary: Color(0xFF0097A7),
    ),
    MerchantThemePreset.lagoon => const MerchantThemeDefinition(
      name: '清爽湖青',
      description: '饮品、日用品与轻食更清爽',
      seed: Color(0xFF008C95),
      secondary: Color(0xFF68A83C),
      tertiary: Color(0xFFE87817),
    ),
    MerchantThemePreset.freshGreen => const MerchantThemeDefinition(
      name: '鲜蔬青绿',
      description: '自然、可靠，适合生鲜与便利店',
      seed: Color(0xFF318B45),
      secondary: Color(0xFFE2A400),
      tertiary: Color(0xFF009AA6),
    ),
  };
}

ThemeMode materialThemeMode(AppearanceBrightness brightness) {
  return switch (brightness) {
    AppearanceBrightness.system => ThemeMode.system,
    AppearanceBrightness.light => ThemeMode.light,
    AppearanceBrightness.dark => ThemeMode.dark,
  };
}

ThemeData buildMerchantTheme(
  Brightness brightness,
  MerchantThemePreset preset,
) {
  final dark = brightness == Brightness.dark;
  final definition = preset.definition;
  final primary = ColorScheme.fromSeed(
    seedColor: definition.seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  );
  final secondary = ColorScheme.fromSeed(
    seedColor: definition.secondary,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  );
  final tertiary = ColorScheme.fromSeed(
    seedColor: definition.tertiary,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  );
  final scheme = primary.copyWith(
    secondary: secondary.primary,
    onSecondary: secondary.onPrimary,
    secondaryContainer: secondary.primaryContainer,
    onSecondaryContainer: secondary.onPrimaryContainer,
    tertiary: tertiary.primary,
    onTertiary: tertiary.onPrimary,
    tertiaryContainer: tertiary.primaryContainer,
    onTertiaryContainer: tertiary.onPrimaryContainer,
  );
  final background = Color.alphaBlend(
    scheme.primary.withValues(alpha: dark ? 0.035 : 0.025),
    dark ? const Color(0xFF111310) : const Color(0xFFFAF9F5),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: Platform.isWindows ? 'Segoe UI' : null,
    scaffoldBackgroundColor: background,
    canvasColor: scheme.surface,
    dividerColor: scheme.outlineVariant.withValues(alpha: 0.72),
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(
        alpha: dark ? 0.58 : 0.5,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(40, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(40, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: BorderSide(color: scheme.outline),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const StadiumBorder(),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(42),
        shape: const CircleBorder(),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      useIndicator: true,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.secondaryContainer,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        surfaceTintColor: WidgetStatePropertyAll(scheme.surfaceTint),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
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
    'orange' => const Color(0xFFE87817),
    'red' => const Color(0xFFD84D4D),
    'pink' => const Color(0xFFD6538C),
    'green' => const Color(0xFF3F8F58),
    'blue' => const Color(0xFF357DBF),
    'purple' => const Color(0xFF7B61A8),
    _ => scheme.primary,
  };
}
