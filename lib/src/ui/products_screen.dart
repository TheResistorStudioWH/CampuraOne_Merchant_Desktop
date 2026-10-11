import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../state/app_state.dart';
import 'app_theme.dart';
import 'common.dart';
import 'product_editor.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _editorKey = GlobalKey<ProductEditorState>();
  int? _categoryId;
  var _ownership = ProductOwnership.all;
  var _sort = ProductSort.updatedDesc;
  int? _selectedId;
  var _editing = false;
  var _creating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<bool> _discardIfNeeded() async {
    if (!ref.read(unsavedChangesProvider)) {
      return true;
    }
    final discard = await confirmDiscardChanges(context);
    if (discard) {
      ref.read(unsavedChangesProvider.notifier).setUnsaved(false);
    }
    return discard;
  }

  Future<void> _startNew(bool wide) async {
    if (!wide) {
      context.go('/products/new');
      return;
    }
    if (!await _discardIfNeeded() || !mounted) {
      return;
    }
    setState(() {
      _creating = true;
      _editing = false;
    });
  }

  Future<void> _selectProduct(Product product, bool wide) async {
    if (!wide) {
      context.go('/products/${product.productId}');
      return;
    }
    if (_selectedId == product.productId && !_creating) {
      return;
    }
    if (!await _discardIfNeeded() || !mounted) {
      return;
    }
    setState(() {
      _selectedId = product.productId;
      _editing = false;
      _creating = false;
    });
  }

  Future<Product?> _saveDraft(ProductDraft draft) async {
    final controller = ref.read(appControllerProvider.notifier);
    final saved = _creating
        ? await controller.createProduct(draft)
        : await controller.updateProduct(_selectedId!, draft);
    if (saved != null && mounted) {
      setState(() {
        _selectedId = saved.productId;
        _creating = false;
        _editing = false;
      });
    }
    return saved;
  }

  void _cancelEditor() {
    if (!mounted) {
      return;
    }
    setState(() {
      _creating = false;
      _editing = false;
    });
  }

  Future<void> _delete(Product product) async {
    final confirmed = await _confirmDelete(context, product);
    if (!confirmed) {
      return;
    }
    final deleted = await ref
        .read(appControllerProvider.notifier)
        .deleteProduct(product);
    if (deleted && mounted) {
      setState(() {
        _selectedId = null;
        _editing = false;
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final catalog = appState.catalog;
    if (catalog == null) {
      return const Center(child: Text('商品数据暂不可用'));
    }
    final permittedShops = appState.session?.shopIds.toSet() ?? <int>{};
    final ownedProducts = catalog.products.where(
      (product) =>
          permittedShops.isEmpty || permittedShops.contains(product.mainShopId),
    );
    final products = ProductQuery(
      search: _searchController.text,
      categoryId: _categoryId,
      ownership: _ownership,
      sort: _sort,
    ).apply(ownedProducts);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        Product? selected;
        if (_selectedId != null) {
          selected = catalog.productById(_selectedId!);
        }
        selected ??= products.isEmpty ? null : products.first;
        _selectedId ??= selected?.productId;

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
                _startNew(wide),
            const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
                _startNew(wide),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                _searchFocus.requestFocus,
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                _searchFocus.requestFocus,
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
                _editorKey.currentState?.save(),
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
                _editorKey.currentState?.save(),
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_editing || _creating) {
                _editorKey.currentState?.cancel();
              }
            },
          },
          child: Focus(
            autofocus: true,
            child: Column(
              children: [
                _ProductToolbar(
                  searchController: _searchController,
                  searchFocus: _searchFocus,
                  categories: catalog.categories,
                  categoryId: _categoryId,
                  ownership: _ownership,
                  sort: _sort,
                  resultCount: products.length,
                  onSearchChanged: (_) => setState(() {}),
                  onCategoryChanged: (value) =>
                      setState(() => _categoryId = value),
                  onOwnershipChanged: (value) =>
                      setState(() => _ownership = value),
                  onSortChanged: (value) => setState(() => _sort = value),
                  onAdd: () => _startNew(wide),
                ),
                const Divider(height: 1),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            SizedBox(
                              width: constraints.maxWidth < 1020 ? 370 : 420,
                              child: _ProductList(
                                products: products,
                                catalog: catalog,
                                selectedId: selected?.productId,
                                hasAnyProducts: catalog.products.isNotEmpty,
                                onSelected: (product) =>
                                    _selectProduct(product, true),
                                onClearFilters: _clearFilters,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _creating || _editing
                                  ? ProductEditor(
                                      key: _editorKey,
                                      catalog: catalog,
                                      product: _creating ? null : selected,
                                      onSave: _saveDraft,
                                      onCancel: _cancelEditor,
                                    )
                                  : ProductDetailsPane(
                                      product: selected,
                                      catalog: catalog,
                                      onEdit: selected == null
                                          ? null
                                          : () => setState(() {
                                              _selectedId = selected!.productId;
                                              _editing = true;
                                            }),
                                      onDelete: selected == null
                                          ? null
                                          : () => _delete(selected!),
                                      onCreate: () => _startNew(true),
                                    ),
                            ),
                          ],
                        )
                      : _ProductList(
                          products: products,
                          catalog: catalog,
                          selectedId: null,
                          hasAnyProducts: catalog.products.isNotEmpty,
                          onSelected: (product) =>
                              _selectProduct(product, false),
                          onClearFilters: _clearFilters,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _categoryId = null;
      _ownership = ProductOwnership.all;
      _sort = ProductSort.updatedDesc;
    });
  }
}

