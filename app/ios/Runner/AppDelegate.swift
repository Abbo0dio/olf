import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Opaque cover shown while the app is not active, so the iOS app-switcher
  /// snapshot never contains real content (p2.4). iOS has no FLAG_SECURE
  /// equivalent, so this native view is the reliable mitigation; the Flutter
  /// `PrivacyShield` is the cross-platform secondary.
  private var privacyCover: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // p1.7: let flutter_local_notifications present the daily reminder while the
    // app is in the foreground on iOS 10+.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // After super: the storyboard's FlutterViewController is up, so its
    // binaryMessenger is available for the p5.4 channel.
    registerAppIconChannel()
    return launched
  }

  // p5.4: `olf/app_icon` — `setIcon("branded" | "notes")` swaps the home-screen
  // icon via UIApplication.setAlternateIconName. iOS shows its own confirmation
  // alert and keeps the app running (no task kill, unlike Android). A no-op
  // where the OS reports no alternate-icon support.
  private func registerAppIconChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: "olf/app_icon",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(
          code: "unsupported",
          message: "This device does not support alternate app icons.",
          details: nil
        ))
        return
      }
      let id = call.arguments as? String
      let iconName: String?
      switch id {
      case "branded": iconName = nil // reset to the primary icon
      case "notes": iconName = "AppIconNotes"
      default:
        result(FlutterError(code: "bad_arg", message: "unknown icon id: \(id ?? "nil")", details: nil))
        return
      }
      UIApplication.shared.setAlternateIconName(iconName) { error in
        if let error = error {
          result(FlutterError(code: "switch_failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    showPrivacyCover()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    hidePrivacyCover()
  }

  private func showPrivacyCover() {
    guard privacyCover == nil, let window = window else { return }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = .systemBackground
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
    icon.tintColor = .secondaryLabel
    icon.translatesAutoresizingMaskIntoConstraints = false
    cover.addSubview(icon)
    NSLayoutConstraint.activate([
      icon.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: cover.centerYAnchor),
    ])

    window.addSubview(cover)
    privacyCover = cover
  }

  private func hidePrivacyCover() {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}
