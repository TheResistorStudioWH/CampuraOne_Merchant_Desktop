import 'package:campura_one_merchant/src/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Product JSON', () {
    test('解析服务器字段、字符串 DECIMAL 和可空字段', () {
      final product = Product.fromJson({
        'productID': 9,
        'productName': '冰美式',
        'categoryID': null,
        'price': '12.50',
        'productImg': null,
        'productIntro': null,
        'mainShopID': 1,
        'subShopID': null,
        'createdAt': '2026-06-05 02:07:26',
        'updatedAt': '2026-06-15 14:17:48',
      });

      expect(product.productId, 9);
      expect(product.priceInCents, 1250);
      expect(product.priceAsDecimal, '12.50');
      expect(product.categoryId, isNull);
      expect(product.productImg, isNull);
      expect(product.toJson()['price'], '12.50');
      expect(
        product.toJson().keys,
        containsAll(<String>{
          'productID',
          'productName',
          'categoryID',
          'price',
          'productImg',
          'productIntro',
          'mainShopID',
          'subShopID',
          'createdAt',
          'updatedAt',
        }),
      );
    });

    test('价格严格遵守 DECIMAL(10,2)', () {
      expect(parsePriceInCents('0'), 0);
      expect(parsePriceInCents('0.1'), 10);
      expect(parsePriceInCents('99999999.99'), 9999999999);
      expect(parsePriceInCents('-1'), isNull);
      expect(parsePriceInCents('1.001'), isNull);
      expect(parsePriceInCents('100000000.00'), isNull);
    });
  });

  group('ProductQuery', () {
    final products = [
      _product(1, '冰美式', 1200, categoryId: 1),
      _product(2, '烤肠', 600, categoryId: 3, subShopId: 1),
      _product(3, '拿铁', 1500, categoryId: 1),
    ];

    test('支持搜索、分类和商户归属筛选', () {
      expect(
        const ProductQuery(search: '美式')
            .apply(products)
            .map((item) => item.productId),
        [1],
      );
      expect(
        const ProductQuery(categoryId: 1)
            .apply(products)
            .map((item) => item.productId),
        [3, 1],
      );
      expect(
        const ProductQuery(ownership: ProductOwnership.subShop)
            .apply(products)
            .map((item) => item.productId),
        [2],
      );
      expect(
        const ProductQuery(subShopId: 1)
            .apply([...products, _product(4, '另一子商户商品', 900, subShopId: 2)])
            .map((item) => item.productId),
        [2],
      );
      expect(
        const ProductQuery(
          mainShopId: 1,
          ownership: ProductOwnership.direct,
        ).apply(products).map((item) => item.productId),
        [3, 1],
      );
    });

    test('按价格排序', () {
      expect(
        const ProductQuery(sort: ProductSort.priceAsc)
            .apply(products)
            .map((item) => item.priceInCents),
        [600, 1200, 1500],
      );
      expect(
        const ProductQuery(sort: ProductSort.priceDesc)
            .apply(products)
            .map((item) => item.priceInCents),
        [1500, 1200, 600],
      );
    });
  });

  test('子商户必须属于当前主商户', () {
    final catalog = CatalogSnapshot(
      mainShops: const [
        MainShop(shopId: 1, shopName: 'A', schoolId: 1, accountId: 1),
        MainShop(shopId: 2, shopName: 'B', schoolId: 1, accountId: 1),
      ],
      subShops: const [
        SubShop(shopId: 8, shopName: 'B-1', mainShopId: 2, accountId: 1),
      ],
      categories: const [],
      products: const [],
    );
    const draft = ProductDraft(
      productName: '测试商品',
      priceText: '8.00',
      mainShopId: 1,
      subShopId: 8,
    );

    expect(draft.validationErrors(catalog), contains('subShopID'));
  });
}

Product _product(
  int id,
  String name,
  int cents, {
  int? categoryId,
  int? subShopId,
}) {
  return Product(
    productId: id,
    productName: name,
    priceInCents: cents,
    categoryId: categoryId,
    mainShopId: 1,
    subShopId: subShopId,
    createdAt: DateTime(2026, 1, id),
    updatedAt: DateTime(2026, 1, id),
  );
}
