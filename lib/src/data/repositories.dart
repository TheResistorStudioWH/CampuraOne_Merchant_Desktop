import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

Future<File> _quarantine(File source) async {
  final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );
  final preserved = File('${source.path}.corrupt-$timestamp');
  return source.rename(preserved.path);
}
