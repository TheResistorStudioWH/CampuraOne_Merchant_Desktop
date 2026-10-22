import 'dart:convert';

import 'models.dart';

DateTime _requiredDate(Object? value, String field) {
  final parsed = DateTime.tryParse(
    value?.toString().replaceFirst(' ', 'T') ?? '',
  );
  if (parsed == null) throw FormatException('$field 不是有效时间');
  return parsed;
}

DateTime? _optionalDate(Object? value, String field) =>
    value == null ? null : _requiredDate(value, field);

int _requiredId(Object? value, String field) {
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (parsed == null || parsed < 1) throw FormatException('$field 必须是正整数');
  return parsed;
}

int? _optionalId(Object? value, String field) =>
    value == null ? null : _requiredId(value, field);

List<Map<String, dynamic>> _objects(Object? value, String field) {
  if (value is! List) throw FormatException('$field 必须是数组');
  return value
      .map((item) {
        if (item is! Map) throw FormatException('$field 内必须是对象');
        return Map<String, dynamic>.from(item);
      })
      .toList(growable: false);
}

class PromotionEvent {
  const PromotionEvent({
    required this.saleId,
    required this.startTime,
    required this.createdAt,
    required this.updatedAt,
    this.productId,
    this.saleRule,
    this.endTime,
  });

  final int saleId;
  final int? productId;
  final String? saleRule;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayTitle =>
      saleRule?.trim().isNotEmpty == true ? saleRule!.trim() : '促销活动';

  String statusAt(DateTime now) {
    if (startTime.isAfter(now)) return '未开始';
    if (endTime != null && endTime!.isBefore(now)) return '已结束';
    return '进行中';
  }

  factory PromotionEvent.fromJson(Map<String, dynamic> json) => PromotionEvent(
    saleId: _requiredId(json['saleID'], 'saleID'),
    productId: _optionalId(json['productID'], 'productID'),
    saleRule: json['saleRule'] as String?,
    startTime: _requiredDate(json['startTime'], 'startTime'),
    endTime: _optionalDate(json['endTime'], 'endTime'),
    createdAt: _optionalDate(json['createdAt'], 'createdAt') ?? DateTime(1970),
    updatedAt: _optionalDate(json['updatedAt'], 'updatedAt') ?? DateTime(1970),
  );

