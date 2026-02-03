import UIKit
import Flutter
import UserNotifications
import StoreKit

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
    // Call super FIRST to ensure Flutter engine is initialized properly
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    GeneratedPluginRegistrant.register(with: self)

    // Set up notification center delegate for native notifications
    UNUserNotificationCenter.current().delegate = self

    // Ensure window is visible and Flutter view is ready
    // This helps ensure the launch screen is properly dismissed
    if let window = self.window {
      window.makeKeyAndVisible()
    }

    // Defer platform channel setup until the window and Flutter view controller are ready
    // This ensures the Flutter engine is fully initialized before we try to access it
    DispatchQueue.main.async { [weak self] in
      self?.setupPlatformChannels()
    }

    return result
  }

  /// Track if platform channels have been set up
  private var platformChannelsSetup = false
  
  /// Track if native liquid glass plugin has been registered
  private var nativeLiquidGlassRegistered = false

  /// Find Flutter view controller recursively (handles Mac Catalyst nested hierarchy)
  private func findFlutterViewController(in viewController: UIViewController?) -> FlutterViewController? {
    guard let vc = viewController else { return nil }
    
    // Check if this is the Flutter view controller
    if let flutterVC = vc as? FlutterViewController {
      return flutterVC
    }
    
    // Check child view controllers
    for child in vc.children {
      if let flutterVC = findFlutterViewController(in: child) {
        return flutterVC
      }
    }
    
    // Check presented view controller
    if let presented = vc.presentedViewController {
      if let flutterVC = findFlutterViewController(in: presented) {
        return flutterVC
      }
    }
    
    return nil
  }

  /// Set up all platform channels once the Flutter view controller is ready
  private func setupPlatformChannels() {
    guard !platformChannelsSetup else { return }
    
    // Try multiple times with increasing delays to ensure Flutter engine is ready
    var attempts = 0
    let maxAttempts = 15
    
    func trySetup() {
      attempts += 1
      
      // Try to find Flutter view controller (handles Mac Catalyst nested hierarchy)
      let controller = self.findFlutterViewController(in: self.window?.rootViewController)
      
      guard let flutterController = controller else {
        if attempts < maxAttempts {
          // Retry with exponential backoff
          let delay = min(0.1 * Double(attempts), 1.0)
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            trySetup()
          }
          if attempts % 3 == 0 {
            print("⚠️ Flutter view controller not ready yet (attempt \(attempts)/\(maxAttempts)), retrying...")
            // Debug: Print view hierarchy
            if let rootVC = self.window?.rootViewController {
              print("   Root VC: \(type(of: rootVC)), children: \(rootVC.children.count)")
            }
          }
        } else {
          print("⚠️ Flutter view controller not ready after \(maxAttempts) attempts - platform channels may not work")
          print("   This is expected on Mac Catalyst - platform channels will be set up when available")
        }
        return
      }
      
      // Success! Set up platform channels
      print("✅ Flutter view controller ready, setting up platform channels...")
      
      // Initialize Screen Time platform channel
      self.setupScreenTimeChannel(controller: flutterController)

      // Initialize iOS Settings platform channel
      self.setupIOSSettingsChannel(controller: flutterController)

      // Initialize Native Liquid Glass method channel
      self.setupNativeLiquidGlass(controller: flutterController)

      // Initialize Rating platform channel
      self.setupRatingChannel(controller: flutterController)

      self.platformChannelsSetup = true
      print("📱 PUSHIN - Screen Time, iOS Settings, Native Liquid Glass, and Rating integration active")
    }
    
    // Start trying immediately
    DispatchQueue.main.async {
      trySetup()
    }
  }

  /// Fallback: Set up platform channels when app becomes active (ensures window is ready)
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    
    // Retry setup if it hasn't been done yet
    if !platformChannelsSetup {
      print("🔄 App became active, retrying platform channel setup...")
      setupPlatformChannels()
    }
  }

  // MARK: Deep Link Handling
  override func application(_ application: UIApplication,
                           open url: URL,
                           options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("🔗 Deep link received: \(url)")
    print("🔗   scheme: \(url.scheme ?? "nil")")
    print("🔗   host: \(url.host ?? "nil")")

    // Handle workout deep links via method channel
    if handleWorkoutDeepLink(url) {
      return true
    }

    // For ALL other deep links (including pushinapp://payment-success),
    // let Flutter's app_links package handle them by calling super
    print("🔗 Forwarding to Flutter app_links: \(url)")
    return super.application(application, open: url, options: options)
  }

  /// Handle workout-specific deep links (pushin://workout)
  /// Returns true if handled, false otherwise
  private func handleWorkoutDeepLink(_ url: URL) -> Bool {
    if url.scheme == "pushin" && url.host == "workout" {
      print("🏋️ Deep link to workout screen detected!")
      guard let controller = findFlutterViewController(in: window?.rootViewController) else {
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

  /// Handle any deep link - for use from notification handlers
  private func handleDeepLink(_ url: URL) -> Bool {
    print("🔗 handleDeepLink called: \(url)")

    // Try workout deep link first
    if handleWorkoutDeepLink(url) {
      return true
    }

    // For other deep links, we can't easily forward to app_links from here,
    // but the notification scenario typically only needs workout links
    print("🔗 Non-workout deep link from notification: \(url)")
    return false
  }

  private func setupScreenTimeChannel(controller: FlutterViewController? = nil) {
    let flutterController = controller ?? findFlutterViewController(in: window?.rootViewController)
    guard let controller = flutterController else {
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

  private func setupIOSSettingsChannel(controller: FlutterViewController? = nil) {
    let flutterController = controller ?? findFlutterViewController(in: window?.rootViewController)
    guard let controller = flutterController else {
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

  private func setupNativeLiquidGlass(controller: FlutterViewController? = nil) {
    // Prevent duplicate registration
    guard !nativeLiquidGlassRegistered else {
      print("⚠️ Native Liquid Glass already registered, skipping duplicate registration")
      return
    }
    
    let flutterController = controller ?? findFlutterViewController(in: window?.rootViewController)
    guard let controller = flutterController else {
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
    
    // Mark as registered to prevent duplicates
    nativeLiquidGlassRegistered = true

    print("✨ Native Liquid Glass platform view and method channel registered")
  }

  private func setupRatingChannel(controller: FlutterViewController? = nil) {
    let flutterController = controller ?? findFlutterViewController(in: window?.rootViewController)
    guard let controller = flutterController else {
      return
    }

    let channel = FlutterMethodChannel(name: "pushin.app/rating", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "requestReview":
        // Request native iOS rating dialog
        if #available(iOS 14.0, *) {
          if let windowScene = self.window?.windowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            print("⭐ Requested native iOS rating dialog (iOS 14+)")
            result(true)
          } else {
            print("⚠️ Could not get window scene for rating")
            result(false)
          }
        } else {
          // iOS 13 and earlier
          SKStoreReviewController.requestReview()
          print("⭐ Requested native iOS rating dialog (iOS 13)")
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    print("✨ Rating method channel registered")
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
