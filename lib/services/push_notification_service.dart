import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/models.dart';

class PushNotificationService {
  PushNotificationService({required this.enabled});

  final bool enabled;

  Future<void> initialize() async {
    if (!enabled) {
      return;
    }

    try {
      await FirebaseMessaging.instance.requestPermission();
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    } catch (_) {
      // Best-effort only. App should keep working without push setup.
    }
  }

  Future<void> subscribeToRole(UserRole role) async {
    if (!enabled) {
      return;
    }

    try {
      await FirebaseMessaging.instance.subscribeToTopic('role_${role.name}');
    } catch (_) {
      // Ignore to keep login flow resilient.
    }
  }

  Future<void> unsubscribeFromRole(UserRole role) async {
    if (!enabled) {
      return;
    }

    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(
        'role_${role.name}',
      );
    } catch (_) {
      // Ignore.
    }
  }
}
