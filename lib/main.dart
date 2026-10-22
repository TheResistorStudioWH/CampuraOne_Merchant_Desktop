import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/data/repositories.dart';
import 'src/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
}
