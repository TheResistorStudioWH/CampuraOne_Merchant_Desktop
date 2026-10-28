import 'package:campura_one_merchant/src/vision/vision_demo_model.dart';
import 'package:campura_one_merchant/src/vision/vision_demo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('店内人数不作为订单重复计入等待估算', () {
    const inputs = VisionDemoModel();
    expect(inputs.onlineScenarioMinutes, closeTo(4.9, 0.0001));
    expect(
      inputs.copyWith(peopleInStore: 80).onlineScenarioMinutes,
      closeTo(4.9, 0.0001),
    );
  });

  testWidgets('手动调整线上单数会更新等待估算', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VisionDemoApp());
    expect(find.byKey(const Key('vision-camera-placeholder')), findsOneWidget);
    expect(find.text('约 5 分钟'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vision-edit-线上单数')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('vision-manual-input')), '8');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(find.text('约 6 分钟'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vision-edit-店内人数')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('vision-manual-input')), '42');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(find.text('约 6 分钟'), findsOneWidget);
  });

  testWidgets('窄窗口仍可操作输入', (tester) async {
    tester.view.physicalSize = const Size(620, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VisionDemoApp());
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('vision-edit-每单时间')));
    await tester.tap(find.byKey(const Key('vision-edit-每单时间')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vision-manual-input')), findsOneWidget);
  });
}
