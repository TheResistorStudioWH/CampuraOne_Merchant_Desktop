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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '经营概览',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '用可验证的本地商品数据快速了解当前目录。',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    key: const Key('dashboard-add-product'),
                    onPressed: () => context.go('/products/new'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('新增商品'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: constraints.maxWidth >= 960 ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth >= 960 ? 1.8 : 2.15,
                children: [
                  _MetricCard(
                    label: '商品总数',
                    value: '${products.length}',
                    icon: Icons.inventory_2_rounded,
                    color: brandPurple,
                  ),
                  _MetricCard(
                    label: '主商户直营',
                    value: '$directCount',
                    icon: Icons.store_rounded,
                    color: brandBlue,
                  ),
                  _MetricCard(
                    label: '附属商户商品',
                    value: '$subShopCount',
                    icon: Icons.account_tree_rounded,
                    color: const Color(0xFFF18F32),
                  ),
                  _MetricCard(
                    label: '已使用分类',
                    value: '$usedCategories',
                    icon: Icons.category_rounded,
                    color: const Color(0xFF4B9B65),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant),
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
