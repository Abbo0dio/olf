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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
