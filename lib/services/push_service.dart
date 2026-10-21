import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
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

  // Looked up only when actually needed, never while this singleton is being
  // built. Touching FirebaseMessaging.instance before Firebase.initializeApp()
  // has succeeded throws [core/no-app] — which is exactly what happens on a
  // build without google-services.json — and used to crash HomeView the
  // moment it called PushService.instance.registerDevice().
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// True only once Firebase.initializeApp() has actually succeeded (see
  /// main.dart). Every public method checks this first, so push quietly
  /// does nothing on a build with no Firebase project instead of throwing.
  bool get _firebaseReady => Firebase.apps.isNotEmpty;
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

  // Opens the notifications page (BroadcastsView). Only HomeView has the
  // donor details that page needs, so HomeView supplies this while it's
  // mounted (see setNotificationsOpener).
  VoidCallback? _openNotifications;

  // A tap that arrived before any donor was on Home — e.g. the app was
  // launched from a killed state by the tap and is still on splash/login.
  // Consumed as soon as HomeView registers its opener.
  bool _pendingOpenNotifications = false;

  /// Called by HomeView once it's ready. If a notification was tapped
  /// before Home existed, opens it right away.
  void setNotificationsOpener(VoidCallback opener) {
    _openNotifications = opener;
    if (_pendingOpenNotifications) {
      _pendingOpenNotifications = false;
      opener();
    }
  }

  /// Called by HomeView on dispose. Only clears [opener] if it's still the
  /// current one, so an old HomeView being torn down after a re-login
  /// doesn't remove the new one's.
  void clearNotificationsOpener(VoidCallback opener) {
    if (_openNotifications == opener) _openNotifications = null;
  }

  /// One-time app-wide setup: creates the Android notification channel,
  /// wires foreground-message display (Android doesn't show a system
  /// notification for foreground FCM messages on its own), and wires
  /// notification-tap handling for all three app states (foreground,
  /// backgrounded, launched-from-terminated). Call once from main.dart,
  /// after Firebase.initializeApp(). Safe to call more than once.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    if (_initialized || !_firebaseReady) return;
    _initialized = true;

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // iOS/macOS settings are required on those platforms — without them
    // initialize() throws and none of the listeners below get wired. The
    // permission prompt is left to FCM's requestPermission in
    // registerDevice, so it isn't shown here at app launch.
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (response) => _handleTapPayload(response.payload),
    );

    // iOS drops a push that arrives while the app is open unless told to
    // show it, so iOS shows the banner itself (and handles its tap through
    // onMessageOpenedApp below). Android never shows one for an open app,
    // so there the push is re-shown as a local notification instead —
    // doing that on iOS as well would show every banner twice.
    await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null || Platform.isIOS) return;
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
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // App was backgrounded (not killed) and the donor tapped the system
    // notification to bring it back to the foreground.
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTapPayload(jsonEncode(message.data)));

    // App was fully terminated and the tap that opened it was a
    // notification tap — only checked once, right after init. Not awaited:
    // init() runs before runApp(), and on iOS with the UIScene lifecycle
    // getInitialMessage() can never complete, which left the app stuck on
    // a white screen. The timeout just stops the future from lingering.
    unawaited(_messaging
        .getInitialMessage()
        .timeout(const Duration(seconds: 5), onTimeout: () => null)
        .then((initialMessage) {
      if (initialMessage != null) {
        _handleTapPayload(jsonEncode(initialMessage.data));
      }
    }).catchError((Object e) {
      debugPrint('PushService: getInitialMessage failed: $e');
    }));
  }

  void _handleTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      // Every push type opens the notifications page, on top of HomeView
      // (always the root route once a donor is signed in — login pushes it
      // with pushAndRemoveUntil). If Home isn't up yet, the tap is held
      // until it is.
      debugPrint('Push notification tapped: ${data['type']}');
      final opener = _openNotifications;
      if (opener == null) {
        _pendingOpenNotifications = true;
        return;
      }
      _navigatorKey?.currentState?.popUntil((route) => route.isFirst);
      opener();
    } catch (e) {
      debugPrint('PushService: could not parse notification payload: $e');
    }
  }

  /// Whether the OS currently lets ResQ show notifications. Works without
  /// Firebase (reads the platform setting through flutter_local_notifications).
  Future<bool> areNotificationsAllowed() async {
    try {
      if (Platform.isAndroid) {
        final android = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      }
      if (Platform.isIOS) {
        final ios = _localNotifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        final options = await ios?.checkPermissions();
        return options?.isEnabled ?? false;
      }
    } catch (e) {
      debugPrint('PushService: could not read notification permission: $e');
    }
    return false;
  }

  /// Shows the OS "Allow ResQ to send you notifications?" prompt (Android
  /// 13+ and iOS; older Android allows notifications by default). Returns
  /// whether notifications are allowed afterwards. Doesn't need Firebase, so
  /// the Settings toggle works even on a build without push configured.
  Future<bool> requestOsPermission() async {
    try {
      if (Platform.isAndroid) {
        final android = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? await areNotificationsAllowed();
      }
      if (Platform.isIOS) {
        final ios = _localNotifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        final granted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('PushService: notification permission prompt failed: $e');
    }
    return false;
  }

  /// Requests OS notification permission — only a real prompt on Android 13+
  /// (API 33), where POST_NOTIFICATIONS is required; granted automatically
  /// on older Android. Returns whether pushes are actually allowed, or
  /// false if Firebase itself isn't usable (no GoogleService-Info.plist /
  /// google-services.json for this build) rather than letting that throw.
  Future<bool> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('PushService: notification permission request failed: $e');
      return false;
    }
  }

  /// Requests permission, fetches this device's FCM token, and registers it
  /// with the backend under the signed-in donor. Call once after login
  /// (see home_view.dart's initState) — a no-op if permission is denied or
  /// Firebase couldn't hand back a token (e.g. no Firebase project
  /// configured yet, see setup instructions). The whole body is one big
  /// try/catch, not just the token-fetch part — _requestPermission already
  /// guards itself, but Firebase being unconfigured can surface at any of
  /// these calls depending on platform, and push registration should never
  /// be able to break sign-in.
  // Stored on the backend's donor_devices.platform (which defaults to android).
  String get _platformName => Platform.isIOS ? 'ios' : 'android';

  Future<void> registerDevice(String donorAuthToken) async {
    if (donorAuthToken.isEmpty || !_firebaseReady) return;

    try {
      final granted = await _requestPermission();
      if (!granted) return;

      // On iOS, FCM's getToken() requires an APNs token to already be
      // registered with the OS, but that arrives asynchronously right after
      // permission is granted — calling getToken() immediately can race
      // ahead of it and throw apns-token-not-set. Give it a few short
      // retries before giving up, since on a fresh permission grant it's
      // often just not there *yet* rather than never coming.
      if (Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        var attempts = 0;
        while (apnsToken == null && attempts < 5) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await _messaging.getAPNSToken();
          attempts++;
        }
        if (apnsToken == null) {
          // Still not set after retrying — this almost always means the
          // Push Notifications capability isn't enabled for this build
          // (that capability requires a paid Apple Developer Program
          // account; a free/Personal Team signing can't add it), not a
          // transient timing issue. Calling getToken() now would just
          // throw the same error again, so stop here rather than spamming
          // it — push stays silently unavailable on this build until a
          // paid-account build re-signs with that capability turned on.
          debugPrint('PushService: no APNs token after retrying — Push Notifications capability is likely not enabled for this build.');
          return;
        }
      }

      final fcmToken = await _messaging.getToken();
      if (fcmToken != null) {
        await ApiService.registerDeviceToken(donorAuthToken, fcmToken, platform: _platformName);
      }

      // Firebase can rotate a device's token (token expiry, app data
      // restored to a new device) — without this, a donor who's been
      // signed in for a while would silently stop receiving pushes once
      // that happens.
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
        ApiService.registerDeviceToken(donorAuthToken, newToken, platform: _platformName).catchError((_) {});
      });
    } catch (e) {
      // Firebase not configured for this build, or a network hiccup — push
      // is additive, so a failure here should never block sign-in.
      debugPrint('PushService: device registration failed: $e');
    }
  }

  /// Call on sign-out so this device stops receiving pushes meant for the
  /// donor who just signed out of it.
  Future<void> unregisterDevice(String donorAuthToken) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (!_firebaseReady) return;
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