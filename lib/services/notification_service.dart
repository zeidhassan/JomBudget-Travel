import 'package:uuid/uuid.dart';

import '../data/in_memory_repositories.dart';
import '../domain/models.dart';

class NotificationService {
  NotificationService(this._notificationRepository);

  final NotificationRepository _notificationRepository;
  final Uuid _uuid = const Uuid();

  void notifyUser({
    required String userId,
    required String title,
    required String body,
  }) {
    _notificationRepository.add(
      NotificationItem(
        id: _uuid.v4(),
        userId: userId,
        title: title,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
  }

  List<NotificationItem> notificationsForUser(String userId) {
    return _notificationRepository.byUser(userId);
  }

  void markAsRead(NotificationItem notification) {
    _notificationRepository.update(notification.copyWith(isRead: true));
  }
}
