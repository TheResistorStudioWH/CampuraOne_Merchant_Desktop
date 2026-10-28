import 'dart:math' as math;

/// Local values used only by the on-stage visual analysis demonstration.
class VisionDemoModel {
  const VisionDemoModel({
    this.peopleInStore = 19,
    this.onlineOrders = 6,
    this.minutesPerOrder = 0.7,
  });

  final int peopleInStore;
  final int onlineOrders;
  final double minutesPerOrder;

  VisionDemoModel copyWith({
    int? peopleInStore,
    int? onlineOrders,
    double? minutesPerOrder,
  }) => VisionDemoModel(
    peopleInStore: peopleInStore ?? this.peopleInStore,
    onlineOrders: onlineOrders ?? this.onlineOrders,
    minutesPerOrder: minutesPerOrder ?? this.minutesPerOrder,
  );

  /// Scenario only: pending online orders plus one new order, one work station.
  /// Store occupancy is deliberately excluded: a person is not an order.
  double get onlineScenarioMinutes => (onlineOrders + 1) * minutesPerOrder;

  int get roundedScenarioMinutes => math.max(1, onlineScenarioMinutes.round());
}
