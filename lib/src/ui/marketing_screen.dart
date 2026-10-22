import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/marketing_models.dart';
import '../domain/models.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'workspace_resize_handle.dart';

final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

DateTime? _parseDate(String text) {
  final value = text.trim();
  if (value.isEmpty) return null;
  try {
    return _dateFormat.parseStrict(value);
  } on FormatException {
    return null;
  }
}

const _smallImages = [
  'assets/demo/images/01-americano-S.png',
  'assets/demo/images/04-sausage-S.png',
];
const _largeImages = [
  'assets/demo/images/02-breakfast-L.png',
  'assets/demo/images/03-latte-L.png',
];

class MarketingScreen extends ConsumerStatefulWidget {
  const MarketingScreen({super.key});

  @override
  ConsumerState<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends ConsumerState<MarketingScreen> {
  int? _selectedSaleId;
  double? _dragListWidth;

  double _listWidth(double contentWidth, double? preferredWidth) {
    return (preferredWidth ?? 320.0).clamp(
      260.0,
      (contentWidth - 488.0).clamp(260.0, 600.0),
    );
  }

  void _updateListWidth(double delta, double contentWidth) {
    final savedWidth = ref
        .read(appControllerProvider)
        .appearance
        .promotionListWidth;
    setState(() {
      _dragListWidth =
          (_dragListWidth ?? _listWidth(contentWidth, savedWidth)) + delta;
    });
  }

  Future<void> _finishListResize(double contentWidth) async {
    final draggedWidth = _dragListWidth;
    if (draggedWidth == null) {
      return;
    }
    final settings = ref.read(appControllerProvider).appearance;
    final width = _listWidth(contentWidth, draggedWidth);
    final save = ref
        .read(appControllerProvider.notifier)
        .setAppearance(settings.copyWith(promotionListWidth: width));
    setState(() => _dragListWidth = null);
    await save;
  }

  Future<void> _resetListWidth() async {
    final settings = ref.read(appControllerProvider).appearance;
    setState(() => _dragListWidth = null);
    await ref
        .read(appControllerProvider.notifier)
        .setAppearance(settings.copyWith(promotionListWidth: null));
  }

  Future<void> _editPromotion([PromotionEvent? event]) async {
    final result = await showDialog<PromotionEvent>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PromotionDialog(event: event),
    );
    if (result != null && mounted) {
      setState(() => _selectedSaleId = result.saleId);
    }
  }

  Future<void> _deletePromotion(PromotionEvent event, int adCount) async {
    if (adCount > 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先删除这条促销下的广告，再删除促销。')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除促销事件？'),
        content: Text('「${event.displayTitle}」将从本地演示数据中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final deleted = await ref
          .read(appControllerProvider.notifier)
          .deletePromotion(event.saleId);
      if (deleted && mounted) setState(() => _selectedSaleId = null);
    }
  }

