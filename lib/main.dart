import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/splash/splashscreen.dart';

void main() {
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

  runApp(const ResQApp());
}

class ResQApp extends StatelessWidget {
  const ResQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQ',
      theme: ResQTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}