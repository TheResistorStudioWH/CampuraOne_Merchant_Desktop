import 'dart:convert';

const _unset = Object();

Map<String, dynamic> _asMap(Object? value, String label) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw FormatException('$label 必须是 JSON 对象');
}

List<Map<String, dynamic>> _asMapList(Object? value, String label) {
  if (value is! List) {
    throw FormatException('$label 必须是 JSON 数组');
  }
  return value.map((item) => _asMap(item, label)).toList(growable: false);
}

int _asInt(Object? value, String label) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('$label 必须是整数');
  }
  return parsed;
}

int? _asNullableInt(Object? value, String label) {
  if (value == null) {
    return null;
  }
  return _asInt(value, label);
}

String _asString(Object? value, String label) {
  if (value is String) {
    return value;
  }
  throw FormatException('$label 必须是字符串');
}

String? _asNullableString(Object? value, String label) {
  if (value == null) {
    return null;
  }
  return _asString(value, label);
}

List<int>? _asNullableIntList(Object? value, String label) {
  if (value == null) {
    return null;
  }
  if (value is! List) {
    throw FormatException('$label 必须是数组');
  }
  return value.map((item) => _asInt(item, label)).toList(growable: false);
}

List<String>? _asNullableStringList(Object? value, String label) {
  if (value == null) {
    return null;
  }
  if (value is! List) {
    throw FormatException('$label 必须是数组');
  }
  return value.map((item) => _asString(item, label)).toList(growable: false);
}

DateTime? _asNullableDateTime(Object? value, String label) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  final source = _asString(value, label);
  final parsed = DateTime.tryParse(source.replaceFirst(' ', 'T'));
  if (parsed == null) {
    throw FormatException('$label 不是有效时间');
  }
  return parsed;
}

String? _dateToJson(DateTime? value) => value?.toIso8601String();

/// 将 DECIMAL(10,2) 文本精确转成分，避免浮点误差进入本地数据。
int? parsePriceInCents(String source) {
  final value = source.trim();
  if (!RegExp(r'^\d{1,8}(?:\.\d{1,2})?$').hasMatch(value)) {
    return null;
  }
  final parts = value.split('.');
  final whole = int.parse(parts.first);
  final fraction = parts.length == 1
      ? 0
      : int.parse(parts.last.padRight(2, '0'));
  final cents = whole * 100 + fraction;
  return cents <= 9999999999 ? cents : null;
}

int _priceFromJson(Object? value) {
  if (value is num && (!value.isFinite || value.isNegative)) {
    throw const FormatException('price 超出允许范围');
  }
  final parsed = parsePriceInCents(value?.toString() ?? '');
  if (parsed == null) {
    throw const FormatException('price 必须符合 DECIMAL(10,2)');
  }
  return parsed;
}

class MerchantSession {
  const MerchantSession({
    required this.userId,
    required this.userName,
    required this.shopIds,
    required this.subShopIds,
    required this.signedInAt,
  });

  final int userId;
  final String userName;
  final List<int> shopIds;
  final List<int> subShopIds;
  final DateTime signedInAt;

  factory MerchantSession.fromJson(Map<String, dynamic> json) {
    return MerchantSession(
      userId: _asInt(json['userID'], 'userID'),
      userName: _asString(json['userName'], 'userName'),
      shopIds: _asNullableIntList(json['shopIDs'], 'shopIDs') ?? const [],
      subShopIds:
          _asNullableIntList(json['subShopIDs'], 'subShopIDs') ?? const [],
      signedInAt:
          _asNullableDateTime(json['signedInAt'], 'signedInAt') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
    'userID': userId,
    'userName': userName,
    'shopIDs': shopIds,
    'subShopIDs': subShopIds,
    'signedInAt': signedInAt.toIso8601String(),
  };
}

class MainShop {
  const MainShop({
    required this.shopId,
    required this.shopName,
    required this.schoolId,
    required this.accountId,
    this.shopAddress,
    this.shopSlogan,
    this.subShopsList,
    this.productsList,
    this.adIds,
    this.shopLogo,
    this.shopImg,
    this.saleIds,
    this.areaId,
    this.createdAt,
    this.updatedAt,
  });

