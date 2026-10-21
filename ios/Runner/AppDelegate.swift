import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // With the implicit engine, plugins register after launch, so
    // firebase_messaging never gets to request an APNs token itself.
    application.registerForRemoteNotifications()
    // Makes this app delegate iOS's notification handler, so a push that
    // arrives while the app is open reaches the plugins (firebase_messaging
    // and flutter_local_notifications) and can be shown as a banner.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
