import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/appearance.dart';
import '../domain/marketing_models.dart';
import '../domain/models.dart';

const demoMerchantUserName = 'demo_merchant';
const demoMerchantPassword = 'CampuraDemo!2026';

class RepositoryLoad<T> {
  const RepositoryLoad(this.value, {this.recoveryNotice});

  final T value;
  final String? recoveryNotice;
}

class AuthenticationException implements Exception {
  const AuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CatalogValidationException implements Exception {
  const CatalogValidationException(this.errors);

  final Map<String, String> errors;

  @override
  String toString() => errors.values.join('；');
}

class MarketingValidationException implements Exception {
  const MarketingValidationException(this.errors);

  final Map<String, String> errors;

  @override
  String toString() => errors.values.join('；');
}

abstract interface class AuthRepository {
  Future<RepositoryLoad<MerchantSession?>> restoreSession();

  Future<MerchantSession> login(String userName, String password);

  Future<void> logout();
}

abstract interface class CatalogRepository {
  Future<RepositoryLoad<CatalogSnapshot>> loadCatalog();

  Stream<List<Product>> watchProducts();

  Future<List<MainShop>> readMainShops();

  Future<List<SubShop>> readSubShops();

  Future<List<ProductCategory>> readCategories();

  Future<Product> createProduct(ProductDraft draft);

  Future<Product> updateProduct(int productId, ProductDraft draft);

  Future<void> deleteProduct(int productId);

  Future<CatalogSnapshot> resetDemoData();

  void dispose();
}

abstract interface class AppearanceRepository {
  Future<RepositoryLoad<AppearanceSettings>> loadAppearance();

  Future<void> saveAppearance(AppearanceSettings settings);
}

abstract interface class MarketingRepository {
  Future<RepositoryLoad<MarketingSnapshot>> loadMarketing();

  Future<PromotionEvent> createPromotion(
    PromotionDraft draft,
    CatalogSnapshot catalog,
  );

  Future<PromotionEvent> updatePromotion(
    int saleId,
    PromotionDraft draft,
    CatalogSnapshot catalog,
  );

  Future<void> deletePromotion(int saleId);

  Future<Advertisement> createAdvertisement(AdvertisementDraft draft);

  Future<Advertisement> updateAdvertisement(int adId, AdvertisementDraft draft);

  Future<void> deleteAdvertisement(int adId);

  Future<MarketingSnapshot> resetDemoData();
}

typedef AtomicCommitHook = FutureOr<void> Function(
  File temporaryFile,
  File? backupFile,
);

/// 先写临时文件，再用备份保护原文件，适配 Windows 不能直接
/// 覆盖 rename 目标的行为。
class AtomicJsonWriter {
  const AtomicJsonWriter({this.beforeCommit});

  final AtomicCommitHook? beforeCommit;

  Future<void> write(File target, Object value) async {
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.backup');

    if (await temporary.exists()) {
      await temporary.delete();
    }
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(value),
      flush: true,
    );

    File? activeBackup;
    var committed = false;
    try {
      if (await backup.exists()) {
        await backup.delete();
      }
      if (await target.exists()) {
        activeBackup = await target.rename(backup.path);
      }
      await beforeCommit?.call(temporary, activeBackup);
      await temporary.rename(target.path);
      committed = true;
    } catch (_) {
      if (await target.exists()) {
        await target.delete();
      }
      if (activeBackup != null && await activeBackup.exists()) {
        await activeBackup.rename(target.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }

    if (committed && activeBackup != null && await activeBackup.exists()) {
      try {
        await activeBackup.delete();
      } on FileSystemException {
        // 新文件已经安全落盘，遗留备份不应把成功操作报成失败。
      }
    }
  }
}

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({
    required Directory supportDirectory,
    this.writer = const AtomicJsonWriter(),
  }) : _sessionFile = File(
         '${supportDirectory.path}${Platform.pathSeparator}session_v1.json',
       );

  final File _sessionFile;
  final AtomicJsonWriter writer;

  File get sessionFile => _sessionFile;

