/// Where a tapped notification should take the player.
enum PushTarget { home, daily }

/// Push-notification abstraction (Firebase Cloud Messaging in production).
abstract class PushService {
  const PushService();

  /// Sets up listeners. Does NOT request permission.
  Future<void> initialize();

  /// Requests OS permission and subscribes to reminder topics.
  /// Returns false if the player denied permission.
  Future<bool> enable();

  /// Unsubscribes from topics (permission stays as the OS has it).
  Future<void> disable();

  /// Called when the player opens the app from a notification.
  set onOpen(void Function(PushTarget target)? callback);
}

class DisabledPushService extends PushService {
  const DisabledPushService();

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> enable() async => false;
  @override
  Future<void> disable() async {}
  @override
  set onOpen(void Function(PushTarget target)? callback) {}
}
