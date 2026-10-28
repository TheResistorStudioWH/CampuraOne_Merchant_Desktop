import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/data/repositories.dart';
import 'src/state/app_state.dart';
import 'src/vision/vision_demo_window.dart';
import 'src/vision/vision_window_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    final currentWindow = await WindowController.fromCurrentEngine();
    if (currentWindow.arguments == VisionWindowService.windowArgument) {
      runApp(const VisionDemoApp());
      return;
    }
  }
  final supportDirectory = await getApplicationSupportDirectory();
  final authRepository = LocalAuthRepository(
    supportDirectory: supportDirectory,
  );
  final catalogRepository = LocalCatalogRepository(
    supportDirectory: supportDirectory,
    seedLoader: () => rootBundle.loadString('assets/demo/catalog_seed.json'),
  );
  final appearanceRepository = LocalAppearanceRepository(
    supportDirectory: supportDirectory,
  );
  final marketingRepository = LocalMarketingRepository(
    supportDirectory: supportDirectory,
  );

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        catalogRepositoryProvider.overrideWithValue(catalogRepository),
        appearanceRepositoryProvider.overrideWithValue(appearanceRepository),
        marketingRepositoryProvider.overrideWithValue(marketingRepository),
      ],
      child: const MerchantApp(),
    ),
  );
  if (Platform.isWindows) {
    try {
      await VisionWindowService.instance.initializeTray();
    } catch (error) {
      debugPrint('视觉分析状态图标初始化失败：$error');
    }
  }
}