  final int shopId;
  final String shopName;
  final List<String>? shopAddress;
  final String? shopSlogan;
  final List<int>? subShopsList;
  final List<int>? productsList;
  final List<int>? adIds;
  final String? shopLogo;
  final String? shopImg;
  final List<int>? saleIds;
  final int schoolId;
  final int? areaId;
  final int accountId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MainShop.fromJson(Map<String, dynamic> json) => MainShop(
    shopId: _asInt(json['shopID'], 'shopID'),
    shopName: _asString(json['shopName'], 'shopName'),
    shopAddress: _asNullableStringList(json['shopAddress'], 'shopAddress'),
    shopSlogan: _asNullableString(json['shopSlogan'], 'shopSlogan'),
    subShopsList: _asNullableIntList(json['subShopsList'], 'subShopsList'),
    productsList: _asNullableIntList(json['productsList'], 'productsList'),
    adIds: _asNullableIntList(json['adIDs'], 'adIDs'),
    shopLogo: _asNullableString(json['shopLogo'], 'shopLogo'),
    shopImg: _asNullableString(json['shopImg'], 'shopImg'),
    saleIds: _asNullableIntList(json['saleIDs'], 'saleIDs'),
    schoolId: _asInt(json['schoolID'], 'schoolID'),
    areaId: _asNullableInt(json['areaID'], 'areaID'),
    accountId: _asInt(json['accountID'], 'accountID'),
    createdAt: _asNullableDateTime(json['createdAt'], 'createdAt'),
    updatedAt: _asNullableDateTime(json['updatedAt'], 'updatedAt'),
  );

  MainShop copyWith({List<int>? productsList, List<int>? subShopsList}) {
    return MainShop(
      shopId: shopId,
      shopName: shopName,
      shopAddress: shopAddress,
      shopSlogan: shopSlogan,
      subShopsList: subShopsList ?? this.subShopsList,
      productsList: productsList ?? this.productsList,
      adIds: adIds,
      shopLogo: shopLogo,
      shopImg: shopImg,
      saleIds: saleIds,
      schoolId: schoolId,
      areaId: areaId,
      accountId: accountId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'shopID': shopId,
    'shopName': shopName,
    'shopAddress': shopAddress,
    'shopSlogan': shopSlogan,
    'subShopsList': subShopsList,
    'productsList': productsList,
    'adIDs': adIds,
    'shopLogo': shopLogo,
    'shopImg': shopImg,
    'saleIDs': saleIds,
    'schoolID': schoolId,
    'areaID': areaId,
    'accountID': accountId,
    'createdAt': _dateToJson(createdAt),
    'updatedAt': _dateToJson(updatedAt),
  };
}

class SubShop {
  const SubShop({
    required this.shopId,
    required this.shopName,
    required this.mainShopId,
    required this.accountId,
    this.shopAddress,
    this.productsList,
    this.shopImg,
    this.saleList,
    this.takeOutLink,
    this.createdAt,
    this.updatedAt,
  });

  final int shopId;
  final String shopName;
  final List<String>? shopAddress;
  final List<int>? productsList;
  final String? shopImg;
  final int mainShopId;
  final List<int>? saleList;
  final String? takeOutLink;
  final int accountId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SubShop.fromJson(Map<String, dynamic> json) => SubShop(
    shopId: _asInt(json['shopID'], 'shopID'),
    shopName: _asString(json['shopName'], 'shopName'),
    shopAddress: _asNullableStringList(json['shopAddress'], 'shopAddress'),
    productsList: _asNullableIntList(json['productsList'], 'productsList'),
    shopImg: _asNullableString(json['shopImg'], 'shopImg'),
    mainShopId: _asInt(json['mainShopID'], 'mainShopID'),
    saleList: _asNullableIntList(json['saleList'], 'saleList'),
    takeOutLink: _asNullableString(json['takeOutLink'], 'takeOutLink'),
    accountId: _asInt(json['accountID'], 'accountID'),
    createdAt: _asNullableDateTime(json['createdAt'], 'createdAt'),
    updatedAt: _asNullableDateTime(json['updatedAt'], 'updatedAt'),
  );

