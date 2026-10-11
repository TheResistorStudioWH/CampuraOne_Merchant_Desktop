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
    final availableSubShops = widget.catalog.subShops
        .where((shop) => shop.mainShopId == _mainShopId)
        .toList(growable: false);
    final ownershipValue = _subShopId == null ? 'direct' : 'sub:$_subShopId';

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
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
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
                    if (_dirty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '未保存',
                          style: TextStyle(color: scheme.primary),
                        ),
                      ),
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
                            title: '归属与分类',
                            subtitle: '直营商品不关联附属商户。',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            key: const Key('product-main-shop'),
                            initialValue: _mainShopId,
                            decoration: const InputDecoration(
                              labelText: '主商户 *',
                            ),
                            items: [
                              for (final shop in widget.catalog.mainShops)
                                DropdownMenuItem(
                                  value: shop.shopId,
                                  child: Text(shop.shopName),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _mainShopId = value;
                                final valid = widget.catalog.subShops.any(
                                  (shop) =>
                                      shop.shopId == _subShopId &&
                                      shop.mainShopId == value,
                                );
                                if (!valid) {
                                  _subShopId = null;
                                }
                              });
                              _markDirty();
                            },
                            validator: (value) =>
                                value == null || value == 0 ? '请选择主商户' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: const Key('product-ownership'),
                            initialValue: ownershipValue,
                            decoration: const InputDecoration(
                              labelText: '商户归属 *',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'direct',
                                child: Text('主商户直营'),
                              ),
                              for (final shop in availableSubShops)
                                DropdownMenuItem(
                                  value: 'sub:${shop.shopId}',
                                  child: Text('附属商户 · ${shop.shopName}'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _subShopId = value == 'direct'
                                    ? null
                                    : int.parse(value.substring(4));
                              });
                              _markDirty();
                            },
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
