import UIKit
import Flutter
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Register the headless task for background updates
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      // Add any necessary plugins for the background task
      // registry.register(with: registry.registrar(forPlugin: "PluginName"))
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