  @override
  Future<RepositoryLoad<MerchantSession?>> restoreSession() async {
    if (!await _sessionFile.exists()) {
      return const RepositoryLoad(null);
    }
    final source = await _sessionFile.readAsString();
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const FormatException('会话文件根节点必须是对象');
      }
      return RepositoryLoad(
        MerchantSession.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } catch (_) {
      final preserved = await _quarantine(_sessionFile);
      return RepositoryLoad(
        null,
        recoveryNotice: '已保留损坏的会话文件（${preserved.uri.pathSegments.last}），请重新登录。',
      );
    }
  }

  @override
  Future<MerchantSession> login(String userName, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (userName.trim() != demoMerchantUserName ||
        password != demoMerchantPassword) {
      throw const AuthenticationException('账号或密码不正确，可使用页面上的演示账号。');
    }
    final session = MerchantSession(
      userId: 1,
      userName: demoMerchantUserName,
      shopIds: const [1],
      subShopIds: const [1],
      signedInAt: DateTime.now(),
    );
    await writer.write(_sessionFile, session.toJson());
    return session;
  }

  @override
  Future<void> logout() async {
    if (await _sessionFile.exists()) {
      await _sessionFile.delete();
    }
  }
}

class LocalAppearanceRepository implements AppearanceRepository {
  LocalAppearanceRepository({
    required Directory supportDirectory,
    this.writer = const AtomicJsonWriter(),
  }) : _appearanceFile = File(
         '${supportDirectory.path}${Platform.pathSeparator}appearance_v1.json',
       );

  final File _appearanceFile;
  final AtomicJsonWriter writer;

  File get appearanceFile => _appearanceFile;

  @override
  Future<RepositoryLoad<AppearanceSettings>> loadAppearance() async {
    if (!await _appearanceFile.exists()) {
      return const RepositoryLoad(AppearanceSettings());
    }
    final source = await _appearanceFile.readAsString();
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const FormatException('外观设置根节点必须是对象');
      }
      return RepositoryLoad(
        AppearanceSettings.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } catch (_) {
      final preserved = await _quarantine(_appearanceFile);
      return RepositoryLoad(
        const AppearanceSettings(),
        recoveryNotice: '外观设置已恢复默认值；已保留副本 ${preserved.uri.pathSegments.last}。',
      );
    }
  }

  @override
  Future<void> saveAppearance(AppearanceSettings settings) {
    return writer.write(_appearanceFile, settings.toJson());
  }
}

class LocalCatalogRepository implements CatalogRepository {
  LocalCatalogRepository({
    required Directory supportDirectory,
    required this.seedLoader,
    this.writer = const AtomicJsonWriter(),
  }) : _catalogFile = File(
         '${supportDirectory.path}${Platform.pathSeparator}catalog_v1.json',
       );

  final File _catalogFile;
  final Future<String> Function() seedLoader;
  final AtomicJsonWriter writer;
  final StreamController<List<Product>> _productsController =
      StreamController<List<Product>>.broadcast();

  CatalogSnapshot? _snapshot;

  File get catalogFile => _catalogFile;

  @override
  Future<RepositoryLoad<CatalogSnapshot>> loadCatalog() async {
    if (_snapshot != null) {
      return RepositoryLoad(_snapshot!);
    }

    if (!await _catalogFile.exists()) {
      final seed = await _loadSeed();
      await writer.write(_catalogFile, seed.toJson());
      _snapshot = seed;
      return RepositoryLoad(seed);
    }

    final source = await _catalogFile.readAsString();
    try {
      final snapshot = CatalogSnapshot.fromJsonString(source);
      _snapshot = snapshot;
      return RepositoryLoad(snapshot);
    } catch (_) {
      final preserved = await _quarantine(_catalogFile);
      final seed = await _loadSeed();
      await writer.write(_catalogFile, seed.toJson());
      _snapshot = seed;
      return RepositoryLoad(
        seed,
        recoveryNotice:
            '商品数据损坏，已保留副本（${preserved.uri.pathSegments.last}）并恢复标准演示数据。',
      );
    }
  }

  Future<CatalogSnapshot> _loadSeed() async {
    return CatalogSnapshot.fromJsonString(await seedLoader());
  }

  Future<CatalogSnapshot> _requireSnapshot() async {
    return _snapshot ?? (await loadCatalog()).value;
  }

  @override
  Stream<List<Product>> watchProducts() async* {
    final snapshot = await _requireSnapshot();
    yield List<Product>.unmodifiable(snapshot.products);
    yield* _productsController.stream;
  }

