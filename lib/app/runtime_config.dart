import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class AppRuntimeConfig {
  const AppRuntimeConfig({required this.enableCloudSync});

  final bool enableCloudSync;
}

Future<AppRuntimeConfig> initializeRuntimeConfig() async {
  const shouldTryFirebase = bool.fromEnvironment(
    'USE_FIREBASE',
    defaultValue: false,
  );

  if (!shouldTryFirebase) {
    return const AppRuntimeConfig(enableCloudSync: false);
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return const AppRuntimeConfig(enableCloudSync: true);
  } catch (_) {
    return const AppRuntimeConfig(enableCloudSync: false);
  }
}
