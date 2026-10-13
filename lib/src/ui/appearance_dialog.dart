import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/appearance.dart';
import '../state/app_state.dart';
import 'app_theme.dart';

Future<void> showAppearanceDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const AppearanceDialog(),
  );
}

class AppearanceButton extends ConsumerWidget {
  const AppearanceButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(
      appControllerProvider.select((state) => state.appearance.preset),
    );
    return IconButton.filledTonal(
      key: const Key('appearance-open'),
      tooltip: '外观与主题',
      onPressed: () => showAppearanceDialog(context),
      icon: ThemePaletteIcon(preset: preset, compact: compact),
    );
  }
}

class ThemePaletteIcon extends StatelessWidget {
  const ThemePaletteIcon({
    required this.preset,
    super.key,
    this.compact = false,
  });

  final MerchantThemePreset preset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = preset.definition.swatches;
    final size = compact ? 7.0 : 8.0;
    return Semantics(
      label: preset.definition.name,
      child: SizedBox(
        width: compact ? 20 : 23,
        height: compact ? 18 : 20,
        child: Stack(
          children: [
            for (var index = 0; index < colors.length; index++)
              Positioned(
                left: index * (size - 1.5),
                top: index.isOdd ? 1 : 7,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppearanceDialog extends ConsumerWidget {
  const AppearanceDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      appControllerProvider.select((state) => state.appearance),
    );
    final effectiveBrightness = switch (settings.brightness) {
      AppearanceBrightness.system => MediaQuery.platformBrightnessOf(context),
      AppearanceBrightness.light => Brightness.light,
      AppearanceBrightness.dark => Brightness.dark,
    };

    return Theme(
      data: buildMerchantTheme(effectiveBrightness, settings.preset),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.palette_outlined,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '外观与主题',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '为不同类型的校园门店选择一套 Material 3 配色。',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      '显示模式',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<AppearanceBrightness>(
                      key: const Key('appearance-brightness'),
                      segments: const [
                        ButtonSegment(
                          value: AppearanceBrightness.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('跟随系统'),
                        ),
                        ButtonSegment(
                          value: AppearanceBrightness.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('浅色'),
                        ),
                        ButtonSegment(
                          value: AppearanceBrightness.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('深色'),
                        ),
                      ],
                      selected: {settings.brightness},
                      onSelectionChanged: (selection) {
                        ref
                            .read(appControllerProvider.notifier)
                            .setAppearance(
                              settings.copyWith(brightness: selection.single),
                            );
                      },
                    ),
                    const SizedBox(height: 26),
                    Text(
                      '主题颜色',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '暖色更有食欲，青绿更清爽；所有文字均使用自动对比色。',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: SingleChildScrollView(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final twoColumns = constraints.maxWidth >= 560;
                            final width = twoColumns
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final preset in MerchantThemePreset.values)
                                  SizedBox(
                                    width: width,
                                    child: _ThemeOption(
                                      preset: preset,
                                      selected: settings.preset == preset,
                                      onSelected: () => ref
                                          .read(appControllerProvider.notifier)
                                          .setAppearance(
                                            settings.copyWith(preset: preset),
                                          ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.preset,
    required this.selected,
    required this.onSelected,
  });

  final MerchantThemePreset preset;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final definition = preset.definition;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? scheme.secondary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('appearance-preset-${preset.name}'),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _ColorSwatches(colors: definition.swatches),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      definition.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? scheme.secondary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final color in colors)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
