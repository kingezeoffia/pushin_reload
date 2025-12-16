import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Screen Time integration disabled for MVP
    // App works perfectly with UX overlay fallback (100% user coverage)
    // To enable: Add ScreenTimeModule.swift to Xcode project + Family Controls capability
    print("📱 PUSHIN MVP - Running without Screen Time API (UX overlay active)")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