  Map<String, dynamic> toJson() => {
    'saleID': saleId,
    'productID': productId,
    'saleRule': saleRule,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class PromotionDraft {
  const PromotionDraft({
    required this.saleRule,
    required this.startTime,
    this.endTime,
    this.productId,
  });

  final String saleRule;
  final int? productId;
  final DateTime startTime;
  final DateTime? endTime;

  Map<String, String> validationErrors(CatalogSnapshot catalog) {
    final errors = <String, String>{};
    if (saleRule.trim().isEmpty) errors['saleRule'] = '请输入促销规则';
    if (productId != null && catalog.productById(productId!) == null) {
      errors['productID'] = '所选商品不存在';
    }
    if (endTime != null && !endTime!.isAfter(startTime)) {
      errors['endTime'] = '结束时间必须晚于开始时间';
    }
    return errors;
  }

  PromotionEvent toEvent(int id, DateTime createdAt, DateTime updatedAt) =>
      PromotionEvent(
        saleId: id,
        productId: productId,
        saleRule: saleRule.trim(),
        startTime: startTime,
        endTime: endTime,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class Advertisement {
  const Advertisement({
    required this.adId,
    required this.saleId,
    required this.startTime,
    required this.type,
    required this.img,
    required this.createdAt,
    required this.updatedAt,
    this.endTime,
  });

  final int adId;
  final int saleId;
  final DateTime startTime;
  final DateTime? endTime;
  final String type;
  final String img;
  final DateTime createdAt;
  final DateTime updatedAt;

  String statusAt(DateTime now) {
    if (startTime.isAfter(now)) return '未开始';
    if (endTime != null && endTime!.isBefore(now)) return '已结束';
    return '预览时段内';
  }

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    final img = json['img'];
    if (type != 'S' && type != 'L') {
      throw const FormatException('type 必须是 S 或 L');
    }
    if (img is! String || img.trim().isEmpty) {
      throw const FormatException('img 必须是非空字符串');
    }
    return Advertisement(
      adId: _requiredId(json['adID'], 'adID'),
      saleId: _requiredId(json['saleID'], 'saleID'),
      startTime: _requiredDate(json['startTime'], 'startTime'),
      endTime: _optionalDate(json['endTime'], 'endTime'),
      type: type as String,
      img: img,
      createdAt:
          _optionalDate(json['createdAt'], 'createdAt') ?? DateTime(1970),
      updatedAt:
          _optionalDate(json['updatedAt'], 'updatedAt') ?? DateTime(1970),
    );
  }

  Map<String, dynamic> toJson() => {
    'adID': adId,
    'saleID': saleId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'type': type,
    'img': img,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class AdvertisementDraft {
  const AdvertisementDraft({
    required this.saleId,
    required this.startTime,
    required this.type,
    required this.img,
    this.endTime,
  });

  final int saleId;
  final DateTime startTime;
  final DateTime? endTime;
  final String type;
  final String img;

  Map<String, String> validationErrors(MarketingSnapshot snapshot) {
    final errors = <String, String>{};
    final promotion = snapshot.promotionById(saleId);
    if (promotion == null) {
      errors['saleID'] = '关联促销不存在';
      return errors;
    }
    if (type != 'S' && type != 'L') errors['type'] = '广告尺寸必须是 S 或 L';
    if (img.trim().isEmpty) errors['img'] = '请选择演示图片';
    if (endTime != null && !endTime!.isAfter(startTime)) {
      errors['endTime'] = '结束时间必须晚于开始时间';
    }
    if (startTime.isBefore(promotion.startTime) ||
        (promotion.endTime != null && startTime.isAfter(promotion.endTime!)) ||
        (promotion.endTime != null && endTime == null) ||
        (endTime != null &&
            promotion.endTime != null &&
            endTime!.isAfter(promotion.endTime!))) {
      errors['period'] = '广告时段需包含在促销时段内';
    }
    return errors;
  }

  Advertisement toAdvertisement(
    int id,
    DateTime createdAt,
    DateTime updatedAt,
  ) => Advertisement(
    adId: id,
    saleId: saleId,
    startTime: startTime,
    endTime: endTime,
    type: type,
    img: img,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

class MarketingSnapshot {
  const MarketingSnapshot({
    this.promotions = const [],
    this.advertisements = const [],
  });

  final List<PromotionEvent> promotions;
  final List<Advertisement> advertisements;

  factory MarketingSnapshot.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('营销数据根节点必须是对象');
    final json = Map<String, dynamic>.from(decoded);
    final snapshot = MarketingSnapshot(
      promotions: _objects(
        json['promotions'],
        'promotions',
      ).map(PromotionEvent.fromJson).toList(growable: false),
      advertisements: _objects(
        json['advertisements'],
        'advertisements',
      ).map(Advertisement.fromJson).toList(growable: false),
    );
    if (snapshot.advertisements.any(
      (ad) => snapshot.promotionById(ad.saleId) == null,
    )) {
      throw const FormatException('广告引用的促销不存在');
    }
    return snapshot;
  }

  PromotionEvent? promotionById(int id) {
    for (final item in promotions) {
      if (item.saleId == id) return item;
    }
    return null;
  }

  List<Advertisement> adsFor(int saleId) =>
      advertisements.where((ad) => ad.saleId == saleId).toList(growable: false);

  MarketingSnapshot copyWith({
    List<PromotionEvent>? promotions,
    List<Advertisement>? advertisements,
  }) => MarketingSnapshot(
    promotions: promotions ?? this.promotions,
    advertisements: advertisements ?? this.advertisements,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'promotions': promotions.map((item) => item.toJson()).toList(),
    'advertisements': advertisements.map((item) => item.toJson()).toList(),
  };
}