class ProductRoutePage extends ConsumerStatefulWidget {
  const ProductRoutePage({super.key, this.productId});

  final int? productId;

  bool get creating => productId == null;

  @override
  ConsumerState<ProductRoutePage> createState() => _ProductRoutePageState();
}

class _ProductRoutePageState extends ConsumerState<ProductRoutePage> {
  final _editorKey = GlobalKey<ProductEditorState>();
  var _editing = false;

  Future<Product?> _save(ProductDraft draft) async {
    final controller = ref.read(appControllerProvider.notifier);
    final saved = widget.creating
        ? await controller.createProduct(draft)
        : await controller.updateProduct(widget.productId!, draft);
    if (saved != null && mounted) {
      context.go('/products/${saved.productId}');
    }
    return saved;
  }

  void _cancel() {
    if (widget.creating) {
      context.go('/products');
    } else {
      setState(() => _editing = false);
    }
  }

  Future<void> _delete(Product product) async {
    if (!await _confirmDelete(context, product)) {
      return;
    }
    final deleted = await ref
        .read(appControllerProvider.notifier)
        .deleteProduct(product);
    if (deleted && mounted) {
      context.go('/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(appControllerProvider).catalog;
    if (catalog == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final product = widget.productId == null
        ? null
        : catalog.productById(widget.productId!);
    if (!widget.creating && product == null) {
      return _NotFound(
        message: '该商品已不存在',
        onBack: () => context.go('/products'),
      );
    }
    if (widget.creating || _editing) {
      return ProductEditor(
        key: _editorKey,
        catalog: catalog,
        product: product,
        onSave: _save,
        onCancel: _cancel,
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            context.go('/products/new'),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            context.go('/products/new'),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            context.go('/products'),
      },
      child: Focus(
        autofocus: true,
        child: ProductDetailsPane(
          product: product,
          catalog: catalog,
          showBack: true,
          onBack: () => context.go('/products'),
          onEdit: () => setState(() => _editing = true),
          onDelete: () => _delete(product!),
          onCreate: () => context.go('/products/new'),
        ),
      ),
    );
  }
}

class _ProductToolbar extends StatelessWidget {
  const _ProductToolbar({
    required this.searchController,
    required this.searchFocus,
    required this.categories,
    required this.categoryId,
    required this.ownership,
    required this.sort,
    required this.resultCount,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onOwnershipChanged,
    required this.onSortChanged,
    required this.onAdd,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final List<ProductCategory> categories;
  final int? categoryId;
  final ProductOwnership ownership;
  final ProductSort sort;
  final int resultCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<ProductOwnership> onOwnershipChanged;
  final ValueChanged<ProductSort> onSortChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('product-search'),
                  controller: searchController,
                  focusNode: searchFocus,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '搜索名称或介绍',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空搜索',
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const Key('product-add'),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('新增商品'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _FilterDropdown<int?>(
                      value: categoryId,
                      tooltip: '分类',
                      icon: Icons.category_outlined,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('全部分类'),
                        ),
                        for (final category in categories)
                          DropdownMenuItem<int?>(
                            value: category.categoryId,
                            child: Text(category.categoryName),
                          ),
                      ],
                      onChanged: onCategoryChanged,
                    ),
                    _FilterDropdown<ProductOwnership>(
                      value: ownership,
                      tooltip: '商户归属',
                      icon: Icons.store_outlined,
                      items: const [
                        DropdownMenuItem(
                          value: ProductOwnership.all,
                          child: Text('全部归属'),
                        ),
                        DropdownMenuItem(
                          value: ProductOwnership.direct,
                          child: Text('主商户直营'),
                        ),
                        DropdownMenuItem(
                          value: ProductOwnership.subShop,
                          child: Text('附属商户'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onOwnershipChanged(value);
                        }
                      },
                    ),
                    _FilterDropdown<ProductSort>(
                      value: sort,
                      tooltip: '排序',
                      icon: Icons.sort_rounded,
                      items: const [
                        DropdownMenuItem(
                          value: ProductSort.updatedDesc,
                          child: Text('最近更新'),
                        ),
                        DropdownMenuItem(
                          value: ProductSort.updatedAsc,
                          child: Text('最早更新'),
                        ),
                        DropdownMenuItem(
                          value: ProductSort.nameAsc,
                          child: Text('名称升序'),
                        ),
                        DropdownMenuItem(
                          value: ProductSort.priceAsc,
                          child: Text('价格从低到高'),
                        ),
                        DropdownMenuItem(
                          value: ProductSort.priceDesc,
                          child: Text('价格从高到低'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onSortChanged(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$resultCount 件商品',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.tooltip,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String tooltip;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 7),
            DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                borderRadius: BorderRadius.circular(10),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.products,
    required this.catalog,
    required this.selectedId,
    required this.hasAnyProducts,
    required this.onSelected,
    required this.onClearFilters,
  });

  final List<Product> products;
  final CatalogSnapshot catalog;
  final int? selectedId;
  final bool hasAnyProducts;
  final ValueChanged<Product> onSelected;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return _EmptyProducts(
        filtered: hasAnyProducts,
        onClearFilters: onClearFilters,
      );
    }
    return ListView.separated(
      key: const Key('product-list'),
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductListTile(
          product: product,
          catalog: catalog,
          selected: product.productId == selectedId,
          onTap: () => onSelected(product),
        );
      },
    );
  }
}

class _ProductListTile extends StatelessWidget {
  const _ProductListTile({
    required this.product,
    required this.catalog,
    required this.selected,
    required this.onTap,
  });

  final Product product;
  final CatalogSnapshot catalog;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = catalog.categoryById(product.categoryId);
    final subShop = catalog.subShopById(product.subShopId);
    return Material(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.72) : null,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        key: Key('product-item-${product.productId}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        hoverColor: scheme.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 60,
                child: ProductImage(
                  assetPath: product.productImg,
                  borderRadius: 9,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '¥${product.priceAsDecimal}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${category?.categoryName ?? '未分类'}  ·  ${subShop?.shopName ?? '主商户直营'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductDetailsPane extends StatelessWidget {
  const ProductDetailsPane({
    required this.product,
    required this.catalog,
    required this.onEdit,
    required this.onDelete,
    required this.onCreate,
    super.key,
    this.showBack = false,
    this.onBack,
  });

  final Product? product;
  final CatalogSnapshot catalog;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onCreate;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (product == null) {
      return _NoSelection(onCreate: onCreate);
    }
    final value = product!;
    final scheme = Theme.of(context).colorScheme;
    final category = catalog.categoryById(value.categoryId);
    final mainShop = catalog.mainShopById(value.mainShopId);
    final subShop = catalog.subShopById(value.subShopId);
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');

    return Column(
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              if (showBack) ...[
                IconButton(
                  tooltip: '返回商品列表 (Esc)',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  '商品详情',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '删除商品',
                onPressed: onDelete,
                color: scheme.error,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                key: const Key('product-edit'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 2.2,
                      child: ProductImage(assetPath: value.productImg),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            value.productName,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '¥${value.priceAsDecimal}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetadataChip(
                          icon: materialIconForCategory(category?.categoryIcon),
                          label: category?.categoryName ?? '未分类',
                          color: materialColorForCategory(
                            category?.categoryColor,
                            scheme,
                          ),
                        ),
                        _MetadataChip(
                          icon: value.subShopId == null
                              ? Icons.store_rounded
                              : Icons.account_tree_rounded,
                          label: subShop?.shopName ?? '主商户直营',
                          color: scheme.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      '商品介绍',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      value.productIntro?.trim().isNotEmpty == true
                          ? value.productIntro!
                          : '暂无介绍',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: value.productIntro?.trim().isNotEmpty == true
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 14),
                    _DetailRow(label: '主商户', value: mainShop?.shopName ?? '未知'),
                    _DetailRow(
                      label: '商品 ID',
                      value: value.productId.toString(),
                    ),
                    _DetailRow(
                      label: '创建时间',
                      value: dateFormat.format(value.createdAt),
                    ),
                    _DetailRow(
                      label: '更新时间',
                      value: dateFormat.format(value.updatedAt),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 18),
            Text(
              '选择一件商品查看详情',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '也可以直接建立第一件本地演示商品。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新增商品'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.filtered, required this.onClearFilters});

  final bool filtered;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off_rounded : Icons.inventory_2_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? '没有匹配的商品' : '还没有商品',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (filtered) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onClearFilters,
                child: const Text('清除搜索和筛选'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 52),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 16),
          FilledButton(onPressed: onBack, child: const Text('返回商品列表')),
        ],
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, Product product) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除商品？'),
          content: Text('「${product.productName}」将从本地演示目录中删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      ) ??
      false;
}
