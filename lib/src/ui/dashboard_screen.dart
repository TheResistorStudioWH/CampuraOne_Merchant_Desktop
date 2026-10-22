import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../state/app_state.dart';
import 'app_theme.dart';
import 'common.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    final catalog = appState.catalog;
    if (catalog == null) {
      return const Center(child: Text('商品数据暂不可用'));
    }
    final permittedShopIds = appState.session?.shopIds.toSet() ?? <int>{};
    final managedMainShops = catalog.mainShops
        .where(
          (shop) =>
              permittedShopIds.isEmpty ||
              permittedShopIds.contains(shop.shopId),
        )
        .toList(growable: false);
    final managedMainShopIds = managedMainShops
        .map((shop) => shop.shopId)
        .toSet();
    final managedSubShops = catalog.subShops
        .where((shop) => managedMainShopIds.contains(shop.mainShopId))
        .toList(growable: false);
    final products = catalog.products
        .where(
          (product) =>
              permittedShopIds.isEmpty ||
              permittedShopIds.contains(product.mainShopId),
        )
        .toList(growable: false);
    final directCount = products.where((item) => item.subShopId == null).length;
    final subShopCount = products.length - directCount;
    final usedCategories = products
        .map((item) => item.categoryId)
        .whereType<int>()
        .toSet()
        .length;
    final recent = [...products]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 880;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHero(
                productCount: products.length,
                managedSubShopCount: managedSubShops.length,
                onAdd: () => context.go('/products/new'),
              ),
              const SizedBox(height: 20),
              _MetricStrip(
                productCount: products.length,
                directCount: directCount,
                managedCount: subShopCount,
                categoryCount: usedCategories,
              ),
              const SizedBox(height: 24),
              _ManagementHierarchy(
                mainShops: managedMainShops,
                subShops: managedSubShops,
                products: products,
              ),
              const SizedBox(height: 24),
              if (twoColumns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _CategoryDistribution(
                        products: products,
                        catalog: catalog,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _RecentProducts(
                        products: recent.take(5).toList(growable: false),
                        catalog: catalog,
                      ),
                    ),
                  ],
                )
              else ...[
                _CategoryDistribution(products: products, catalog: catalog),
                const SizedBox(height: 16),
                _RecentProducts(
                  products: recent.take(5).toList(growable: false),
                  catalog: catalog,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.productCount,
    required this.managedSubShopCount,
    required this.onAdd,
  });

  final int productCount;
  final int managedSubShopCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 22, 22),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_rounded,
                color: scheme.onPrimary,
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '经营概览',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '当前以主商户账号管理 $managedSubShopCount 个子商户，共有 $productCount 件商品。',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const Key('dashboard-add-product'),
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('新增商品'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({
    required this.productCount,
    required this.directCount,
    required this.managedCount,
    required this.categoryCount,
  });

  final int productCount;
  final int directCount;
  final int managedCount;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = [
      (Icons.inventory_2_outlined, '$productCount', '商品总数'),
      (Icons.storefront_outlined, '$directCount', '主店直营'),
      (Icons.account_tree_outlined, '$managedCount', '代管商品'),
      (Icons.category_outlined, '$categoryCount', '已用分类'),
    ];
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 680) {
            return IntrinsicHeight(
              child: Row(
                children: [
                  for (var index = 0; index < metrics.length; index++) ...[
                    if (index > 0)
                      const VerticalDivider(
                        width: 1,
                        indent: 18,
                        endIndent: 18,
                      ),
                    Expanded(
                      child: _MetricCell(
                        icon: metrics[index].$1,
                        value: metrics[index].$2,
                        label: metrics[index].$3,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCell(
                      icon: metrics[0].$1,
                      value: metrics[0].$2,
                      label: metrics[0].$3,
                    ),
                  ),
                  const SizedBox(height: 72, child: VerticalDivider(width: 1)),
                  Expanded(
                    child: _MetricCell(
                      icon: metrics[1].$1,
                      value: metrics[1].$2,
                      label: metrics[1].$3,
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              Row(
                children: [
                  Expanded(
                    child: _MetricCell(
                      icon: metrics[2].$1,
                      value: metrics[2].$2,
                      label: metrics[2].$3,
                    ),
                  ),
                  const SizedBox(height: 72, child: VerticalDivider(width: 1)),
                  Expanded(
                    child: _MetricCell(
                      icon: metrics[3].$1,
                      value: metrics[3].$2,
                      label: metrics[3].$3,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      child: Row(
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementHierarchy extends StatelessWidget {
  const _ManagementHierarchy({
    required this.mainShops,
    required this.subShops,
    required this.products,
  });

  final List<MainShop> mainShops;
  final List<SubShop> subShops;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账号与商品目录',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          '当前为主商户视角。层级表示管理范围，不代表正在切换账号。',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (mainShops.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('当前账号尚未关联主商户'),
                )
              else
                for (
                  var mainIndex = 0;
                  mainIndex < mainShops.length;
                  mainIndex++
                ) ...[
                  if (mainIndex > 0) const Divider(height: 1),
                  _HierarchyRow(
                    key: Key('main-shop-scope-${mainShops[mainIndex].shopId}'),
                    icon: Icons.storefront_rounded,
                    title: mainShops[mainIndex].shopName,
                    role: '主商户账号',
                    detail: '当前账号 · 完整管理权',
                    productCount: products
                        .where(
                          (product) =>
                              product.mainShopId ==
                                  mainShops[mainIndex].shopId &&
                              product.subShopId == null,
                        )
                        .length,
                  ),
                  for (final subShop in subShops.where(
                    (shop) => shop.mainShopId == mainShops[mainIndex].shopId,
                  )) ...[
                    const Divider(height: 1, indent: 70),
                    _HierarchyRow(
                      key: Key('sub-shop-scope-${subShop.shopId}'),
                      icon: Icons.subdirectory_arrow_right_rounded,
                      title: subShop.shopName,
                      role: '独立子账号',
                      detail: '权限较低 · 主商户可代管',
                      productCount: products
                          .where(
                            (product) => product.subShopId == subShop.shopId,
                          )
                          .length,
                      child: true,
                    ),
                  ],
                ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
                color: scheme.secondaryContainer.withValues(alpha: 0.55),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 20,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '权限方向：主商户可管理子商户商品；子商户仅能管理自己的目录。',
                        style: TextStyle(color: scheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HierarchyRow extends StatelessWidget {
  const _HierarchyRow({
    required this.icon,
    required this.title,
    required this.role,
    required this.detail,
    required this.productCount,
    super.key,
    this.child = false,
  });

  final IconData icon;
  final String title;
  final String role;
  final String detail;
  final int productCount;
  final bool child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(child ? 42 : 18, 15, 18, 15),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: child ? scheme.tertiaryContainer : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color: child
                  ? scheme.onTertiaryContainer
                  : scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        role,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(detail, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$productCount',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                child ? '代管商品' : '直营商品',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryDistribution extends StatelessWidget {
  const _CategoryDistribution({required this.products, required this.catalog});

  final List<Product> products;
  final CatalogSnapshot catalog;

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{};
    var uncategorized = 0;
    for (final product in products) {
      if (product.categoryId == null) {
        uncategorized++;
      } else {
        counts.update(
          product.categoryId!,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final rows = catalog.categories
        .where((category) => (counts[category.categoryId] ?? 0) > 0)
        .toList(growable: false);
    final maxCount = [
      ...counts.values,
      if (uncategorized > 0) uncategorized,
      1,
    ].reduce((left, right) => left > right ? left : right);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分类分布',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '按当前商品数量统计',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (rows.isEmpty && uncategorized == 0)
              const _InlineEmpty(message: '暂无可统计的商品')
            else ...[
              for (final category in rows)
                _DistributionRow(
                  label: category.categoryName,
                  count: counts[category.categoryId] ?? 0,
                  maxCount: maxCount,
                  icon: materialIconForCategory(category.categoryIcon),
                  color: materialColorForCategory(
                    category.categoryColor,
                    Theme.of(context).colorScheme,
                  ),
                ),
              if (uncategorized > 0)
                _DistributionRow(
                  label: '未分类',
                  count: uncategorized,
                  maxCount: maxCount,
                  icon: Icons.help_outline_rounded,
                  color: Theme.of(context).colorScheme.outline,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final int maxCount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: count / maxCount,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 20,
            child: Text('$count', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _RecentProducts extends StatelessWidget {
  const _RecentProducts({required this.products, required this.catalog});

  final List<Product> products;
  final CatalogSnapshot catalog;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM月dd日  HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '最近更新',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/products'),
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (products.isEmpty)
              const _InlineEmpty(message: '还没有商品更新')
            else
              for (final product in products)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => context.go('/products/${product.productId}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 44,
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
                              Text(
                                product.productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                dateFormat.format(product.updatedAt),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text('¥${product.priceAsDecimal}'),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
