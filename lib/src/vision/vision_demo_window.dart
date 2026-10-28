import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'vision_demo_model.dart';

class VisionDemoApp extends StatelessWidget {
  const VisionDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFDB6B24);
    ThemeData theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    );

    return MaterialApp(
      title: '域校屿商家 · 视觉分析',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const VisionDemoWindow(),
    );
  }
}

class VisionDemoWindow extends StatefulWidget {
  const VisionDemoWindow({super.key});

  @override
  State<VisionDemoWindow> createState() => _VisionDemoWindowState();
}

class _VisionDemoWindowState extends State<VisionDemoWindow> {
  VisionDemoModel _model = const VisionDemoModel();
  DateTime? _lastAdjusted;

  Future<void> _editCount({required bool people}) async {
    final label = people ? '店内人数' : '线上单数';
    final initial = people ? _model.peopleInStore : _model.onlineOrders;
    final value = await _showNumberDialog(label, initial.toString());
    if (!mounted || value == null) return;
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    setState(() {
      _model = people
          ? _model.copyWith(peopleInStore: parsed)
          : _model.copyWith(onlineOrders: parsed);
      _lastAdjusted = DateTime.now();
    });
  }

  Future<void> _editMinutes() async {
    final value = await _showNumberDialog(
      '每单时间（分钟）',
      _model.minutesPerOrder.toString(),
      decimal: true,
    );
    if (!mounted || value == null) return;
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    setState(() {
      _model = _model.copyWith(minutesPerOrder: parsed);
      _lastAdjusted = DateTime.now();
    });
  }

  Future<String?> _showNumberDialog(
    String label,
    String initial, {
    bool decimal = false,
  }) async {
    final formKey = GlobalKey<FormState>();
    String? enteredValue;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void save() {
          if (formKey.currentState?.validate() == true) {
            formKey.currentState!.save();
            Navigator.of(dialogContext).pop(enteredValue?.trim());
          }
        }

        return AlertDialog(
          title: Text('手动调整$label'),
          content: SizedBox(
            width: 320,
            child: Form(
              key: formKey,
              child: TextFormField(
                key: const Key('vision-manual-input'),
                autofocus: true,
                initialValue: initial,
                keyboardType: TextInputType.numberWithOptions(decimal: decimal),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: label,
                  suffixText: decimal ? 'min' : peopleSuffix(label),
                  helperText: decimal ? '允许 0.1–60 分钟，最多两位小数' : '允许 0–999',
                ),
                validator: (raw) {
                  final value = raw?.trim() ?? '';
                  if (decimal) {
                    final parsed = double.tryParse(value);
                    if (parsed == null ||
                        !parsed.isFinite ||
                        parsed < 0.1 ||
                        parsed > 60 ||
                        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
                      return '请输入 0.1–60 的分钟数，最多两位小数';
                    }
                  } else {
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed < 0 || parsed > 999) {
                      return '请输入 0–999 的整数';
                    }
                  }
                  return null;
                },
                onSaved: (value) => enteredValue = value,
                onFieldSubmitted: (_) => save(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(onPressed: save, child: const Text('应用')),
          ],
        );
      },
    );
  }

  String peopleSuffix(String label) => label == '店内人数' ? '人' : '单';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('视觉分析'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() {
              _model = const VisionDemoModel();
              _lastAdjusted = null;
            }),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('重置数据'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = (constraints.maxWidth - 48).clamp(0.0, 1100.0);
          final columns = contentWidth >= 520 ? 3 : 1;
          final cardWidth = columns == 3
              ? (contentWidth - 24) / 3
              : contentWidth;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          '当前正在监控',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.science_outlined, size: 18),
                          label: const Text('摄像头画面待接入'),
                          backgroundColor: scheme.tertiaryContainer,
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '这里将显示本店授权摄像头的画面；当前数值可由商家手动调整。',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CameraPlaceholder(height: contentWidth >= 720 ? 280 : 220),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricCard(
                          width: cardWidth,
                          label: '店内人数',
                          value: '${_model.peopleInStore}',
                          unit: '人',
                          icon: Icons.groups_2_outlined,
                          onEdit: () => _editCount(people: true),
                        ),
                        _MetricCard(
                          width: cardWidth,
                          label: '线上单数',
                          value: '${_model.onlineOrders}',
                          unit: '单',
                          icon: Icons.receipt_long_outlined,
                          onEdit: () => _editCount(people: false),
                        ),
                        _MetricCard(
                          width: cardWidth,
                          label: '每单时间',
                          value: '${_model.minutesPerOrder}',
                          unit: 'min',
                          icon: Icons.timer_outlined,
                          onEdit: _editMinutes,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card.filled(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('预计等待', style: textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              '约 ${_model.roundedScenarioMinutes} 分钟',
                              key: const Key('vision-wait-estimate'),
                              style: textTheme.headlineMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '按 ${_model.onlineOrders} 笔线上待处理单、每单 ${_model.minutesPerOrder} 分钟、单工位且新增 1 单估算。'
                              '店内人数不计为订单；线下订单和在制状态尚未接入，结果仅基于当前输入。',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (_lastAdjusted != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '数据更新时间：${TimeOfDay.fromDateTime(_lastAdjusted!).format(context)}（手动）',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
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

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('vision-camera-placeholder'),
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 16,
            child: Chip(
              avatar: const Icon(Icons.videocam_off_outlined, size: 18),
              label: const Text('CAM 01 · 未接入'),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 48,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text('监控画面预留区', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '画面接入后将在此显示',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.onEdit,
  });

  final double width;
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = width < 220;
    final adjustButton = TextButton(
      key: Key('vision-edit-$label'),
      onPressed: onEdit,
      style: compact
          ? TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            )
          : null,
      child: const Text('手动调整'),
    );
    return SizedBox(
      width: width,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 5),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(unit),
                  ),
                  if (!compact) ...[const Spacer(), adjustButton],
                ],
              ),
              if (compact)
                Align(alignment: Alignment.centerRight, child: adjustButton),
            ],
          ),
        ),
      ),
    );
  }
}
