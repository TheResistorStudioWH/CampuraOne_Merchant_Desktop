import 'package:campura_one_merchant/src/domain/appearance.dart';
import 'package:campura_one_merchant/src/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('所有主题的核心文字和容器达到 WCAG AA 对比度', () {
    for (final preset in MerchantThemePreset.values) {
      for (final brightness in Brightness.values) {
        final scheme = buildMerchantTheme(brightness, preset).colorScheme;
        final pairs = <(Color, Color, String)>[
          (scheme.onSurface, scheme.surface, 'surface'),
          (scheme.onPrimary, scheme.primary, 'primary'),
          (scheme.onSecondary, scheme.secondary, 'secondary'),
          (scheme.onTertiary, scheme.tertiary, 'tertiary'),
          (
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
            'primaryContainer',
          ),
          (
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
            'secondaryContainer',
          ),
          (
            scheme.onTertiaryContainer,
            scheme.tertiaryContainer,
            'tertiaryContainer',
          ),
        ];

        for (final pair in pairs) {
          expect(
            _contrastRatio(pair.$1, pair.$2),
            greaterThanOrEqualTo(4.5),
            reason:
                '${preset.name} / ${brightness.name} / ${pair.$3} '
                '文字对比度不足',
          );
        }
      }
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
