import UIKit
import Flutter
import UserNotifications

// MARK: - Native Liquid Glass Platform View
class NativeLiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeLiquidGlassView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class NativeLiquidGlassView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var _blurView: UIVisualEffectView
    private var _borderLayer: CALayer

    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        _view = UIView(frame: frame)

        // APPLE LIQUID GLASS - MINIMAL BLUR, MAXIMUM BRIGHTNESS
        // Apple's liquid glass uses very subtle blur, almost no blur at all
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)

        _blurView = UIVisualEffectView(effect: blurEffect)
        _blurView.frame = frame
        _blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Configure corner radius for pill shape
        let borderRadius = (args as? [String: Any])?["borderRadius"] as? Double ?? 32.0
        _blurView.layer.cornerRadius = CGFloat(borderRadius)
        _blurView.clipsToBounds = true

        // MINIMAL BORDER - Apple's liquid glass has almost no visible border
        _borderLayer = CALayer()
        _borderLayer.frame = _blurView.bounds
        _borderLayer.borderColor = UIColor(red: 0.36, green: 0.25, blue: 0.75, alpha: 0.25).cgColor // PURPLE
        _borderLayer.borderWidth = 0.8 // THICKER outline
        _borderLayer.cornerRadius = CGFloat(borderRadius)
        _blurView.layer.addSublayer(_borderLayer)

        // No highlights - completely flat, modern look

        _view.addSubview(_blurView)

        super.init()

        // Listen for frame changes to update border
        _view.addObserver(self, forKeyPath: "frame", options: .new, context: nil)
    }

    deinit {
        _view.removeObserver(self, forKeyPath: "frame")
    }

    func view() -> UIView {
        return _view
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "frame" {
            _borderLayer.frame = _blurView.bounds
        }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up notification center delegate for native notifications
    UNUserNotificationCenter.current().delegate = self

    // Initialize Screen Time platform channel
    setupScreenTimeChannel()

    // Initialize iOS Settings platform channel
    setupIOSSettingsChannel()

    // Initialize Native Liquid Glass method channel
    setupNativeLiquidGlass()

    print("📱 PUSHIN - Screen Time, iOS Settings, and Native Liquid Glass integration active")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: Deep Link Handling
  override func application(_ application: UIApplication,
                           open url: URL,
                           options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return handleDeepLink(url)
  }

  private func handleDeepLink(_ url: URL) -> Bool {
    print("🔗 Deep link received: \(url)")
    if url.scheme == "pushin" && url.host == "workout" {
      print("🏋️ Deep link to workout screen detected!")
      // Signal Flutter to navigate to workout screen
      guard let controller = window?.rootViewController as? FlutterViewController else {
        print("❌ Could not get Flutter view controller")
        return false
      }

      let channel = FlutterMethodChannel(name: "dev.pushin.screentime", binaryMessenger: controller.binaryMessenger)
      let source = url.query?.contains("source=shield") ?? false ? "shield" : "notification"
      channel.invokeMethod("navigateToWorkout", arguments: ["source": source])
      return true
    }
    return false
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

  private func setupIOSSettingsChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(name: "com.pushin.iossettings", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "setEmergencyUnlockEnabled":
        if let arguments = call.arguments as? [String: Any],
           let enabled = arguments["enabled"] as? Bool {
          self.saveEmergencyUnlockEnabled(enabled)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for setEmergencyUnlockEnabled", details: nil))
        }

      case "setEmergencyUnlockMinutes":
        if let arguments = call.arguments as? [String: Any],
           let minutes = arguments["minutes"] as? Int {
          self.saveEmergencyUnlockMinutes(minutes)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for setEmergencyUnlockMinutes", details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func saveEmergencyUnlockEnabled(_ enabled: Bool) {
    let appGroupSuiteName = "group.com.pushin.reload"
    if let store = UserDefaults(suiteName: appGroupSuiteName) {
      store.set(enabled, forKey: "emergency_unlock_enabled")
      store.synchronize()
      print("✅ Saved emergency unlock enabled to iOS UserDefaults: \(enabled)")
    } else {
      print("❌ Failed to access app group UserDefaults")
    }
  }

  private func saveEmergencyUnlockMinutes(_ minutes: Int) {
    let appGroupSuiteName = "group.com.pushin.reload"
    if let store = UserDefaults(suiteName: appGroupSuiteName) {
      store.set(minutes, forKey: "emergency_unlock_minutes")
      store.synchronize()
      print("✅ Saved emergency unlock minutes to iOS UserDefaults: \(minutes)")
    } else {
      print("❌ Failed to access app group UserDefaults")
    }
  }

  private func setupNativeLiquidGlass() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    // Set up method channel for native liquid glass
    let channel = FlutterMethodChannel(name: "com.pushin.native_liquid_glass", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "isSupported":
        // iOS supports native liquid glass
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Register platform view factory
    let factory = NativeLiquidGlassViewFactory(messenger: controller.binaryMessenger)
    controller.registrar(forPlugin: "com.pushin.native_liquid_glass")?.register(factory, withId: "native_liquid_glass")

    print("✨ Native Liquid Glass platform view and method channel registered")
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// Handle notification tap when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show notification even when app is in foreground
    print("🔔 Notification will present in foreground")
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  /// Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("🔔 Notification tapped!")

    let userInfo = response.notification.request.content.userInfo

    // Check if it's a workout notification with deep link
    if let deepLinkString = userInfo["deepLink"] as? String,
       let deepLinkURL = URL(string: deepLinkString) {
      print("🔗 Deep link found in notification: \(deepLinkString)")

      // Handle the deep link to navigate to workout
      _ = handleDeepLink(deepLinkURL)
    }

    completionHandler()
  }
}
