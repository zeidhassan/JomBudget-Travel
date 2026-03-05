import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../ui/auth_screen.dart';
import '../ui/role_shell.dart';
import 'theme.dart';

class JomBudgetApp extends StatelessWidget {
  const JomBudgetApp({super.key, this.appState, this.enableCloudSync = false});

  final AppState? appState;
  final bool enableCloudSync;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) =>
          appState ?? AppState.seeded(enableCloudSync: enableCloudSync),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'JomBudget',
        theme: buildJomBudgetTheme(),
        home: const _HomeRouter(),
      ),
    );
  }
}

class _HomeRouter extends StatelessWidget {
  const _HomeRouter();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    if (user == null) {
      return const AuthScreen();
    }
    return const RoleShell();
  }
}
