import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase/firebase_services.dart';
import 'push_service.dart';

/// FCM topics the app subscribes to when notifications are on.
/// Send campaigns to these from Firebase Console → Messaging.
class PushTopics {
  static const String all = 'all_players';
  static const String daily = 'daily_challenge';
}

/// Background/terminated message handler. Must be a top-level function.
/// Notification messages are displayed by the OS automatically; this only
/// needs Firebase to be initialised for data handling.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initializeFirebase();
}

/// Firebase Cloud Messaging + local notifications for foreground display.
///
/// Message format (data payload) understood by the app:
///   `screen: daily` → tapping opens the Daily Challenge screen.
class FcmPushService extends PushService {
  FcmPushService();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mind_tiles_general',
    'Game reminders',
    description: 'Daily challenge reminders and game news',
    importance: Importance.high,
  );

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  void Function(PushTarget target)? _onOpen;
  PushTarget? _pendingTarget;
  bool _initialised = false;

  @override
  set onOpen(void Function(PushTarget target)? callback) {
    _onOpen = callback;
    final pending = _pendingTarget;
    if (callback != null && pending != null) {
      _pendingTarget = null;
      callback(pending);
    }
  }

  static PushTarget _targetOf(Map<String, dynamic> data) =>
      data['screen'] == 'daily' ? PushTarget.daily : PushTarget.home;

  void _open(PushTarget t) {
    final cb = _onOpen;
    if (cb == null) {
      _pendingTarget = t; // app UI not ready yet (cold start)
    } else {
      cb(t);
    }
  }

  @override
  Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notify'),
          // Permission is requested by FCM in enable(), not at startup.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) =>
            _open(r.payload == 'daily' ? PushTarget.daily : PushTarget.home),
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      // iOS shows foreground notifications natively with these options.
      await _fm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _open(_targetOf(m.data)),
      );
      final initial = await _fm.getInitialMessage();
      if (initial != null) _open(_targetOf(initial.data));
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
  }

  /// Android does not display FCM notifications while the app is in the
  /// foreground, so mirror them as local notifications.
  Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null || !Platform.isAndroid) return;
    try {
      await _local.show(
        id: m.hashCode,
        title: n.title,
        body: n.body,
        payload: m.data['screen'] as String?,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_notify',
            color: const Color(0xFF5530A8),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Foreground notification failed: $e');
    }
  }

  @override
  Future<bool> enable() async {
    try {
      final settings = await _fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return false;
      await _fm.subscribeToTopic(PushTopics.all);
      await _fm.subscribeToTopic(PushTopics.daily);
      // In debug builds print the FCM token so a test message can be sent to
      // this device from Firebase Console → Messaging → "Send test message".
      if (kDebugMode) {
        debugPrint('[push] FCM token: ${await _fm.getToken()}');
      }
      return true;
    } catch (e) {
      // e.g. iOS simulator without APNs, or no network. Topics are retried
      // next launch because the setting stays on.
      debugPrint('Push enable failed: $e');
      return true;
    }
  }

  @override
  Future<void> disable() async {
    try {
      await _fm.unsubscribeFromTopic(PushTopics.all);
      await _fm.unsubscribeFromTopic(PushTopics.daily);
    } catch (e) {
      debugPrint('Push disable failed: $e');
    }
  }
}
