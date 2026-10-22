import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import 'appearance_dialog.dart';
import 'common.dart';
import 'workspace_resize_handle.dart';

enum _AccountAction { resetData, logout }

class MerchantAppShell extends ConsumerStatefulWidget {
  const MerchantAppShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MerchantAppShell> createState() => _MerchantAppShellState();
}

class _MerchantAppShellState extends ConsumerState<MerchantAppShell> {
  double? _dragSidebarWidth;

  double _sidebarWidth(double viewportWidth, double? preferredWidth) {
    final maxExpanded = (viewportWidth - 600).clamp(0.0, 360.0);
    final preferred = preferredWidth ?? (viewportWidth < 960 ? 76.0 : 224.0);
    if (maxExpanded < 180 || preferred < 140) {
      return 76;
    }
    return preferred.clamp(180.0, maxExpanded);
  }

  void _updateSidebarWidth(double delta, double viewportWidth) {
    final savedWidth = ref.read(appControllerProvider).appearance.sidebarWidth;
    setState(() {
      _dragSidebarWidth =
          (_dragSidebarWidth ?? _sidebarWidth(viewportWidth, savedWidth)) +
          delta;
    });
  }

  Future<void> _finishSidebarResize(double viewportWidth) async {
    final draggedWidth = _dragSidebarWidth;
    if (draggedWidth == null) {
      return;
    }
    final settings = ref.read(appControllerProvider).appearance;
    final width = _sidebarWidth(viewportWidth, draggedWidth);
    final save = ref
        .read(appControllerProvider.notifier)
        .setAppearance(settings.copyWith(sidebarWidth: width));
    setState(() => _dragSidebarWidth = null);
    await save;
  }

  void _cancelSidebarResize() {
    setState(() => _dragSidebarWidth = null);
  }

  Future<void> _resetSidebarWidth() async {
    final settings = ref.read(appControllerProvider).appearance;
    setState(() => _dragSidebarWidth = null);
    await ref
        .read(appControllerProvider.notifier)
        .setAppearance(settings.copyWith(sidebarWidth: null));
  }

  Future<bool> _confirmUnsaved(BuildContext context) async {
    if (!ref.read(unsavedChangesProvider)) {
      return true;
    }
    final discard = await confirmDiscardChanges(context);
    if (discard) {
      ref.read(unsavedChangesProvider.notifier).setUnsaved(false);
    }
    return discard;
  }

  Future<void> _navigate(BuildContext context, String location) async {
    if (GoRouterState.of(context).uri.path == location) {
      return;
    }
    if (await _confirmUnsaved(context) && context.mounted) {
      context.go(location);
    }
  }

