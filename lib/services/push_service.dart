import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:resq/services/api_service.dart';

/// FCM's plugin requires the background handler to be a top-level (or
/// static) function, not a class method — it has to be reachable without an
/// app instance, since it can run in its own isolate while the app is fully
/// terminated. Must also be registered before runApp() in main.dart.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nothing to do here today — a background/terminated-state push with a
  // `notification` payload is displayed by Android/FCM automatically using
  // the default channel declared in AndroidManifest.xml. This handler only
  // needs to exist so Firebase has one registered; it's the place a future
  // data-only (silent) push would do background work.
}

/// Wraps Firebase Cloud Messaging + flutter_local_notifications: requests
/// permission, registers/refreshes this device's token with the backend
/// (see api_service.dart's registerDeviceToken), and shows/handles taps on
/// the four push types the backend sends (see notifications.service.js,
/// appointmentReminders.js, diditWebhook.controller.js, donors.controller.js
/// setDonorEligibility) — new blood request matches, appointment reminders,
/// verification status updates, and account/system notices.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Must match AndroidManifest.xml's default_notification_channel_id so a
  // background/terminated push and a foreground one land in the same place
  // instead of Android splitting them into two channels a donor could mute
  // independently without realizing it.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'resq_alerts_channel',
    'ResQ Alerts',
    description: 'Blood request matches, appointment reminders, verification and account updates.',
    importance: Importance.high,
  );

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// One-time app-wide setup: creates the Android notification channel,
  /// wires foreground-message display (Android doesn't show a system
  /// notification for foreground FCM messages on its own), and wires
  /// notification-tap handling for all three app states (foreground,
  /// backgrounded, launched-from-terminated). Call once from main.dart,
  /// after Firebase.initializeApp(). Safe to call more than once.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    if (_initialized) return;
    _initialized = true;

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/launcher_icon')),
      onDidReceiveNotificationResponse: (response) => _handleTapPayload(response.payload),
    );

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // App was backgrounded (not killed) and the donor tapped the system
    // notification to bring it back to the foreground.
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTapPayload(jsonEncode(message.data)));

    // App was fully terminated and the tap that opened it was a
    // notification tap — only checked once, right after init.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTapPayload(jsonEncode(initialMessage.data));
    }
  }

  void _handleTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      // Every push type currently just brings the donor back to HomeView —
      // it already re-fetches appointments/requests/profile in initState,
      // so whatever changed (a new match, a status flip) is fresh the
      // moment they land there. Routing each `type` to a specific
      // sub-screen (e.g. straight into the appointment tab for a reminder)
      // is a reasonable follow-up, not required for the notification to be
      // useful today.
      debugPrint('Push notification tapped: ${data['type']}');
      _navigatorKey?.currentState?.popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('PushService: could not parse notification payload: $e');
    }
  }

  /// Requests OS notification permission — only a real prompt on Android 13+
  /// (API 33), where POST_NOTIFICATIONS is required; granted automatically
  /// on older Android. Returns whether pushes are actually allowed.
  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Requests permission, fetches this device's FCM token, and registers it
  /// with the backend under the signed-in donor. Call once after login
  /// (see home_view.dart's initState) — a no-op if permission is denied or
  /// Firebase couldn't hand back a token (e.g. no Firebase project
  /// configured yet, see setup instructions).
  Future<void> registerDevice(String donorAuthToken) async {
    if (donorAuthToken.isEmpty) return;

    final granted = await _requestPermission();
    if (!granted) return;

    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken != null) {
        await ApiService.registerDeviceToken(donorAuthToken, fcmToken);
      }
    } catch (e) {
      // Firebase not configured for this build, or a network hiccup — push
      // is additive, so a failure here should never block sign-in.
      debugPrint('PushService: device registration failed: $e');
    }

    // Firebase can rotate a device's token (token expiry, app data
    // restored to a new device) — without this, a donor who's been signed
    // in for a while would silently stop receiving pushes once that
    // happens.
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      ApiService.registerDeviceToken(donorAuthToken, newToken).catchError((_) {});
    });
  }

  /// Call on sign-out so this device stops receiving pushes meant for the
  /// donor who just signed out of it.
  Future<void> unregisterDevice(String donorAuthToken) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken != null && donorAuthToken.isNotEmpty) {
        await ApiService.unregisterDeviceToken(donorAuthToken, fcmToken);
      }
    } catch (e) {
      debugPrint('PushService: device unregistration failed: $e');
    }
  }
}