  @override
  Future<List<MainShop>> readMainShops() async =>
      List<MainShop>.unmodifiable((await _requireSnapshot()).mainShops);

  @override
  Future<List<SubShop>> readSubShops() async =>
      List<SubShop>.unmodifiable((await _requireSnapshot()).subShops);

  @override
  Future<List<ProductCategory>> readCategories() async =>
      List<ProductCategory>.unmodifiable((await _requireSnapshot()).categories);

  @override
  Future<Product> createProduct(ProductDraft draft) async {
    final current = await _requireSnapshot();
    _validate(draft, current);
    final nextId =
        current.products.fold<int>(
          0,
          (highest, product) =>
              product.productId > highest ? product.productId : highest,
        ) +
        1;
    final now = DateTime.now();
    final product = draft.toProduct(
      productId: nextId,
      createdAt: now,
      updatedAt: now,
    );
    final next = current.copyWith(products: [...current.products, product]);
    await _persist(next);
    return product;
  }

  @override
  Future<Product> updateProduct(int productId, ProductDraft draft) async {
    final current = await _requireSnapshot();
    _validate(draft, current);
    final existing = current.productById(productId);
    if (existing == null) {
      throw StateError('要编辑的商品不存在');
    }
    final product = draft.toProduct(
      productId: productId,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    final next = current.copyWith(
      products: current.products
          .map((item) => item.productId == productId ? product : item)
          .toList(growable: false),
    );
    await _persist(next);
    return product;
  }

  @override
  Future<void> deleteProduct(int productId) async {
    final current = await _requireSnapshot();
    if (current.productById(productId) == null) {
      throw StateError('要删除的商品不存在');
    }
    final next = current.copyWith(
      products: current.products
          .where((item) => item.productId != productId)
          .toList(growable: false),
    );
    await _persist(next);
  }

  @override
  Future<CatalogSnapshot> resetDemoData() async {
    final seed = await _loadSeed();
    await _persist(seed);
    return seed;
  }

  void _validate(ProductDraft draft, CatalogSnapshot catalog) {
    final errors = draft.validationErrors(catalog);
    if (errors.isNotEmpty) {
      throw CatalogValidationException(errors);
    }
  }

  Future<void> _persist(CatalogSnapshot next) async {
    await writer.write(_catalogFile, next.toJson());
    _snapshot = next;
    _productsController.add(List<Product>.unmodifiable(next.products));
  }

  @override
  void dispose() {
    _productsController.close();
  }
}

class LocalMarketingRepository implements MarketingRepository {
  LocalMarketingRepository({
    required Directory supportDirectory,
    this.writer = const AtomicJsonWriter(),
  }) : _file = File(
         '${supportDirectory.path}${Platform.pathSeparator}marketing_v1.json',
       );

  final File _file;
  final AtomicJsonWriter writer;
  MarketingSnapshot? _snapshot;

  File get marketingFile => _file;

  @override
  Future<RepositoryLoad<MarketingSnapshot>> loadMarketing() async {
    if (_snapshot != null) return RepositoryLoad(_snapshot!);
    if (!await _file.exists()) {
      const empty = MarketingSnapshot();
      await writer.write(_file, empty.toJson());
      _snapshot = empty;
      return const RepositoryLoad(empty);
    }
    try {
      final loaded = MarketingSnapshot.fromJsonString(
        await _file.readAsString(),
      );
      _snapshot = loaded;
      return RepositoryLoad(loaded);
    } catch (_) {
      final preserved = await _quarantine(_file);
      const empty = MarketingSnapshot();
      await writer.write(_file, empty.toJson());
      _snapshot = empty;
      return RepositoryLoad(
        empty,
        recoveryNotice:
            '营销数据损坏，已保留副本（${preserved.uri.pathSegments.last}）并恢复空目录。',
      );
    }
  }

  Future<MarketingSnapshot> _current() async =>
      _snapshot ?? (await loadMarketing()).value;

  Future<void> _persist(MarketingSnapshot next) async {
    await writer.write(_file, next.toJson());
    _snapshot = next;
  }

