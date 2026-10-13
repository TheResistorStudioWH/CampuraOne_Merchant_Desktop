import 'dart:io';

import 'package:campura_one_merchant/src/app.dart';
import 'package:campura_one_merchant/src/data/repositories.dart';
import 'package:campura_one_merchant/src/domain/appearance.dart';
import 'package:campura_one_merchant/src/domain/models.dart';
import 'package:campura_one_merchant/src/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int attempts = 100,
  }) async {
    for (var index = 0; index < attempts; index++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    fail('等待界面元素超时：$finder');
  }

  Future<void> pumpMerchantApp(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    _MemoryAppearanceRepository? appearance,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final seed = CatalogSnapshot.fromJsonString(
      File('assets/demo/catalog_seed.json').readAsStringSync(),
    );
    final auth = _MemoryAuthRepository();
    final catalog = _MemoryCatalogRepository(seed);
    final appearanceRepository = appearance ?? _MemoryAppearanceRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          catalogRepositoryProvider.overrideWithValue(catalog),
          appearanceRepositoryProvider.overrideWithValue(appearanceRepository),
        ],
        child: const MerchantApp(),
      ),
    );
    await pumpUntilFound(tester, find.text('欢迎回来'));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  Future<void> login(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('fill-demo-account')));
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntilFound(tester, find.text('经营概览'));
  }

  testWidgets('新安装显示登录，校验后可用演示账号进入总览', (tester) async {
    await pumpMerchantApp(tester);

    expect(find.text('欢迎回来'), findsOneWidget);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('请输入商家账号'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);

    await login(tester);
    expect(find.text('经营概览'), findsOneWidget);
    expect(find.text('商品总数'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('外观面板可切换 Material 3 主题和深浅模式', (tester) async {
    final appearance = _MemoryAppearanceRepository();
    await pumpMerchantApp(tester, appearance: appearance);
    final initialTheme = Theme.of(tester.element(find.text('欢迎回来')));

    await tester.tap(find.byKey(const Key('appearance-open')));
    await pumpUntilFound(tester, find.text('外观与主题'));
    await tester.tap(find.byKey(const Key('appearance-preset-lagoon')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(appearance.settings.preset, MerchantThemePreset.lagoon);
    final lagoonTheme = Theme.of(tester.element(find.text('外观与主题')));
    expect(
      lagoonTheme.colorScheme.primary,
      isNot(initialTheme.colorScheme.primary),
    );

    await tester.tap(find.text('深色'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(appearance.settings.brightness, AppearanceBrightness.dark);
    expect(
      Theme.of(tester.element(find.text('外观与主题'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('搜索、新增、编辑与删除商品', (tester) async {
    await pumpMerchantApp(tester);
    await login(tester);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await pumpUntilFound(tester, find.byKey(const Key('product-search')));

    await tester.enterText(find.byKey(const Key('product-search')), '烤肠');
    await tester.pump();
    expect(find.text('测试烤肠'), findsWidgets);
    expect(find.text('冰美式'), findsNothing);
    await tester.enterText(find.byKey(const Key('product-search')), '');
    await tester.pump();

    await tester.tap(find.byKey(const Key('product-add')));
    await pumpUntilFound(tester, find.byKey(const Key('product-save')));
    await tester.enterText(find.byKey(const Key('product-name')), '评委演示奶茶');
    await tester.enterText(find.byKey(const Key('product-price')), '15.80');
    await tester.tap(find.byKey(const Key('product-save')));
    await pumpUntilFound(tester, find.byKey(const Key('product-edit')));
    expect(find.text('评委演示奶茶'), findsWidgets);

    await tester.tap(find.byKey(const Key('product-edit')));
    await pumpUntilFound(tester, find.byKey(const Key('product-save')));
    await tester.enterText(find.byKey(const Key('product-name')), '评委演示果茶');
    await tester.tap(find.byKey(const Key('product-save')));
    await pumpUntilFound(tester, find.byKey(const Key('product-edit')));
    expect(find.text('评委演示果茶'), findsWidgets);

    await tester.tap(find.byTooltip('删除商品'));
    await pumpUntilFound(tester, find.widgetWithText(FilledButton, '删除'));
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('评委演示果茶'), findsNothing);
  });

  testWidgets('未保存修改会阻止离开商品页', (tester) async {
    await pumpMerchantApp(tester);
    await login(tester);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await pumpUntilFound(tester, find.byKey(const Key('product-search')));
    await tester.tap(find.byKey(const Key('product-add')));
    await pumpUntilFound(tester, find.byKey(const Key('product-save')));
    await tester.enterText(find.byKey(const Key('product-name')), '未保存商品');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.space_dashboard_outlined).first);
    await pumpUntilFound(tester, find.text('放弃未保存的修改？'));
    expect(find.text('放弃未保存的修改？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '继续编辑'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('product-save')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.space_dashboard_outlined).first);
    await pumpUntilFound(tester, find.text('放弃未保存的修改？'));
    await tester.tap(find.widgetWithText(FilledButton, '放弃修改'));
    await pumpUntilFound(tester, find.text('经营概览'));
    expect(find.text('经营概览'), findsOneWidget);
  });

  testWidgets('窄窗口中商品详情使用独立页面', (tester) async {
    await pumpMerchantApp(tester, size: const Size(800, 700));
    await login(tester);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await pumpUntilFound(tester, find.byKey(const Key('product-search')));
    await tester.tap(find.byKey(const Key('product-item-3')));
    await pumpUntilFound(tester, find.text('商品详情'));

    expect(find.text('商品详情'), findsOneWidget);
    expect(find.text('冰美式'), findsWidgets);
    expect(find.byTooltip('返回商品列表 (Esc)'), findsOneWidget);
  });
}

class _MemoryAuthRepository implements AuthRepository {
  MerchantSession? _session;

  @override
  Future<RepositoryLoad<MerchantSession?>> restoreSession() async {
    return RepositoryLoad(_session);
  }

  @override
  Future<MerchantSession> login(String userName, String password) async {
    if (userName != demoMerchantUserName || password != demoMerchantPassword) {
      throw const AuthenticationException('账号或密码不正确');
    }
    return _session = MerchantSession(
      userId: 1,
      userName: userName,
      shopIds: const [1],
      subShopIds: const [1],
      signedInAt: DateTime(2026, 10, 11),
    );
  }

  @override
  Future<void> logout() async {
    _session = null;
  }
}

class _MemoryAppearanceRepository implements AppearanceRepository {
  AppearanceSettings settings = const AppearanceSettings();

  @override
  Future<RepositoryLoad<AppearanceSettings>> loadAppearance() async {
    return RepositoryLoad(settings);
  }

  @override
  Future<void> saveAppearance(AppearanceSettings settings) async {
    this.settings = settings;
  }
}

class _MemoryCatalogRepository implements CatalogRepository {
  _MemoryCatalogRepository(this._initial) : _snapshot = _initial;

  final CatalogSnapshot _initial;
  CatalogSnapshot _snapshot;

  @override
  Future<RepositoryLoad<CatalogSnapshot>> loadCatalog() async {
    return RepositoryLoad(_snapshot);
  }

  @override
  Stream<List<Product>> watchProducts() async* {
    yield _snapshot.products;
  }

  @override
  Future<List<MainShop>> readMainShops() async => _snapshot.mainShops;

  @override
  Future<List<SubShop>> readSubShops() async => _snapshot.subShops;

  @override
  Future<List<ProductCategory>> readCategories() async => _snapshot.categories;

  @override
  Future<Product> createProduct(ProductDraft draft) async {
    final id =
        _snapshot.products.fold<int>(
          0,
          (highest, product) =>
              product.productId > highest ? product.productId : highest,
        ) +
        1;
    final now = DateTime(2026, 10, 11, 12, id);
    final product = draft.toProduct(
      productId: id,
      createdAt: now,
      updatedAt: now,
    );
    _snapshot = _snapshot.copyWith(products: [..._snapshot.products, product]);
    return product;
  }

  @override
  Future<Product> updateProduct(int productId, ProductDraft draft) async {
    final existing = _snapshot.productById(productId)!;
    final product = draft.toProduct(
      productId: productId,
      createdAt: existing.createdAt,
      updatedAt: DateTime(2026, 10, 11, 13),
    );
    _snapshot = _snapshot.copyWith(
      products: _snapshot.products
          .map((item) => item.productId == productId ? product : item)
          .toList(growable: false),
    );
    return product;
  }

  @override
  Future<void> deleteProduct(int productId) async {
    _snapshot = _snapshot.copyWith(
      products: _snapshot.products
          .where((item) => item.productId != productId)
          .toList(growable: false),
    );
  }

  @override
  Future<CatalogSnapshot> resetDemoData() async {
    _snapshot = _initial;
    return _snapshot;
  }

  @override
  void dispose() {}
}