  Future<void> _editAd(PromotionEvent event, [Advertisement? ad]) async {
    await showDialog<Advertisement>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AdvertisementDialog(event: event, ad: ad),
    );
  }

  Future<void> _deleteAd(Advertisement ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除广告预览？'),
        content: const Text('这只会移除本机的演示广告，不会影响线上内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(appControllerProvider.notifier)
          .deleteAdvertisement(ad.adId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final marketing = state.marketing;
    final catalog = state.catalog;
    if (marketing == null || catalog == null) {
      return const Center(child: Text('营销数据暂不可用'));
    }
    final promotions = [...marketing.promotions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final selectedId = marketing.promotionById(_selectedSaleId ?? -1) != null
        ? _selectedSaleId
        : promotions.firstOrNull?.saleId;
    final selected = selectedId == null
        ? null
        : marketing.promotionById(selectedId);
    final ads = selected == null
        ? <Advertisement>[]
        : marketing.adsFor(selected.saleId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 940;
        final listWidth = _listWidth(
          constraints.maxWidth,
          _dragListWidth ?? state.appearance.promotionListWidth,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('营销工作台', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '先建立促销事件，再为选中的促销配置广告。当前内容仅保存在本机，不会发布到学生端。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _WorkflowNote(hasPromotion: selected != null),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      key: const Key('promotion-list-pane'),
                      width: listWidth,
                      child: _PromotionList(
                        promotions: promotions,
                        catalog: catalog,
                        selectedId: selectedId,
                        onSelected: (id) =>
                            setState(() => _selectedSaleId = id),
                        onAdd: () => _editPromotion(),
                      ),
                    ),
                    WorkspaceResizeHandle(
                      key: const Key('promotion-resize-handle'),
                      tooltip: '拖动调整促销列表宽度，双击恢复自动宽度',
                      height: 360,
                      onDrag: (delta) =>
                          _updateListWidth(delta, constraints.maxWidth),
                      onDragEnd: () => _finishListResize(constraints.maxWidth),
                      onDragCancel: () => setState(() => _dragListWidth = null),
                      onDoubleTap: _resetListWidth,
                    ),
                    Expanded(child: _detail(selected, ads, catalog)),
                  ],
                )
              else ...[
                _PromotionList(
                  promotions: promotions,
                  catalog: catalog,
                  selectedId: selectedId,
                  onSelected: (id) => setState(() => _selectedSaleId = id),
                  onAdd: () => _editPromotion(),
                ),
                const SizedBox(height: 16),
                _detail(selected, ads, catalog),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _detail(
    PromotionEvent? event,
    List<Advertisement> ads,
    CatalogSnapshot catalog,
  ) {
    if (event == null) {
      return _Panel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 46),
          child: Column(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text('从一条促销开始', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('建好促销后，这里就能添加与它关联的广告。'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _editPromotion(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('新建促销'),
              ),
            ],
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final product = event.productId == null
        ? null
        : catalog.productById(event.productId!);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '促销详情',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            event.displayTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '${product?.productName ?? (event.productId == null ? '全店促销' : '关联商品已移除')}  ·  ${event.statusAt(DateTime.now())}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text('开始：${_dateFormat.format(event.startTime)}'),
          Text(
            '结束：${event.endTime == null ? '长期有效' : _dateFormat.format(event.endTime!)}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _editPromotion(event),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑促销'),
              ),
              TextButton.icon(
                onPressed: () => _deletePromotion(event, ads.length),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('删除促销'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '关联广告',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.tonalIcon(
                key: const Key('marketing-add-ad'),
                onPressed: () => _editAd(event),
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加广告'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '每条广告都属于当前促销。仅使用内置素材进行本地预览。',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          if (ads.isEmpty)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Text('还没有关联广告。可先添加一张小广告或横幅广告。')),
            )
          else
            for (final ad in ads) ...[
              _AdCard(
                ad: ad,
                onEdit: () => _editAd(event, ad),
                onDelete: () => _deleteAd(ad),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _WorkflowNote extends StatelessWidget {
  const _WorkflowNote({required this.hasPromotion});
  final bool hasPromotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.route_rounded, color: scheme.onPrimaryContainer),
          Text(
            '建立促销事件',
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
          Text(
            hasPromotion ? '为选中的促销配置广告' : '选择促销后配置广告',
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class _PromotionList extends StatelessWidget {
  const _PromotionList({
    required this.promotions,
    required this.catalog,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
  });
  final List<PromotionEvent> promotions;
  final CatalogSnapshot catalog;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '促销事件',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                key: const Key('marketing-add-promotion'),
                tooltip: '新建促销',
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${promotions.length} 条本地促销',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          if (promotions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('还没有促销事件')),
            )
          else
            for (final event in promotions) ...[
              Material(
                color: event.saleId == selectedId
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: Key('promotion-item-${event.saleId}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelected(event.saleId),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${event.productId == null ? '全店' : catalog.productById(event.productId!)?.productName ?? '商品已移除'} · ${event.statusAt(DateTime.now())}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({
    required this.ad,
    required this.onEdit,
    required this.onDelete,
  });
  final Advertisement ad;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('advertisement-item-${ad.adId}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: ad.type == 'S' ? 68 : 114,
            height: 68,
            child: ProductImage(assetPath: ad.img, borderRadius: 10),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad.type == 'S' ? '小广告 · 1:1' : '横幅广告 · 3:1',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${ad.statusAt(DateTime.now())} · 本地预览',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑广告',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '删除广告',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _PromotionDialog extends ConsumerStatefulWidget {
  const _PromotionDialog({this.event});
  final PromotionEvent? event;

  @override
  ConsumerState<_PromotionDialog> createState() => _PromotionDialogState();
}

class _PromotionDialogState extends ConsumerState<_PromotionDialog> {
  late final TextEditingController _rule;
  late final TextEditingController _start;
  late final TextEditingController _end;
  int? _productId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _rule = TextEditingController(text: event?.saleRule ?? '');
    _start = TextEditingController(
      text: _dateFormat.format(event?.startTime ?? DateTime.now()),
    );
    _end = TextEditingController(
      text: event?.endTime == null ? '' : _dateFormat.format(event!.endTime!),
    );
    _productId = event?.productId;
  }

  @override
  void dispose() {
    _rule.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final start = _parseDate(_start.text);
    final end = _end.text.trim().isEmpty ? null : _parseDate(_end.text);
    if (start == null || (_end.text.trim().isNotEmpty && end == null)) {
      setState(() => _error = '请按 YYYY-MM-DD HH:mm 填写有效时间');
      return;
    }
    final draft = PromotionDraft(
      saleRule: _rule.text,
      productId: _productId,
      startTime: start,
      endTime: end,
    );
    final errors = draft.validationErrors(
      ref.read(appControllerProvider).catalog!,
    );
    if (errors.isNotEmpty) {
      setState(() => _error = errors.values.join('；'));
      return;
    }
    final saved = await ref
        .read(appControllerProvider.notifier)
        .savePromotion(draft, saleId: widget.event?.saleId);
    if (saved != null && mounted) Navigator.pop(context, saved);
    if (saved == null && mounted) {
      setState(() => _error = ref.read(appControllerProvider).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(appControllerProvider).catalog!;
    return AlertDialog(
      title: Text(widget.event == null ? '新建促销事件' : '编辑促销事件'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('促销先于广告建立；保存后可在详情中添加广告。'),
              const SizedBox(height: 18),
              TextField(
                key: const Key('promotion-rule'),
                controller: _rule,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '促销规则',
                  hintText: '例如：早餐组合立减 3 元',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                key: const Key('promotion-product'),
                initialValue: catalog.productById(_productId ?? -1) == null
                    ? null
                    : _productId,
                decoration: const InputDecoration(labelText: '关联商品'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('全店促销'),
                  ),
                  for (final product in catalog.products)
                    DropdownMenuItem<int?>(
                      value: product.productId,
                      child: Text(product.productName),
                    ),
                ],
                onChanged: (value) => setState(() => _productId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('promotion-start'),
                controller: _start,
                decoration: const InputDecoration(
                  labelText: '开始时间',
                  hintText: 'YYYY-MM-DD HH:mm',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('promotion-end'),
                controller: _end,
                decoration: const InputDecoration(
                  labelText: '结束时间（留空表示长期有效）',
                  hintText: 'YYYY-MM-DD HH:mm',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('promotion-save'),
          onPressed: _save,
          child: const Text('保存促销'),
        ),
      ],
    );
  }
}

class _AdvertisementDialog extends ConsumerStatefulWidget {
  const _AdvertisementDialog({required this.event, this.ad});
  final PromotionEvent event;
  final Advertisement? ad;

  @override
  ConsumerState<_AdvertisementDialog> createState() =>
      _AdvertisementDialogState();
}

class _AdvertisementDialogState extends ConsumerState<_AdvertisementDialog> {
  late final TextEditingController _start;
  late final TextEditingController _end;
  late String _type;
  late String _img;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ad = widget.ad;
    _type = ad?.type ?? 'S';
    _img = ad?.img ?? _smallImages.first;
    _start = TextEditingController(
      text: _dateFormat.format(ad?.startTime ?? widget.event.startTime),
    );
    _end = TextEditingController(
      text: (ad?.endTime ?? widget.event.endTime) == null
          ? ''
          : _dateFormat.format((ad?.endTime ?? widget.event.endTime)!),
    );
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final start = _parseDate(_start.text);
    final end = _end.text.trim().isEmpty ? null : _parseDate(_end.text);
    if (start == null || (_end.text.trim().isNotEmpty && end == null)) {
      setState(() => _error = '请按 YYYY-MM-DD HH:mm 填写有效时间');
      return;
    }
    final draft = AdvertisementDraft(
      saleId: widget.event.saleId,
      startTime: start,
      endTime: end,
      type: _type,
      img: _img,
    );
    final errors = draft.validationErrors(
      ref.read(appControllerProvider).marketing!,
    );
    if (errors.isNotEmpty) {
      setState(() => _error = errors.values.join('；'));
      return;
    }
    final saved = await ref
        .read(appControllerProvider.notifier)
        .saveAdvertisement(draft, adId: widget.ad?.adId);
    if (saved != null && mounted) Navigator.pop(context, saved);
    if (saved == null && mounted) {
      setState(() => _error = ref.read(appControllerProvider).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _type == 'S' ? _smallImages : _largeImages;
    return AlertDialog(
      title: Text(widget.ad == null ? '添加关联广告' : '编辑关联广告'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('关联促销：${widget.event.displayTitle}'),
              const SizedBox(height: 4),
              const Text('此处仅供本地预览，不上传图片、不发布广告。'),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                key: const Key('ad-type'),
                segments: const [
                  ButtonSegment(value: 'S', label: Text('小广告 1:1')),
                  ButtonSegment(value: 'L', label: Text('横幅 3:1')),
                ],
                selected: {_type},
                onSelectionChanged: (value) => setState(() {
                  _type = value.first;
                  _img = (_type == 'S' ? _smallImages : _largeImages).first;
                }),
              ),
              const SizedBox(height: 14),
              Text('内置演示素材', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final image in images)
                    InkWell(
                      key: Key('ad-image-${image.split('/').last}'),
                      onTap: () => setState(() => _img = image),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: _type == 'S' ? 104 : 180,
                        height: _type == 'S' ? 104 : 64,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _img == image
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: _img == image ? 2 : 1,
                          ),
                        ),
                        child: ProductImage(assetPath: image, borderRadius: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('ad-start'),
                controller: _start,
                decoration: const InputDecoration(
                  labelText: '开始时间',
                  hintText: 'YYYY-MM-DD HH:mm',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ad-end'),
                controller: _end,
                decoration: const InputDecoration(
                  labelText: '结束时间（可留空）',
                  hintText: 'YYYY-MM-DD HH:mm',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('ad-save'),
          onPressed: _save,
          child: const Text('保存广告预览'),
        ),
      ],
    );
  }
}