  @override
  Future<PromotionEvent> createPromotion(
    PromotionDraft draft,
    CatalogSnapshot catalog,
  ) async {
    final errors = draft.validationErrors(catalog);
    if (errors.isNotEmpty) throw MarketingValidationException(errors);
    final current = await _current();
    final nextId =
        current.promotions.fold<int>(
          0,
          (highest, item) => item.saleId > highest ? item.saleId : highest,
        ) +
        1;
    final now = DateTime.now();
    final created = draft.toEvent(nextId, now, now);
    await _persist(
      current.copyWith(promotions: [...current.promotions, created]),
    );
    return created;
  }

  @override
  Future<PromotionEvent> updatePromotion(
    int saleId,
    PromotionDraft draft,
    CatalogSnapshot catalog,
  ) async {
    final current = await _current();
    final existing = current.promotionById(saleId);
    if (existing == null) throw StateError('促销事件不存在');
    final errors = draft.validationErrors(catalog);
    if (errors.isNotEmpty) throw MarketingValidationException(errors);
    final updated = draft.toEvent(saleId, existing.createdAt, DateTime.now());
    final next = current.copyWith(
      promotions: current.promotions
          .map((item) => item.saleId == saleId ? updated : item)
          .toList(growable: false),
    );
    for (final ad in current.adsFor(saleId)) {
      final adErrors = AdvertisementDraft(
        saleId: saleId,
        startTime: ad.startTime,
        endTime: ad.endTime,
        type: ad.type,
        img: ad.img,
      ).validationErrors(next);
      if (adErrors.isNotEmpty) {
        throw const MarketingValidationException({
          'period': '修改后的促销时段不能排除已有广告，请先调整广告时段',
        });
      }
    }
    await _persist(next);
    return updated;
  }

  @override
  Future<void> deletePromotion(int saleId) async {
    final current = await _current();
    if (current.promotionById(saleId) == null) throw StateError('促销事件不存在');
    if (current.adsFor(saleId).isNotEmpty) {
      throw const MarketingValidationException({'ads': '请先删除该促销下的广告'});
    }
    await _persist(
      current.copyWith(
        promotions: current.promotions
            .where((item) => item.saleId != saleId)
            .toList(),
      ),
    );
  }

  @override
  Future<Advertisement> createAdvertisement(AdvertisementDraft draft) async {
    final current = await _current();
    final errors = draft.validationErrors(current);
    if (errors.isNotEmpty) throw MarketingValidationException(errors);
    final nextId =
        current.advertisements.fold<int>(
          0,
          (highest, item) => item.adId > highest ? item.adId : highest,
        ) +
        1;
    final now = DateTime.now();
    final created = draft.toAdvertisement(nextId, now, now);
    await _persist(
      current.copyWith(advertisements: [...current.advertisements, created]),
    );
    return created;
  }

  @override
  Future<Advertisement> updateAdvertisement(
    int adId,
    AdvertisementDraft draft,
  ) async {
    final current = await _current();
    Advertisement? existing;
    for (final item in current.advertisements) {
      if (item.adId == adId) existing = item;
    }
    if (existing == null) throw StateError('广告不存在');
    if (draft.saleId != existing.saleId) {
      throw const MarketingValidationException({'saleID': '广告不能转移到另一条促销'});
    }
    final errors = draft.validationErrors(current);
    if (errors.isNotEmpty) throw MarketingValidationException(errors);
    final updated = draft.toAdvertisement(
      adId,
      existing.createdAt,
      DateTime.now(),
    );
    await _persist(
      current.copyWith(
        advertisements: current.advertisements
            .map((item) => item.adId == adId ? updated : item)
            .toList(growable: false),
      ),
    );
    return updated;
  }

  @override
  Future<void> deleteAdvertisement(int adId) async {
    final current = await _current();
    if (!current.advertisements.any((item) => item.adId == adId)) {
      throw StateError('广告不存在');
    }
    await _persist(
      current.copyWith(
        advertisements: current.advertisements
            .where((item) => item.adId != adId)
            .toList(),
      ),
    );
  }

  @override
  Future<MarketingSnapshot> resetDemoData() async {
    const empty = MarketingSnapshot();
    await _persist(empty);
    return empty;
  }
}

Future<File> _quarantine(File source) async {
  final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );
  final preserved = File('${source.path}.corrupt-$timestamp');
  return source.rename(preserved.path);
}
