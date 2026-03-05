import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/models.dart';
import '../state/app_state.dart';
import 'admin_pages.dart';
import 'traveler_pages.dart';
import 'vendor_pages.dart';

class RoleShell extends StatelessWidget {
  const RoleShell({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppState state) => state.currentUser);
    if (user == null) {
      return const SizedBox.shrink();
    }

    return switch (user.role) {
      UserRole.traveler => const TravelerHomeScreen(),
      UserRole.vendor => const VendorHomeScreen(),
      UserRole.admin => const AdminHomeScreen(),
    };
  }
}
