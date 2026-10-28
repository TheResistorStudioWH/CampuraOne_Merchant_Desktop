import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/app_state.dart';
import 'ui/app_shell.dart';
import 'ui/app_theme.dart';
import 'ui/dashboard_screen.dart';
import 'ui/login_screen.dart';
import 'ui/marketing_screen.dart';
import 'ui/products_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen<AppState>(appControllerProvider, (previous, next) {
    refresh.value++;
  });

  return GoRouter(
    initialLocation: '/loading',
    refreshListenable: refresh,
    redirect: (context, routeState) {
      final appState = ref.read(appControllerProvider);
      final path = routeState.uri.path;
      if (!appState.initialized) {
        return path == '/loading' ? null : '/loading';
      }
      if (appState.session == null) {
        return path == '/login' ? null : '/login';
      }
      if (path == '/login' || path == '/loading' || path == '/') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _LoadingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MerchantAppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const ProductRoutePage(),
              ),
              GoRoute(
                path: ':productId',
                builder: (context, state) {
                  final id = int.tryParse(
                    state.pathParameters['productId'] ?? '',
                  );
                  return id == null
                      ? const _RouteErrorScreen(message: '商品 ID 无效')
                      : ProductRoutePage(productId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/marketing',
            builder: (context, state) => const MarketingScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        _RouteErrorScreen(message: '无法打开该页面：${state.error ?? '未知错误'}'),
  );
});

class MerchantApp extends ConsumerWidget {
  const MerchantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appearance = ref.watch(
      appControllerProvider.select((state) => state.appearance),
    );
    return MaterialApp.router(
      title: '域校屿商家',
      debugShowCheckedModeBanner: false,
      themeMode: materialThemeMode(appearance.brightness),
      theme: buildMerchantTheme(Brightness.light, appearance.preset),
      darkTheme: buildMerchantTheme(Brightness.dark, appearance.preset),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class _LoadingScreen extends ConsumerWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '域校屿商家',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (state.error == null) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    '正在准备本地演示数据…',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else ...[
                  Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: ref
                        .read(appControllerProvider.notifier)
                        .initialize,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 52),
            const SizedBox(height: 16),
            Text(message),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('返回总览'),
            ),
          ],
        ),
      ),
    );
  }
}
