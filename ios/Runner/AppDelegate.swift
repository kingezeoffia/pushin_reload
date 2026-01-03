import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Initialize Screen Time platform channel
    setupScreenTimeChannel()

    print("📱 PUSHIN - Screen Time integration active")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupScreenTimeChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(name: "dev.pushin.screentime", binaryMessenger: controller.binaryMessenger)

    if #available(iOS 15.0, *) {
      let handler = ScreenTimeChannelHandler()
      channel.setMethodCallHandler { (call, result) in
        handler.handle(call, result: result)
      }
    } else {
      // Screen Time APIs require iOS 15+
      channel.setMethodCallHandler { (call, result) in
        result(FlutterError(code: "UNSUPPORTED_OS", message: "Screen Time features require iOS 15.0 or later", details: nil))
      }
    }
  }
}