  Future<void> _handleAccountAction(
    BuildContext context,
    _AccountAction action,
  ) async {
    if (!await _confirmUnsaved(context) || !context.mounted) {
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
            content: const Text('本地商品、促销和广告预览都会恢复到初始状态。当前登录状态不受影响。'),
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
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final path = GoRouterState.of(context).uri.path;
    final productsSelected = path.startsWith('/products');
    final marketingSelected = path.startsWith('/marketing');
    final catalog = appState.catalog;
    final shopName = catalog?.mainShops.isNotEmpty == true
        ? catalog!.mainShops.first.shopName
        : '演示商户';
    final managedMainShopIds = appState.session?.shopIds.toSet() ?? <int>{};
    final managedSubShopCount =
        catalog?.subShops
            .where(
              (shop) =>
                  managedMainShopIds.isEmpty ||
                  managedMainShopIds.contains(shop.mainShopId),
            )
            .length ??
        0;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidebarWidth = _sidebarWidth(
            constraints.maxWidth,
            _dragSidebarWidth ?? appState.appearance.sidebarWidth,
          );
          final compact = sidebarWidth < 140;
          return Row(
            children: [
              _WorkspaceSidebar(
                width: sidebarWidth,
                compact: compact,
                productsSelected: productsSelected,
                marketingSelected: marketingSelected,
                shopName: shopName,
                userName: appState.session?.userName ?? '',
                managedSubShopCount: managedSubShopCount,
                onNavigate: (location) => _navigate(context, location),
                onAccountAction: (action) =>
                    _handleAccountAction(context, action),
              ),
              WorkspaceResizeHandle(
                key: const Key('sidebar-resize-handle'),
                tooltip: '拖动调整侧栏宽度，双击恢复自动宽度',
                onDrag: (delta) =>
                    _updateSidebarWidth(delta, constraints.maxWidth),
                onDragEnd: () => _finishSidebarResize(constraints.maxWidth),
                onDragCancel: _cancelSidebarResize,
                onDoubleTap: _resetSidebarWidth,
              ),
              Expanded(
                child: Column(
                  children: [
                    _ContentHeader(
                      title: marketingSelected
                          ? '营销'
                          : productsSelected
                          ? '商品'
                          : '总览',
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
                    Expanded(child: widget.child),
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

class _WorkspaceSidebar extends ConsumerWidget {
  const _WorkspaceSidebar({
    required this.width,
    required this.compact,
    required this.productsSelected,
    required this.marketingSelected,
    required this.shopName,
    required this.userName,
    required this.managedSubShopCount,
    required this.onNavigate,
    required this.onAccountAction,
  });

  final double width;
  final bool compact;
  final bool productsSelected;
  final bool marketingSelected;
  final String shopName;
  final String userName;
  final int managedSubShopCount;
  final ValueChanged<String> onNavigate;
  final ValueChanged<_AccountAction> onAccountAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final preset = ref.watch(
      appControllerProvider.select((state) => state.appearance.preset),
    );
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        key: const Key('workspace-sidebar'),
        width: width,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 86,
                child: Align(
                  alignment: compact ? Alignment.center : Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: compact ? 0 : 6),
                    child: compact
                        ? const BrandMark(compact: true)
                        : Row(
                            children: [
                              const BrandMark(compact: true),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Campura One',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      '工作区',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              // if (!compact)
              //   Padding(
              //     padding: const EdgeInsets.fromLTRB(14, 13, 0, 9),
              //     child: Text(
              //       '工作区',
              //       style: Theme.of(context).textTheme.labelSmall?.copyWith(
              //         color: scheme.onSurfaceVariant,
              //         letterSpacing: 0.6,
              //       ),
              //     ),
              //   )
              // else
              //   const SizedBox(height: 12),
              _SidebarItem(
                compact: compact,
                label: '总览',
                icon: const Icon(Icons.space_dashboard_outlined),
                selectedIcon: const Icon(Icons.space_dashboard_rounded),
                selected: !productsSelected && !marketingSelected,
                onTap: () => onNavigate('/dashboard'),
              ),
              const SizedBox(height: 4),
              _SidebarItem(
                compact: compact,
                label: '商品',
                icon: const Icon(Icons.inventory_2_outlined),
                selectedIcon: const Icon(Icons.inventory_2_rounded),
                selected: productsSelected,
                onTap: () => onNavigate('/products'),
              ),
              const SizedBox(height: 4),
              _SidebarItem(
                compact: compact,
                label: '营销',
                icon: const Icon(Icons.campaign_outlined),
                selectedIcon: const Icon(Icons.campaign_rounded),
                selected: marketingSelected,
                onTap: () => onNavigate('/marketing'),
              ),
              const Spacer(),
              Divider(
                height: 1,
                indent: compact ? 4 : 10,
                endIndent: compact ? 4 : 10,
              ),
              const SizedBox(height: 10),
              _SidebarItem(
                key: const Key('sidebar-appearance'),
                compact: compact,
                label: '外观与主题',
                icon: ThemePaletteIcon(preset: preset, compact: true),
                onTap: () => showAppearanceDialog(context),
              ),
              const SizedBox(height: 8),
              PopupMenuButton<_AccountAction>(
                key: const Key('sidebar-account'),
                tooltip: '账户菜单',
                onSelected: onAccountAction,
                constraints: const BoxConstraints(minWidth: 240, maxWidth: 280),
                itemBuilder: (context) => [
                  PopupMenuItem<_AccountAction>(
                    enabled: false,
                    height: 74,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '主商户账号 · 管理 $managedSubShopCount 个子商户',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _AccountAction.resetData,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.restart_alt_rounded),
                      title: Text('恢复标准演示数据'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _AccountAction.logout,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout_rounded),
                      title: Text('退出登录'),
                    ),
                  ),
                ],
                child: Ink(
                  height: 60,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: compact
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                '主商户管理员',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.unfold_more_rounded, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.compact,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selectedIcon,
    this.selected = false,
    super.key,
  });

  final bool compact;
  final String label;
  final Widget icon;
  final Widget? selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    final item = Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (!compact) const SizedBox(width: 14),
              IconTheme(
                data: IconThemeData(color: foreground, size: 22),
                child: selected ? selectedIcon ?? icon : icon,
              ),
              if (!compact) ...[
                const SizedBox(width: 13),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? foreground : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: compact ? Tooltip(message: label, child: item) : item,
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({required this.title});

  final String title;

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
        ],
      ),
    );
  }
}
