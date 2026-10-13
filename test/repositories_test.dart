import 'dart:io';

import 'package:campura_one_merchant/src/data/repositories.dart';
import 'package:campura_one_merchant/src/domain/appearance.dart';
import 'package:campura_one_merchant/src/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late String seed;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'campura-merchant-',
    );
    seed = await File('assets/demo/catalog_seed.json').readAsString();
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  LocalCatalogRepository repository({AtomicJsonWriter? writer}) {
    return LocalCatalogRepository(
      supportDirectory: temporaryDirectory,
      seedLoader: () async => seed,
      writer: writer ?? const AtomicJsonWriter(),
    );
  }

  test('首次初始化复制 seed，CRUD 在重启后仍存在', () async {
    final first = repository();
    final initial = await first.loadCatalog();
    expect(initial.value.products, hasLength(4));
    expect(await first.catalogFile.exists(), isTrue);

    final created = await first.createProduct(
      const ProductDraft(
        productName: '新商品',
        priceText: '19.90',
        categoryId: 3,
        mainShopId: 1,
        subShopId: 1,
      ),
    );
    expect(created.productId, 5);
    first.dispose();

    final restarted = repository();
    final restored = await restarted.loadCatalog();
    expect(restored.value.products, hasLength(5));
    expect(restored.value.productById(5)?.priceInCents, 1990);

    await restarted.updateProduct(
      5,
      const ProductDraft(
        productName: '更名商品',
        priceText: '20.00',
        mainShopId: 1,
      ),
    );
    await restarted.deleteProduct(1);
    final afterCrud = await restarted.loadCatalog();
    expect(afterCrud.value.productById(5)?.productName, '更名商品');
    expect(afterCrud.value.productById(1), isNull);
    restarted.dispose();
  });

  test('原子提交失败时恢复原文件，不发布新状态', () async {
    final initial = repository();
    await initial.loadCatalog();
    initial.dispose();

    final failing = repository(
      writer: AtomicJsonWriter(
        beforeCommit: (temporary, backup) {
          throw const FileSystemException('模拟提交失败');
        },
      ),
    );
    await failing.loadCatalog();
    await expectLater(
      failing.createProduct(
        const ProductDraft(
          productName: '不应写入',
          priceText: '1.00',
          mainShopId: 1,
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
    failing.dispose();

    final verifier = repository();
    final restored = await verifier.loadCatalog();
    expect(restored.value.products, hasLength(4));
    expect(restored.value.products, isNot(contains('不应写入')));
    verifier.dispose();
  });

  test('损坏文件会保留时间戳副本并恢复 seed', () async {
    final first = repository();
    await first.loadCatalog();
    first.dispose();
    await File(
      '${temporaryDirectory.path}${Platform.pathSeparator}catalog_v1.json',
    ).writeAsString('{broken json');

    final recovered = repository();
    final result = await recovered.loadCatalog();
    expect(result.value.products, hasLength(4));
    expect(result.recoveryNotice, contains('已保留副本'));
    final preserved = temporaryDirectory.listSync().whereType<File>().where(
      (file) => file.path.contains('.corrupt-'),
    );
    expect(preserved, hasLength(1));
    recovered.dispose();
  });

  test('会话可恢复但持久化文件不包含密码', () async {
    final auth = LocalAuthRepository(supportDirectory: temporaryDirectory);
    final session = await auth.login(
      demoMerchantUserName,
      demoMerchantPassword,
    );
    expect(session.shopIds, [1]);
    final source = await auth.sessionFile.readAsString();
    expect(source, isNot(contains(demoMerchantPassword)));

    final restarted = LocalAuthRepository(supportDirectory: temporaryDirectory);
    expect(
      (await restarted.restoreSession()).value?.userName,
      demoMerchantUserName,
    );
    await restarted.logout();
    expect((await restarted.restoreSession()).value, isNull);
  });

  test('恢复演示目录不会退出登录', () async {
    final auth = LocalAuthRepository(supportDirectory: temporaryDirectory);
    await auth.login(demoMerchantUserName, demoMerchantPassword);
    final catalog = repository();
    await catalog.loadCatalog();
    await catalog.deleteProduct(1);
    expect((await catalog.loadCatalog()).value.products, hasLength(3));

    final reset = await catalog.resetDemoData();
    expect(reset.products, hasLength(4));
    expect((await auth.restoreSession()).value, isNotNull);
    catalog.dispose();
  });

  test('外观设置可持久化并在重启后恢复', () async {
    final first = LocalAppearanceRepository(
      supportDirectory: temporaryDirectory,
    );
    expect((await first.loadAppearance()).value, const AppearanceSettings());

    const selected = AppearanceSettings(
      preset: MerchantThemePreset.lagoon,
      brightness: AppearanceBrightness.dark,
    );
    await first.saveAppearance(selected);

    final restarted = LocalAppearanceRepository(
      supportDirectory: temporaryDirectory,
    );
    expect((await restarted.loadAppearance()).value, selected);
  });

  test('损坏的外观设置会保留副本并回退默认值', () async {
    final repository = LocalAppearanceRepository(
      supportDirectory: temporaryDirectory,
    );
    await repository.saveAppearance(
      const AppearanceSettings(preset: MerchantThemePreset.sunset),
    );
    await repository.appearanceFile.writeAsString('{broken json');

    final recovered = await repository.loadAppearance();
    expect(recovered.value, const AppearanceSettings());
    expect(recovered.recoveryNotice, contains('已保留副本'));
    expect(
      temporaryDirectory.listSync().whereType<File>().where(
        (file) => file.path.contains('appearance_v1.json.corrupt-'),
      ),
      hasLength(1),
    );
  });
}
