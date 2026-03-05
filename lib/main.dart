import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/runtime_config.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await initializeRuntimeConfig();
  final appState = await AppState.bootstrap(
    enableCloudSync: runtime.enableCloudSync,
  );
  runApp(JomBudgetApp(appState: appState));
}
