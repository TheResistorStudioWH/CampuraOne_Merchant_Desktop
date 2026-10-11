import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import 'common.dart';

enum _AccountAction { resetData, logout }

class MerchantAppShell extends ConsumerWidget {
  const MerchantAppShell({required this.child, super.key});

  final Widget child;

  Future<bool> _confirmUnsaved(BuildContext context, WidgetRef ref) async {
    if (!ref.read(unsavedChangesProvider)) {
      return true;
    }
    final discard = await confirmDiscardChanges(context);
    if (discard) {
      ref.read(unsavedChangesProvider.notifier).setUnsaved(false);
    }
    return discard;
  }

  Future<void> _navigate(
    BuildContext context,
    WidgetRef ref,
    String location,
  ) async {
    if (GoRouterState.of(context).uri.path == location) {
      return;
    }
    if (await _confirmUnsaved(context, ref) && context.mounted) {
      context.go(location);
    }
  }

  Future<void> _handleAccountAction(
    BuildContext context,
    WidgetRef ref,
    _AccountAction action,
  ) async {
    if (!await _confirmUnsaved(context, ref) || !context.mounted) {
      return;
    }
    if (action == _AccountAction.logout) {
      await ref.read(appControllerProvider.notifier).logout();
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('恢复标准演示数据？'),
            content: const Text('本地新增、编辑或删除的商品都会被重置。当前登录状态不受影响。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('恢复数据'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await ref.read(appControllerProvider.notifier).resetDemoData();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    final path = GoRouterState.of(context).uri.path;
    final productsSelected = path.startsWith('/products');
    final currentIndex = productsSelected ? 1 : 0;
    final catalog = appState.catalog;
    final shopName = catalog?.mainShops.isNotEmpty == true
        ? catalog!.mainShops.first.shopName
        : '演示商户';

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final extendedRail = constraints.maxWidth >= 1180;
          return Row(
            children: [
              NavigationRail(
                extended: extendedRail,
                minExtendedWidth: 210,
                labelType: extendedRail
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: currentIndex,
                onDestinationSelected: (index) => _navigate(
                  context,
                  ref,
                  index == 0 ? '/dashboard' : '/products',
                ),
                leading: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 28),
                  child: BrandMark(compact: !extendedRail),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard_rounded),
                    label: Text('总览'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2_rounded),
                    label: Text('商品'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      title: productsSelected ? '商品' : '总览',
                      shopName: shopName,
                      userName: appState.session?.userName ?? '',
                      onAction: (action) =>
                          _handleAccountAction(context, ref, action),
                    ),
                    if (appState.busy)
                      const LinearProgressIndicator(minHeight: 2),
                    if (appState.error != null || appState.notice != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: StatusBanner(
                          message: appState.error ?? appState.notice!,
                          isError: appState.error != null,
                          onDismiss: appState.error != null
                              ? ref
                                    .read(appControllerProvider.notifier)
                                    .clearError
                              : ref
                                    .read(appControllerProvider.notifier)
                                    .clearNotice,
                        ),
                      ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.shopName,
    required this.userName,
    required this.onAction,
  });

  final String title;
  final String shopName;
  final String userName;
  final ValueChanged<_AccountAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              shopName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<_AccountAction>(
            tooltip: '账户菜单',
            onSelected: onAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AccountAction.resetData,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.restart_alt_rounded),
                  title: Text('恢复标准演示数据'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _AccountAction.logout,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded),
                  title: Text('退出登录'),
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.person_rounded,
                      size: 17,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