  SubShop copyWith({List<int>? productsList}) => SubShop(
    shopId: shopId,
    shopName: shopName,
    shopAddress: shopAddress,
    productsList: productsList ?? this.productsList,
    shopImg: shopImg,
    mainShopId: mainShopId,
    saleList: saleList,
    takeOutLink: takeOutLink,
    accountId: accountId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'shopID': shopId,
    'shopName': shopName,
    'shopAddress': shopAddress,
    'productsList': productsList,
    'shopImg': shopImg,
    'mainShopID': mainShopId,
    'saleList': saleList,
    'takeOutLink': takeOutLink,
    'accountID': accountId,
    'createdAt': _dateToJson(createdAt),
    'updatedAt': _dateToJson(updatedAt),
  };
}

class ProductCategory {
  const ProductCategory({
    required this.categoryId,
    required this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.createdAt,
    this.updatedAt,
  });

  final int categoryId;
  final String categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        categoryId: _asInt(json['categoryID'], 'categoryID'),
        categoryName: _asString(json['categoryName'], 'categoryName'),
        categoryIcon: _asNullableString(json['categoryIcon'], 'categoryIcon'),
        categoryColor: _asNullableString(
          json['categoryColor'],
          'categoryColor',
        ),
        createdAt: _asNullableDateTime(json['createdAt'], 'createdAt'),
        updatedAt: _asNullableDateTime(json['updatedAt'], 'updatedAt'),
      );

  Map<String, dynamic> toJson() => {
    'categoryID': categoryId,
    'categoryName': categoryName,
    'categoryIcon': categoryIcon,
    'categoryColor': categoryColor,
    'createdAt': _dateToJson(createdAt),
    'updatedAt': _dateToJson(updatedAt),
  };
}

class Product {
  const Product({
    required this.productId,
    required this.productName,
    required this.priceInCents,
    required this.mainShopId,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.productImg,
    this.productIntro,
    this.subShopId,
  });

  final int productId;
  final String productName;
  final int? categoryId;
  final int priceInCents;
  final String? productImg;
  final String? productIntro;
  final int mainShopId;
  final int? subShopId;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get priceAsDecimal {
    final whole = priceInCents ~/ 100;
    final cents = (priceInCents % 100).toString().padLeft(2, '0');
    return '$whole.$cents';
  }

