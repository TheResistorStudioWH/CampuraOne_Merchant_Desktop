enum MerchantThemePreset {
  signatureOrange,
  honeyGold,
  sunset,
  lagoon,
  freshGreen;

  static MerchantThemePreset fromName(String? name) {
    return MerchantThemePreset.values.firstWhere(
      (value) => value.name == name,
      orElse: () => MerchantThemePreset.signatureOrange,
    );
  }
}

enum AppearanceBrightness {
  system,
  light,
  dark;

  static AppearanceBrightness fromName(String? name) {
    return AppearanceBrightness.values.firstWhere(
      (value) => value.name == name,
      orElse: () => AppearanceBrightness.system,
    );
  }
}

class AppearanceSettings {
  const AppearanceSettings({
    this.preset = MerchantThemePreset.signatureOrange,
    this.brightness = AppearanceBrightness.system,
    this.sidebarWidth,
    this.productListWidth,
    this.promotionListWidth,
  });

  final MerchantThemePreset preset;
  final AppearanceBrightness brightness;

  /// Null keeps the sidebar responsive to the window width.
  final double? sidebarWidth;
  final double? productListWidth;
  final double? promotionListWidth;

  static const _keepSidebarWidth = Object();
  static const _keepProductListWidth = Object();
  static const _keepPromotionListWidth = Object();

  AppearanceSettings copyWith({
    MerchantThemePreset? preset,
    AppearanceBrightness? brightness,
    Object? sidebarWidth = _keepSidebarWidth,
    Object? productListWidth = _keepProductListWidth,
    Object? promotionListWidth = _keepPromotionListWidth,
  }) {
    return AppearanceSettings(
      preset: preset ?? this.preset,
      brightness: brightness ?? this.brightness,
      sidebarWidth: identical(sidebarWidth, _keepSidebarWidth)
          ? this.sidebarWidth
          : sidebarWidth as double?,
      productListWidth: identical(productListWidth, _keepProductListWidth)
          ? this.productListWidth
          : productListWidth as double?,
      promotionListWidth: identical(promotionListWidth, _keepPromotionListWidth)
          ? this.promotionListWidth
          : promotionListWidth as double?,
    );
  }

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    final storedWidth = json['sidebarWidth'];
    final storedProductWidth = json['productListWidth'];
    final storedPromotionWidth = json['promotionListWidth'];
    return AppearanceSettings(
      preset: MerchantThemePreset.fromName(json['themePreset'] as String?),
      brightness: AppearanceBrightness.fromName(json['brightness'] as String?),
      sidebarWidth: storedWidth is num && storedWidth.isFinite
          ? storedWidth.toDouble().clamp(76.0, 360.0)
          : null,
      productListWidth: storedProductWidth is num && storedProductWidth.isFinite
          ? storedProductWidth.toDouble().clamp(300.0, 700.0)
          : null,
      promotionListWidth:
          storedPromotionWidth is num && storedPromotionWidth.isFinite
          ? storedPromotionWidth.toDouble().clamp(260.0, 600.0)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'themePreset': preset.name,
    'brightness': brightness.name,
    if (sidebarWidth != null) 'sidebarWidth': sidebarWidth,
    if (productListWidth != null) 'productListWidth': productListWidth,
    if (promotionListWidth != null) 'promotionListWidth': promotionListWidth,
  };

  @override
  bool operator ==(Object other) {
    return other is AppearanceSettings &&
        other.preset == preset &&
        other.brightness == brightness &&
        other.sidebarWidth == sidebarWidth &&
        other.productListWidth == productListWidth &&
        other.promotionListWidth == promotionListWidth;
  }

  @override
  int get hashCode => Object.hash(
    preset,
    brightness,
    sidebarWidth,
    productListWidth,
    promotionListWidth,
  );
}
