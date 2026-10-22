import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../state/app_state.dart';
import 'common.dart';

typedef ProductSaveCallback = Future<Product?> Function(ProductDraft draft);

class ProductEditor extends ConsumerStatefulWidget {
  const ProductEditor({
    required this.catalog,
    required this.onSave,
    required this.onCancel,
    super.key,
    this.product,
  });

  final CatalogSnapshot catalog;
  final Product? product;
  final ProductSaveCallback onSave;
  final VoidCallback onCancel;

  @override
  ConsumerState<ProductEditor> createState() => ProductEditorState();
}

class ProductEditorState extends ConsumerState<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _introController;
  late int _mainShopId;
  int? _subShopId;
  int? _categoryId;
  String? _imagePath;
  late ProductDraft _initialDraft;
  var _attemptedSave = false;
  var _saving = false;
  var _dirty = false;

  static const _imageChoices = <(String, String)>[
    ('assets/demo/images/01-americano-S.png', '冰美式'),
    ('assets/demo/images/02-breakfast-L.png', '早餐三明治'),
    ('assets/demo/images/03-latte-L.png', '拿铁咖啡'),
    ('assets/demo/images/04-sausage-S.png', '烤肠'),
  ];

  @override
  void initState() {
    super.initState();
    final source = widget.product;
    final fallbackShopId = widget.catalog.mainShops.isEmpty
        ? 0
        : widget.catalog.mainShops.first.shopId;
    _nameController = TextEditingController(text: source?.productName ?? '');
    _priceController = TextEditingController(
      text: source?.priceAsDecimal ?? '',
    );
    _introController = TextEditingController(text: source?.productIntro ?? '');
    _mainShopId = source?.mainShopId ?? fallbackShopId;
    _subShopId = source?.subShopId;
    _categoryId = source?.categoryId;
    _imagePath = source?.productImg;
    _initialDraft = _draft;
    _nameController.addListener(_markDirty);
    _priceController.addListener(_markDirty);
    _introController.addListener(_markDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _introController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  ProductDraft get _draft => ProductDraft(
    productName: _nameController.text,
    priceText: _priceController.text,
    categoryId: _categoryId,
    productImg: _imagePath,
    productIntro: _introController.text,
    mainShopId: _mainShopId,
    subShopId: _subShopId,
  );

  bool _sameDraft(ProductDraft left, ProductDraft right) {
    return left.productName == right.productName &&
        left.priceText == right.priceText &&
        left.categoryId == right.categoryId &&
        left.productImg == right.productImg &&
        left.productIntro == right.productIntro &&
        left.mainShopId == right.mainShopId &&
        left.subShopId == right.subShopId;
  }

  void _markDirty() {
    if (!mounted) {
      return;
    }
    final next = !_sameDraft(_draft, _initialDraft);
    if (next != _dirty) {
      setState(() => _dirty = next);
      ref.read(unsavedChangesProvider.notifier).setUnsaved(next);
    }
  }

  Future<void> cancel() async {
    if (_dirty && !await confirmDiscardChanges(context)) {
      return;
    }
    ref.read(unsavedChangesProvider.notifier).setUnsaved(false);
    widget.onCancel();
  }

  Future<Product?> save() async {
    if (_saving) {
      return null;
    }
    setState(() => _attemptedSave = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return null;
    }
    final errors = _draft.validationErrors(widget.catalog);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errors.values.join('；'))));
      return null;
    }
    setState(() => _saving = true);
    final saved = await widget.onSave(_draft);
    if (!mounted) {
      return saved;
    }
    setState(() => _saving = false);
    if (saved != null) {
      _initialDraft = ProductDraft.fromProduct(saved);
      _dirty = false;
      ref.read(unsavedChangesProvider.notifier).setUnsaved(false);
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final permittedShopIds = ref.watch(
      appControllerProvider.select(
        (state) => state.session?.shopIds.toSet() ?? <int>{},
      ),
    );
    final availableMainShops = widget.catalog.mainShops
        .where(
          (shop) =>
              permittedShopIds.isEmpty ||
              permittedShopIds.contains(shop.shopId),
        )
        .toList(growable: false);
    final destinationValue = _subShopId == null
        ? 'main:$_mainShopId'
        : 'sub:$_subShopId';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): save,
        const SingleActivator(LogicalKeyboardKey.escape): cancel,
      },
      child: Focus(
        autofocus: true,
        child: Form(
          key: _formKey,
          autovalidateMode: _attemptedSave
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            children: [
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: '取消 (Esc)',
                      onPressed: _saving ? null : cancel,
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.product == null ? '新增商品' : '编辑商品',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_dirty) ...[
                      Chip(
                        avatar: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('未保存'),
                        backgroundColor: scheme.tertiaryContainer,
                        side: BorderSide.none,
                      ),
                      const SizedBox(width: 12),
                    ],
                    FilledButton.icon(
                      key: const Key('product-save'),
                      onPressed: _saving ? null : save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionHeading(
                            icon: Icons.edit_note_rounded,
                            title: '基本信息',
                            subtitle: '商品名称和价格是必填项。',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('product-name'),
                            controller: _nameController,
                            focusNode: _nameFocus,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: '商品名称 *',
                              hintText: '例如：冰美式',
                            ),
                            validator: (value) {
                              final name = value?.trim() ?? '';
                              if (name.isEmpty || name.length > 100) {
                                return '请输入 1–100 个字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('product-price'),
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '价格 *',
                              prefixText: '¥ ',
                              hintText: '0.00',
                              helperText: '最多两位小数，上限 99999999.99',
                            ),
                            validator: (value) =>
                                parsePriceInCents(value ?? '') == null
                                ? '价格不符合 DECIMAL(10,2)'
                                : null,
                          ),
                          const SizedBox(height: 28),
                          const _SectionHeading(
                            icon: Icons.account_tree_rounded,
                            title: '商品归属',
                            subtitle: '选择商品上架目录。主商户可维护直营目录，也可代管名下子商户。',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: const Key('product-ownership'),
                            initialValue: destinationValue,
                            isExpanded: true,
                            itemHeight: 64,
                            decoration: const InputDecoration(
                              labelText: '上架到 *',
                              helperText: '子商户拥有独立账号；当前主账号具有向下代管权限。',
                            ),
                            items: [
                              for (final mainShop in availableMainShops) ...[
                                DropdownMenuItem(
                                  value: 'main:${mainShop.shopId}',
                                  child: _DestinationOption(
                                    icon: Icons.storefront_rounded,
                                    title: mainShop.shopName,
                                    subtitle: '主商户直营 · 当前主账号',
                                  ),
                                ),
                                for (final subShop
                                    in widget.catalog.subShops.where(
                                      (shop) =>
                                          shop.mainShopId == mainShop.shopId,
                                    ))
                                  DropdownMenuItem(
                                    value: 'sub:${subShop.shopId}',
                                    child: _DestinationOption(
                                      icon: Icons
                                          .subdirectory_arrow_right_rounded,
                                      title: subShop.shopName,
                                      subtitle: '子商户独立账号 · 主商户可代管',
                                      indented: true,
                                    ),
                                  ),
                              ],
                            ],
                            selectedItemBuilder: (context) => [
                              for (final mainShop in availableMainShops) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${mainShop.shopName} · 主店直营',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                for (final subShop
                                    in widget.catalog.subShops.where(
                                      (shop) =>
                                          shop.mainShopId == mainShop.shopId,
                                    ))
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${subShop.shopName} · 主商户代管',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                if (value.startsWith('main:')) {
                                  _mainShopId = int.parse(value.substring(5));
                                  _subShopId = null;
                                } else {
                                  final subShopId = int.parse(
                                    value.substring(4),
                                  );
                                  final subShop = widget.catalog.subShopById(
                                    subShopId,
                                  );
                                  if (subShop != null) {
                                    _mainShopId = subShop.mainShopId;
                                    _subShopId = subShop.shopId;
                                  }
                                }
                              });
                              _markDirty();
                            },
                            validator: (value) =>
                                value == null ? '请选择商品所属目录' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int?>(
                            key: const Key('product-category'),
                            initialValue: _categoryId,
                            decoration: const InputDecoration(
                              labelText: '商品分类',
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('未分类'),
                              ),
                              for (final category in widget.catalog.categories)
                                DropdownMenuItem<int?>(
                                  value: category.categoryId,
                                  child: Text(category.categoryName),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _categoryId = value);
                              _markDirty();
                            },
                          ),
                          const SizedBox(height: 28),
                          const _SectionHeading(
                            icon: Icons.image_outlined,
                            title: '图片与介绍',
                            subtitle: '首版可选用内置演示素材，也可留空。',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 156,
                                height: 112,
                                child: ProductImage(assetPath: _imagePath),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  key: const Key('product-image'),
                                  initialValue: _imagePath,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '内置示例图',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('无图占位'),
                                    ),
                                    for (final choice in _imageChoices)
                                      DropdownMenuItem<String?>(
                                        value: choice.$1,
                                        child: Text(choice.$2),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _imagePath = value);
                                    _markDirty();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('product-intro'),
                            controller: _introController,
                            minLines: 4,
                            maxLines: 7,
                            decoration: const InputDecoration(
                              labelText: '商品介绍',
                              alignLabelWithHint: true,
                              hintText: '输入口味、搭配或适用场景…',
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '快捷键：Ctrl/Cmd+S 保存 · Esc 取消',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationOption extends StatelessWidget {
  const _DestinationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.indented = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: indented ? 20 : 0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: scheme.onPrimaryContainer, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
