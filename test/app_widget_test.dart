import 'dart:io';

import 'package:campura_one_merchant/src/app.dart';
import 'package:campura_one_merchant/src/data/repositories.dart';
import 'package:campura_one_merchant/src/domain/appearance.dart';
import 'package:campura_one_merchant/src/domain/marketing_models.dart';
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
    final marketing = _MemoryMarketingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          catalogRepositoryProvider.overrideWithValue(catalog),
          appearanceRepositoryProvider.overrideWithValue(appearanceRepository),
          marketingRepositoryProvider.overrideWithValue(marketing),
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
    expect(find.text('商户账户'), findsNothing);
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

  testWidgets('工作区侧栏把账户和主题留在左下角，右侧仅显示内容', (tester) async {
    await pumpMerchantApp(tester);
    await login(tester);

    final account = find.byKey(const Key('sidebar-account'));
    expect(account, findsOneWidget);
    expect(tester.getTopLeft(account).dx, lessThan(240));
    expect(tester.getTopLeft(account).dy, greaterThan(650));
    expect(find.byKey(const Key('topbar-appearance')), findsNothing);

    await tester.tap(find.byKey(const Key('sidebar-appearance')));
    await pumpUntilFound(tester, find.text('外观与主题'));
    await tester.tap(find.byTooltip('关闭'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(account);
    await tester.pumpAndSettle();
    expect(find.text('商户账户'), findsOneWidget);
    expect(find.byKey(const Key('main-shop-scope-1')), findsOneWidget);
    expect(find.byKey(const Key('sub-shop-scope-1')), findsOneWidget);
    expect(find.text('独立账号 · 主商户可代管商品'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    await tester.tap(find.text('恢复标准演示数据'));
    await pumpUntilFound(tester, find.text('恢复标准演示数据？'));
    await tester.tap(find.widgetWithText(FilledButton, '恢复数据'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('经营概览'), findsOneWidget);

    await tester.tap(account);
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出登录'));
    await pumpUntilFound(tester, find.text('欢迎回来'));
  });

  testWidgets('侧栏可拖动、记忆宽度并双击恢复自动布局', (tester) async {
    final appearance = _MemoryAppearanceRepository();
    await pumpMerchantApp(tester, appearance: appearance);
    await login(tester);

    final sidebar = find.byKey(const Key('workspace-sidebar'));
    final handle = find.byKey(const Key('sidebar-resize-handle'));
    expect(tester.getSize(sidebar).width, 224);

    await tester.drag(handle, const Offset(90, 0));
    await tester.pumpAndSettle();
    final expandedWidth = tester.getSize(sidebar).width;
    expect(expandedWidth, greaterThan(280));
    expect(appearance.settings.sidebarWidth, expandedWidth);

    await tester.tap(find.byKey(const Key('sidebar-appearance')));
    await pumpUntilFound(tester, find.text('外观与主题'));
    await tester.tap(find.byKey(const Key('appearance-preset-lagoon')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(appearance.settings.sidebarWidth, expandedWidth);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(handle);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(appearance.settings.sidebarWidth, isNull);
    expect(tester.getSize(sidebar).width, 224);

    await tester.drag(handle, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 76);
    expect(appearance.settings.sidebarWidth, 76);
    expect(find.text('工作区'), findsNothing);
  });

  testWidgets('商品和营销的列表分栏可分别调整并记住宽度', (tester) async {
    final appearance = _MemoryAppearanceRepository();
    await pumpMerchantApp(tester, appearance: appearance);
    await login(tester);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await pumpUntilFound(tester, find.byKey(const Key('product-list-pane')));
    final productPane = find.byKey(const Key('product-list-pane'));
    final productHandle = find.byKey(const Key('product-resize-handle'));
    expect(tester.getSize(productPane).width, 420);
    await tester.drag(productHandle, const Offset(80, 0));
    await tester.pumpAndSettle();
    final productWidth = tester.getSize(productPane).width;
    expect(productWidth, greaterThan(470));
    expect(appearance.settings.productListWidth, productWidth);

    await tester.tap(find.byIcon(Icons.campaign_outlined).first);
    await pumpUntilFound(tester, find.byKey(const Key('promotion-list-pane')));
    final promotionPane = find.byKey(const Key('promotion-list-pane'));
    final promotionHandle = find.byKey(const Key('promotion-resize-handle'));
    expect(tester.getSize(promotionPane).width, 320);
    await tester.drag(promotionHandle, const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(promotionPane).width, greaterThan(370));
    expect(appearance.settings.productListWidth, productWidth);
    expect(
      appearance.settings.promotionListWidth,
      tester.getSize(promotionPane).width,
    );

    await tester.tap(promotionHandle);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(promotionHandle);
    await tester.pumpAndSettle();
    expect(appearance.settings.promotionListWidth, isNull);
    expect(tester.getSize(promotionPane).width, 320);
  });

  testWidgets('搜索、新增、编辑与删除商品', (tester) async {
    await pumpMerchantApp(tester);
    await login(tester);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await pumpUntilFound(tester, find.byKey(const Key('product-search')));
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

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

  testWidgets('主商户可按层级筛选子商户商品，编辑器显示向下代管关系', (tester) async {
    await pumpMerchantApp(tester);
    await login(tester);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await pumpUntilFound(tester, find.byKey(const Key('product-scope-filter')));

    await tester.tap(find.byKey(const Key('product-scope-filter')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-scope-main-1')), findsOneWidget);
    expect(find.byKey(const Key('product-scope-sub-1')), findsOneWidget);
    expect(find.text('子商户独立账号 · 主商户可代管'), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-scope-sub-1')));
    await tester.pumpAndSettle();
    expect(find.text('测试烤肠'), findsWidgets);
    expect(find.text('芝士火腿三明治'), findsWidgets);
    expect(find.text('冰美式'), findsNothing);

    await tester.tap(find.byKey(const Key('product-add')));
    await pumpUntilFound(tester, find.byKey(const Key('product-ownership')));
    expect(find.textContaining('当前主账号具有向下代管权限'), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-ownership')));
    await tester.pumpAndSettle();
    expect(find.text('主商户直营 · 当前主账号'), findsWidgets);
    expect(find.text('子商户独立账号 · 主商户可代管'), findsWidgets);
    await tester.tap(find.text('测试咖啡子商户').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-name')), '子商户代管新品');
    await tester.enterText(find.byKey(const Key('product-price')), '9.90');
    await tester.tap(find.byKey(const Key('product-save')));
    await pumpUntilFound(tester, find.text('主商户代管 · 测试咖啡子商户'));
    expect(find.text('子商户代管新品'), findsWidgets);
  });

  testWidgets('营销先创建促销，再添加关联广告并按依赖顺序删除', (tester) async {
    await pumpMerchantApp(tester);
    await login(tester);
    await tester.tap(find.byIcon(Icons.campaign_outlined).first);
    await pumpUntilFound(tester, find.text('营销工作台'));
    expect(find.byKey(const Key('marketing-add-ad')), findsNothing);

    await tester.tap(find.byKey(const Key('marketing-add-promotion')));
    await pumpUntilFound(tester, find.byKey(const Key('promotion-save')));
    await tester.enterText(
      find.byKey(const Key('promotion-rule')),
      '早餐组合立减 3 元',
    );
    await tester.tap(find.byKey(const Key('promotion-save')));
    await pumpUntilFound(tester, find.byKey(const Key('promotion-item-1')));
    expect(find.byKey(const Key('marketing-add-ad')), findsOneWidget);

    await tester.tap(find.byKey(const Key('marketing-add-ad')));
    await pumpUntilFound(tester, find.byKey(const Key('ad-save')));
    await tester.tap(find.byKey(const Key('ad-save')));
    await pumpUntilFound(tester, find.byKey(const Key('advertisement-item-1')));

    await tester.tap(find.widgetWithText(TextButton, '删除促销'));
    await tester.pump();
    expect(find.text('请先删除这条促销下的广告，再删除促销。'), findsOneWidget);
    await tester.tap(find.byTooltip('删除广告'));
    await pumpUntilFound(tester, find.text('删除广告预览？'));
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('advertisement-item-1')), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '删除促销'));
    await pumpUntilFound(tester, find.text('删除促销事件？'));
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('从一条促销开始'), findsOneWidget);
  });

  testWidgets('窄窗口营销页和横幅广告编辑器可用', (tester) async {
    await pumpMerchantApp(tester, size: const Size(800, 700));
    await login(tester);
    await tester.tap(find.byIcon(Icons.campaign_outlined).first);
    await pumpUntilFound(tester, find.text('营销工作台'));
    await tester.tap(find.byKey(const Key('marketing-add-promotion')));
    await pumpUntilFound(tester, find.byKey(const Key('promotion-rule')));
    await tester.enterText(find.byKey(const Key('promotion-rule')), '早餐时段优惠');
    await tester.tap(find.byKey(const Key('promotion-save')));
    await pumpUntilFound(tester, find.byKey(const Key('promotion-item-1')));
    await tester.ensureVisible(find.byKey(const Key('marketing-add-ad')));
    await tester.tap(find.byKey(const Key('marketing-add-ad')));
    await pumpUntilFound(tester, find.byKey(const Key('ad-type')));
    await tester.tap(find.text('横幅 3:1'));
    await tester.pump();
    expect(
      find.byKey(const Key('ad-image-02-breakfast-L.png')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ad-save')));
    await pumpUntilFound(tester, find.byKey(const Key('advertisement-item-1')));
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
    final account = find.byKey(const Key('sidebar-account'));
    expect(tester.getTopLeft(account).dx, lessThan(76));
    expect(tester.getTopLeft(account).dy, greaterThan(550));
    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await pumpUntilFound(tester, find.byKey(const Key('product-search')));
    await tester.tap(find.byKey(const Key('product-item-3')));
    await pumpUntilFound(tester, find.text('商品详情'));

    expect(find.text('商品详情'), findsOneWidget);
    expect(find.text('冰美式'), findsWidgets);
    expect(find.byTooltip('返回商品列表 (Esc)'), findsOneWidget);

    await tester.tap(account);
    await tester.pumpAndSettle();
    final logout = find.text('退出登录');
    expect(logout, findsOneWidget);
    expect(tester.getTopLeft(logout).dx, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(logout).dy, lessThanOrEqualTo(700));
  });

  testWidgets('1024×700 窗口保留完整侧栏并让商品内容自适应', (tester) async {
    await pumpMerchantApp(tester, size: const Size(1024, 700));
    await login(tester);
    expect(find.text('工作区'), findsOneWidget);
    expect(find.text('主商户管理员'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined).first);
    await pumpUntilFound(tester, find.byKey(const Key('product-search')));
    expect(find.text('商品'), findsWidgets);
    expect(find.byKey(const Key('sidebar-account')), findsOneWidget);
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

class _MemoryMarketingRepository implements MarketingRepository {
  MarketingSnapshot snapshot = const MarketingSnapshot();

  @override
  Future<RepositoryLoad<MarketingSnapshot>> loadMarketing() async =>
      RepositoryLoad(snapshot);

  @override
  Future<PromotionEvent> createPromotion(
    PromotionDraft draft,
    CatalogSnapshot catalog,
  ) async {
    final id = snapshot.promotions.length + 1;
    final now = DateTime(2026, 10, 20, 12);
    final event = draft.toEvent(id, now, now);
    snapshot = snapshot.copyWith(promotions: [...snapshot.promotions, event]);
    return event;
  }

  @override
  Future<PromotionEvent> updatePromotion(
    int saleId,
    PromotionDraft draft,
    CatalogSnapshot catalog,
  ) async {
    final existing = snapshot.promotionById(saleId)!;
    final event = draft.toEvent(
      saleId,
      existing.createdAt,
      DateTime(2026, 10, 20, 13),
    );
    snapshot = snapshot.copyWith(
      promotions: snapshot.promotions
          .map((item) => item.saleId == saleId ? event : item)
          .toList(),
    );
    return event;
  }

  @override
  Future<void> deletePromotion(int saleId) async {
    snapshot = snapshot.copyWith(
      promotions: snapshot.promotions
          .where((item) => item.saleId != saleId)
          .toList(),
    );
  }

  @override
  Future<Advertisement> createAdvertisement(AdvertisementDraft draft) async {
    final id = snapshot.advertisements.length + 1;
    final now = DateTime(2026, 10, 20, 12);
    final ad = draft.toAdvertisement(id, now, now);
    snapshot = snapshot.copyWith(
      advertisements: [...snapshot.advertisements, ad],
    );
    return ad;
  }

  @override
  Future<Advertisement> updateAdvertisement(
    int adId,
    AdvertisementDraft draft,
  ) async {
    final existing = snapshot.advertisements.firstWhere(
      (item) => item.adId == adId,
    );
    final ad = draft.toAdvertisement(
      adId,
      existing.createdAt,
      DateTime(2026, 10, 20, 13),
    );
    snapshot = snapshot.copyWith(
      advertisements: snapshot.advertisements
          .map((item) => item.adId == adId ? ad : item)
          .toList(),
    );
    return ad;
  }

  @override
  Future<void> deleteAdvertisement(int adId) async {
    snapshot = snapshot.copyWith(
      advertisements: snapshot.advertisements
          .where((item) => item.adId != adId)
          .toList(),
    );
  }

  @override
  Future<MarketingSnapshot> resetDemoData() async =>
      snapshot = const MarketingSnapshot();
}
