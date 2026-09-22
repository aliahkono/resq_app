import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:resq/services/push_service.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/splash/splashscreen.dart';

// Shared by every screen that needs to navigate without a BuildContext —
// today, just PushService reacting to a notification tap while the app was
// backgrounded or freshly launched from a killed state.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🔴 FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('🔴 STACK: ${details.stack}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            'ERROR:\n${details.exception}\n\n${details.stack}',
            style: const TextStyle(color: Colors.red, fontSize: 11),
          ),
        ),
      ),
    );
  };

  WidgetsFlutterBinding.ensureInitialized();

  // Push notifications are additive — a device/build without a Firebase
  // project configured yet (see google-services.json setup instructions)
  // should still boot into a working app, just without push. initializeApp
  // throws when google-services.json is missing/malformed, so this is
  // caught rather than left to crash startup.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushService.instance.init(navigatorKey);
  } catch (e) {
    debugPrint('Firebase/push init skipped: $e');
  }

  runApp(const ResQApp());
}

class ResQApp extends StatelessWidget {
  const ResQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ResQ',
      theme: ResQTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}