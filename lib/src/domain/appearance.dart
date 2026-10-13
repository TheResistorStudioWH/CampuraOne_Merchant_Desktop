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
  });

  final MerchantThemePreset preset;
  final AppearanceBrightness brightness;

  AppearanceSettings copyWith({
    MerchantThemePreset? preset,
    AppearanceBrightness? brightness,
  }) {
    return AppearanceSettings(
      preset: preset ?? this.preset,
      brightness: brightness ?? this.brightness,
    );
  }

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    return AppearanceSettings(
      preset: MerchantThemePreset.fromName(json['themePreset'] as String?),
      brightness: AppearanceBrightness.fromName(json['brightness'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'themePreset': preset.name,
    'brightness': brightness.name,
  };

  @override
  bool operator ==(Object other) {
    return other is AppearanceSettings &&
        other.preset == preset &&
        other.brightness == brightness;
  }

  @override
  int get hashCode => Object.hash(preset, brightness);
}
