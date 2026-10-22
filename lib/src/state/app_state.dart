import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../domain/appearance.dart';
import '../domain/marketing_models.dart';
import '../domain/models.dart';

const _noChange = Object();

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError('AuthRepository 必须在 ProviderScope 中覆盖');
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  throw UnimplementedError('CatalogRepository 必须在 ProviderScope 中覆盖');
});

final appearanceRepositoryProvider = Provider<AppearanceRepository>((ref) {
  throw UnimplementedError('AppearanceRepository 必须在 ProviderScope 中覆盖');
});

final marketingRepositoryProvider = Provider<MarketingRepository>((ref) {
  throw UnimplementedError('MarketingRepository 必须在 ProviderScope 中覆盖');
});

class AppState {
  const AppState({
    this.initialized = false,
    this.busy = false,
    this.session,
    this.catalog,
    this.marketing,
    this.appearance = const AppearanceSettings(),
    this.notice,
    this.error,
  });

  final bool initialized;
  final bool busy;
  final MerchantSession? session;
  final CatalogSnapshot? catalog;
  final MarketingSnapshot? marketing;
  final AppearanceSettings appearance;
  final String? notice;
  final String? error;

  AppState copyWith({
    bool? initialized,
    bool? busy,
    Object? session = _noChange,
    Object? catalog = _noChange,
    Object? marketing = _noChange,
    AppearanceSettings? appearance,
    Object? notice = _noChange,
    Object? error = _noChange,
  }) {
    return AppState(
      initialized: initialized ?? this.initialized,
      busy: busy ?? this.busy,
      session: identical(session, _noChange)
          ? this.session
          : session as MerchantSession?,
      catalog: identical(catalog, _noChange)
          ? this.catalog
          : catalog as CatalogSnapshot?,
      marketing: identical(marketing, _noChange)
          ? this.marketing
          : marketing as MarketingSnapshot?,
      appearance: appearance ?? this.appearance,
      notice: identical(notice, _noChange) ? this.notice : notice as String?,
      error: identical(error, _noChange) ? this.error : error as String?,
    );
  }
}

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  bool _initializationStarted = false;

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  CatalogRepository get _catalog => ref.read(catalogRepositoryProvider);
  MarketingRepository get _marketing => ref.read(marketingRepositoryProvider);
  AppearanceRepository get _appearance =>
      ref.read(appearanceRepositoryProvider);

  @override
  AppState build() {
    ref.onDispose(_catalog.dispose);
    if (!_initializationStarted) {
      _initializationStarted = true;
      scheduleMicrotask(initialize);
    }
    return const AppState();
  }

  Future<void> initialize() async {
    state = state.copyWith(busy: true, error: null);
    try {
      final sessionResult = await _auth.restoreSession();
      final catalogResult = await _catalog.loadCatalog();
      final marketingResult = await _marketing.loadMarketing();
      final appearanceResult = await _appearance.loadAppearance();
      final notices = [
        sessionResult.recoveryNotice,
        catalogResult.recoveryNotice,
        marketingResult.recoveryNotice,
        appearanceResult.recoveryNotice,
      ].whereType<String>().join('\n');
      state = AppState(
        initialized: true,
        session: sessionResult.value,
        catalog: catalogResult.value,
        marketing: marketingResult.value,
        appearance: appearanceResult.value,
        notice: notices.isEmpty ? null : notices,
      );
    } catch (error) {
      state = AppState(
        initialized: true,
        error: '无法初始化本地数据：${_message(error)}',
      );
    }
  }

  Future<bool> login(String userName, String password) async {
    if (state.busy) {
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final session = await _auth.login(userName, password);
      state = state.copyWith(busy: false, session: session, error: null);
      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return false;
    }
  }

  Future<bool> logout() async {
    if (state.busy) {
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      await _auth.logout();
      state = state.copyWith(
        busy: false,
        session: null,
        notice: null,
        error: null,
      );
      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return false;
    }
  }

  Future<Product?> createProduct(ProductDraft draft) async {
    final current = state.catalog;
    if (current == null || state.busy) {
      return null;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final product = await _catalog.createProduct(draft);
      state = state.copyWith(
        busy: false,
        catalog: current.copyWith(products: [...current.products, product]),
        notice: '已新增商品「${product.productName}」',
      );
      return product;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return null;
    }
  }

  Future<Product?> updateProduct(int productId, ProductDraft draft) async {
    final current = state.catalog;
    if (current == null || state.busy) {
      return null;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final product = await _catalog.updateProduct(productId, draft);
      state = state.copyWith(
        busy: false,
        catalog: current.copyWith(
          products: current.products
              .map((item) => item.productId == productId ? product : item)
              .toList(growable: false),
        ),
        notice: '已保存商品「${product.productName}」',
      );
      return product;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return null;
    }
  }

  Future<bool> deleteProduct(Product product) async {
    final current = state.catalog;
    if (current == null || state.busy) {
      return false;
    }
    if (state.marketing?.promotions.any(
          (event) => event.productId == product.productId,
        ) ==
        true) {
      state = state.copyWith(error: '该商品关联了促销，请先在营销工作台处理相关促销。');
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      await _catalog.deleteProduct(product.productId);
      state = state.copyWith(
        busy: false,
        catalog: current.copyWith(
          products: current.products
              .where((item) => item.productId != product.productId)
              .toList(growable: false),
        ),
        notice: '已删除商品「${product.productName}」',
      );
      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return false;
    }
  }

  Future<bool> resetDemoData() async {
    if (state.busy) {
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final catalog = await _catalog.resetDemoData();
      state = state.copyWith(catalog: catalog);
      final marketing = await _marketing.resetDemoData();
      state = state.copyWith(
        busy: false,
        catalog: catalog,
        marketing: marketing,
        notice: '已恢复标准演示数据，登录状态保持不变。',
      );
      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return false;
    }
  }

  Future<PromotionEvent?> savePromotion(
    PromotionDraft draft, {
    int? saleId,
  }) async {
    final current = state.marketing;
    final catalog = state.catalog;
    if (current == null || catalog == null || state.busy) return null;
    state = state.copyWith(busy: true, error: null);
    try {
      final saved = saleId == null
          ? await _marketing.createPromotion(draft, catalog)
          : await _marketing.updatePromotion(saleId, draft, catalog);
      final next = saleId == null
          ? [...current.promotions, saved]
          : current.promotions
                .map((item) => item.saleId == saleId ? saved : item)
                .toList(growable: false);
      state = state.copyWith(
        busy: false,
        marketing: current.copyWith(promotions: next),
        notice: saleId == null ? '已创建本地促销' : '已保存本地促销',
      );
      return saved;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return null;
    }
  }

  Future<bool> deletePromotion(int saleId) async {
    final current = state.marketing;
    if (current == null || state.busy) return false;
    state = state.copyWith(busy: true, error: null);
    try {
      await _marketing.deletePromotion(saleId);
      state = state.copyWith(
        busy: false,
        marketing: current.copyWith(
          promotions: current.promotions
              .where((item) => item.saleId != saleId)
              .toList(),
        ),
        notice: '已删除本地促销',
      );
      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return false;
    }
  }

  Future<Advertisement?> saveAdvertisement(
    AdvertisementDraft draft, {
    int? adId,
  }) async {
    final current = state.marketing;
    if (current == null || state.busy) return null;
    state = state.copyWith(busy: true, error: null);
    try {
      final saved = adId == null
          ? await _marketing.createAdvertisement(draft)
          : await _marketing.updateAdvertisement(adId, draft);
      final next = adId == null
          ? [...current.advertisements, saved]
          : current.advertisements
                .map((item) => item.adId == adId ? saved : item)
                .toList(growable: false);
      state = state.copyWith(
        busy: false,
        marketing: current.copyWith(advertisements: next),
        notice: adId == null ? '已添加本地广告预览' : '已保存本地广告预览',
      );
      return saved;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return null;
    }
  }

  Future<bool> deleteAdvertisement(int adId) async {
    final current = state.marketing;
    if (current == null || state.busy) return false;
    state = state.copyWith(busy: true, error: null);
    try {
      await _marketing.deleteAdvertisement(adId);
      state = state.copyWith(
        busy: false,
        marketing: current.copyWith(
          advertisements: current.advertisements
              .where((item) => item.adId != adId)
              .toList(),
        ),
        notice: '已删除本地广告预览',
      );
      return true;
    } catch (error) {
      state = state.copyWith(busy: false, error: _message(error));
      return false;
    }
  }

  Future<bool> setAppearance(AppearanceSettings appearance) async {
    if (appearance == state.appearance) {
      return true;
    }
    final previous = state.appearance;
    state = state.copyWith(appearance: appearance, error: null);
    try {
      await _appearance.saveAppearance(appearance);
      return true;
    } catch (error) {
      state = state.copyWith(
        appearance: previous,
        error: '无法保存外观设置：${_message(error)}',
      );
      return false;
    }
  }

  void clearNotice() {
    if (state.notice != null) {
      state = state.copyWith(notice: null);
    }
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
}

String _message(Object error) {
  if (error is AuthenticationException) {
    return error.message;
  }
  if (error is CatalogValidationException) {
    return error.errors.values.join('；');
  }
  if (error is MarketingValidationException) {
    return error.errors.values.join('；');
  }
  if (error is FileSystemException) {
    return '无法访问本地数据文件';
  }
  return error.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
}

final unsavedChangesProvider = NotifierProvider<UnsavedChangesController, bool>(
  UnsavedChangesController.new,
);

class UnsavedChangesController extends Notifier<bool> {
  @override
  bool build() => false;

  void setUnsaved(bool value) {
    if (state != value) {
      state = value;
    }
  }
}