  double get price => priceInCents / 100;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    productId: _asInt(json['productID'], 'productID'),
    productName: _asString(json['productName'], 'productName'),
    categoryId: _asNullableInt(json['categoryID'], 'categoryID'),
    priceInCents: _priceFromJson(json['price']),
    productImg: _asNullableString(json['productImg'], 'productImg'),
    productIntro: _asNullableString(json['productIntro'], 'productIntro'),
    mainShopId: _asInt(json['mainShopID'], 'mainShopID'),
    subShopId: _asNullableInt(json['subShopID'], 'subShopID'),
    createdAt:
        _asNullableDateTime(json['createdAt'], 'createdAt') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt:
        _asNullableDateTime(json['updatedAt'], 'updatedAt') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  Product copyWith({
    String? productName,
    Object? categoryId = _unset,
    int? priceInCents,
    Object? productImg = _unset,
    Object? productIntro = _unset,
    int? mainShopId,
    Object? subShopId = _unset,
    DateTime? updatedAt,
  }) {
    return Product(
      productId: productId,
      productName: productName ?? this.productName,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as int?,
      priceInCents: priceInCents ?? this.priceInCents,
      productImg: identical(productImg, _unset)
          ? this.productImg
          : productImg as String?,
      productIntro: identical(productIntro, _unset)
          ? this.productIntro
          : productIntro as String?,
      mainShopId: mainShopId ?? this.mainShopId,
      subShopId: identical(subShopId, _unset)
          ? this.subShopId
          : subShopId as int?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'productID': productId,
    'productName': productName,
    'categoryID': categoryId,
    'price': priceAsDecimal,
    'productImg': productImg,
    'productIntro': productIntro,
    'mainShopID': mainShopId,
    'subShopID': subShopId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class ProductDraft {
  const ProductDraft({
    required this.productName,
    required this.priceText,
    required this.mainShopId,
    this.categoryId,
    this.productImg,
    this.productIntro,
    this.subShopId,
  });

  final String productName;
  final String priceText;
  final int? categoryId;
  final String? productImg;
  final String? productIntro;
  final int mainShopId;
  final int? subShopId;

  factory ProductDraft.fromProduct(Product product) => ProductDraft(
    productName: product.productName,
    priceText: product.priceAsDecimal,
    categoryId: product.categoryId,
    productImg: product.productImg,
    productIntro: product.productIntro,
    mainShopId: product.mainShopId,
    subShopId: product.subShopId,
  );

  Map<String, String> validationErrors(CatalogSnapshot catalog) {
    final errors = <String, String>{};
    final name = productName.trim();
    if (name.isEmpty || name.length > 100) {
      errors['productName'] = '名称需要 1–100 个字符';
    }
    if (parsePriceInCents(priceText) == null) {
      errors['price'] = '请输入 0–99999999.99 之间、最多两位小数的价格';
    }
    if (!catalog.mainShops.any((shop) => shop.shopId == mainShopId)) {
      errors['mainShopID'] = '所属主商户不存在';
    }
    if (categoryId != null &&
        !catalog.categories.any((item) => item.categoryId == categoryId)) {
      errors['categoryID'] = '所选分类不存在';
    }
    if (subShopId != null) {
      final matches = catalog.subShops.where(
        (shop) => shop.shopId == subShopId,
      );
      if (matches.isEmpty || matches.first.mainShopId != mainShopId) {
        errors['subShopID'] = '子商户必须属于当前主商户';
      }
    }
    return errors;
  }

  Product toProduct({
    required int productId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final cents = parsePriceInCents(priceText);
    if (cents == null) {
      throw const FormatException('商品价格无效');
    }
    String? cleaned(String? value) {
      final result = value?.trim();
      return result == null || result.isEmpty ? null : result;
    }

    return Product(
      productId: productId,
      productName: productName.trim(),
      categoryId: categoryId,
      priceInCents: cents,
      productImg: cleaned(productImg),
      productIntro: cleaned(productIntro),
      mainShopId: mainShopId,
      subShopId: subShopId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.mainShops,
    required this.subShops,
    required this.categories,
    required this.products,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final List<MainShop> mainShops;
  final List<SubShop> subShops;
  final List<ProductCategory> categories;
  final List<Product> products;

  factory CatalogSnapshot.fromJson(Map<String, dynamic> json) {
    final snapshot = CatalogSnapshot(
      schemaVersion: _asInt(json['schemaVersion'] ?? 1, 'schemaVersion'),
      mainShops: _asMapList(
        json['mainShops'],
        'mainShops',
      ).map(MainShop.fromJson).toList(growable: false),
      subShops: _asMapList(
        json['subShops'],
        'subShops',
      ).map(SubShop.fromJson).toList(growable: false),
      categories: _asMapList(
        json['categories'],
        'categories',
      ).map(ProductCategory.fromJson).toList(growable: false),
      products: _asMapList(
        json['products'],
        'products',
      ).map(Product.fromJson).toList(growable: false),
    );
    return snapshot.synchronizeProductLists();
  }

  factory CatalogSnapshot.fromJsonString(String source) {
    return CatalogSnapshot.fromJson(_asMap(jsonDecode(source), '商品目录'));
  }

  MainShop? mainShopById(int id) {
    for (final shop in mainShops) {
      if (shop.shopId == id) {
        return shop;
      }
    }
    return null;
  }

  SubShop? subShopById(int? id) {
    if (id == null) {
      return null;
    }
    for (final shop in subShops) {
      if (shop.shopId == id) {
        return shop;
      }
    }
    return null;
  }

  ProductCategory? categoryById(int? id) {
    if (id == null) {
      return null;
    }
    for (final category in categories) {
      if (category.categoryId == id) {
        return category;
      }
    }
    return null;
  }

  Product? productById(int id) {
    for (final product in products) {
      if (product.productId == id) {
        return product;
      }
    }
    return null;
  }

  CatalogSnapshot copyWith({List<Product>? products}) => CatalogSnapshot(
    schemaVersion: schemaVersion,
    mainShops: mainShops,
    subShops: subShops,
    categories: categories,
    products: products ?? this.products,
  ).synchronizeProductLists();

  CatalogSnapshot synchronizeProductLists() {
    final nextMainShops = mainShops
        .map(
          (shop) => shop.copyWith(
            productsList: products
                .where((product) => product.mainShopId == shop.shopId)
                .map((product) => product.productId)
                .toList(growable: false),
            subShopsList: subShops
                .where((subShop) => subShop.mainShopId == shop.shopId)
                .map((subShop) => subShop.shopId)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    final nextSubShops = subShops
        .map(
          (shop) => shop.copyWith(
            productsList: products
                .where((product) => product.subShopId == shop.shopId)
                .map((product) => product.productId)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    return CatalogSnapshot(
      schemaVersion: schemaVersion,
      mainShops: nextMainShops,
      subShops: nextSubShops,
      categories: categories,
      products: products,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'mainShops': mainShops.map((item) => item.toJson()).toList(),
    'subShops': subShops.map((item) => item.toJson()).toList(),
    'categories': categories.map((item) => item.toJson()).toList(),
    'products': products.map((item) => item.toJson()).toList(),
  };
}

enum ProductOwnership { all, direct, subShop }

enum ProductSort { updatedDesc, updatedAsc, nameAsc, priceAsc, priceDesc }

class ProductQuery {
  const ProductQuery({
    this.search = '',
    this.categoryId,
    this.mainShopId,
    this.subShopId,
    this.ownership = ProductOwnership.all,
    this.sort = ProductSort.updatedDesc,
  });

  final String search;
  final int? categoryId;
  final int? mainShopId;
  final int? subShopId;
  final ProductOwnership ownership;
  final ProductSort sort;

  List<Product> apply(Iterable<Product> source) {
    final needle = search.trim().toLowerCase();
    final result = source
        .where((product) {
          if (categoryId != null && product.categoryId != categoryId) {
            return false;
          }
          if (mainShopId != null && product.mainShopId != mainShopId) {
            return false;
          }
          if (subShopId != null && product.subShopId != subShopId) {
            return false;
          }
          if (ownership == ProductOwnership.direct &&
              product.subShopId != null) {
            return false;
          }
          if (ownership == ProductOwnership.subShop &&
              product.subShopId == null) {
            return false;
          }
          if (needle.isEmpty) {
            return true;
          }
          return product.productName.toLowerCase().contains(needle) ||
              (product.productIntro?.toLowerCase().contains(needle) ?? false);
        })
        .toList(growable: false);

    int updated(Product value) => value.updatedAt.millisecondsSinceEpoch;
    switch (sort) {
      case ProductSort.updatedDesc:
        result.sort((left, right) => updated(right).compareTo(updated(left)));
      case ProductSort.updatedAsc:
        result.sort((left, right) => updated(left).compareTo(updated(right)));
      case ProductSort.nameAsc:
        result.sort(
          (left, right) => left.productName.compareTo(right.productName),
        );
      case ProductSort.priceAsc:
        result.sort(
          (left, right) => left.priceInCents.compareTo(right.priceInCents),
        );
      case ProductSort.priceDesc:
        result.sort(
          (left, right) => right.priceInCents.compareTo(left.priceInCents),
        );
    }
    return result;
  }
}
