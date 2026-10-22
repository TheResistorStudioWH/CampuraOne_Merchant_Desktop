import 'dart:io';

import 'package:campura_one_merchant/src/data/repositories.dart';
import 'package:campura_one_merchant/src/domain/marketing_models.dart';
import 'package:campura_one_merchant/src/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late CatalogSnapshot catalog;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('campura-marketing-');
    catalog = CatalogSnapshot.fromJsonString(
      await File('assets/demo/catalog_seed.json').readAsString(),
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('促销和广告 JSON 使用现有服务器字段并保留可空值', () {
    final snapshot = MarketingSnapshot.fromJsonString('''{
      "promotions": [{
        "saleID": 2, "productID": null, "saleRule": "早餐立减",
        "startTime": "2026-10-20 08:00:00", "endTime": null,
        "createdAt": "2026-10-19 12:00:00", "updatedAt": "2026-10-19 12:00:00"
      }],
      "advertisements": [{
        "adID": 4, "saleID": 2, "startTime": "2026-10-20 08:00:00",
        "endTime": null, "type": "S", "img": "assets/demo/images/01-americano-S.png",
        "createdAt": "2026-10-19 12:00:00", "updatedAt": "2026-10-19 12:00:00"
      }]
    }''');
    expect(snapshot.promotions.single.productId, isNull);
    expect(snapshot.promotions.single.endTime, isNull);
    expect(snapshot.adsFor(2).single.type, 'S');
    expect(
      snapshot.promotions.single.toJson().keys,
      containsAll(['saleID', 'productID', 'saleRule', 'startTime', 'endTime']),
    );
    expect(
      snapshot.advertisements.single.toJson().keys,
      containsAll(['adID', 'saleID', 'startTime', 'endTime', 'type', 'img']),
    );
  });

  test('广告必须属于促销且时段包含在促销内', () {
    final event = PromotionDraft(
      saleRule: '立减 3 元',
      productId: 1,
      startTime: DateTime(2026, 10, 20, 8),
      endTime: DateTime(2026, 10, 21, 20),
    ).toEvent(1, DateTime(2026, 10, 19), DateTime(2026, 10, 19));
    final snapshot = MarketingSnapshot(promotions: [event]);
    expect(
      AdvertisementDraft(
        saleId: 2,
        startTime: event.startTime,
        type: 'S',
        img: 'image',
      ).validationErrors(snapshot),
      contains('saleID'),
    );
    expect(
      AdvertisementDraft(
        saleId: 1,
        startTime: event.startTime,
        type: 'S',
        img: 'image',
      ).validationErrors(snapshot),
      contains('period'),
    );
    expect(
      AdvertisementDraft(
        saleId: 1,
        startTime: event.startTime,
        endTime: event.endTime,
        type: 'L',
        img: 'image',
      ).validationErrors(snapshot),
      isEmpty,
    );
  });

  test('本地促销和广告可创建、重启恢复、更新和删除', () async {
    final first = LocalMarketingRepository(supportDirectory: directory);
    expect((await first.loadMarketing()).value.promotions, isEmpty);
    final event = await first.createPromotion(
      PromotionDraft(
        saleRule: '套餐立减 3 元',
        productId: 1,
        startTime: DateTime(2026, 10, 20, 8),
        endTime: DateTime(2026, 10, 21, 20),
      ),
      catalog,
    );
    final ad = await first.createAdvertisement(
      AdvertisementDraft(
        saleId: event.saleId,
        startTime: event.startTime,
        endTime: event.endTime,
        type: 'S',
        img: 'assets/demo/images/01-americano-S.png',
      ),
    );
    expect(ad.saleId, event.saleId);

    final restarted = LocalMarketingRepository(supportDirectory: directory);
    final loaded = (await restarted.loadMarketing()).value;
    expect(loaded.promotions.single.displayTitle, '套餐立减 3 元');
    expect(loaded.adsFor(event.saleId).single.img, contains('americano'));
    await expectLater(
      restarted.deletePromotion(event.saleId),
      throwsA(isA<MarketingValidationException>()),
    );

    await restarted.updateAdvertisement(
      ad.adId,
      AdvertisementDraft(
        saleId: event.saleId,
        startTime: event.startTime,
        endTime: event.endTime,
        type: 'L',
        img: 'assets/demo/images/02-breakfast-L.png',
      ),
    );
    expect(
      (await restarted.loadMarketing()).value.adsFor(event.saleId).single.type,
      'L',
    );
    await restarted.deleteAdvertisement(ad.adId);
    await restarted.deletePromotion(event.saleId);
    expect((await restarted.loadMarketing()).value.promotions, isEmpty);
  });

  test('营销文件原子提交失败回滚，损坏文件保留副本', () async {
    final initial = LocalMarketingRepository(supportDirectory: directory);
    await initial.loadMarketing();
    final failing = LocalMarketingRepository(
      supportDirectory: directory,
      writer: AtomicJsonWriter(
        beforeCommit: (_, _) {
          throw const FileSystemException('模拟提交失败');
        },
      ),
    );
    await failing.loadMarketing();
    await expectLater(
      failing.createPromotion(
        PromotionDraft(saleRule: '不会保存', startTime: DateTime(2026, 10, 20)),
        catalog,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      (await LocalMarketingRepository(
        supportDirectory: directory,
      ).loadMarketing()).value.promotions,
      isEmpty,
    );

    await initial.marketingFile.writeAsString('{broken');
    final recovered = await LocalMarketingRepository(
      supportDirectory: directory,
    ).loadMarketing();
    expect(recovered.value.promotions, isEmpty);
    expect(recovered.recoveryNotice, contains('已保留副本'));
    expect(
      directory.listSync().whereType<File>().where(
        (file) => file.path.contains('marketing_v1.json.corrupt-'),
      ),
      hasLength(1),
    );
  });
}
