import Flutter
import HealthKit
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
    registerHealthChannel()
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

  // p6.2: `olf/health` — a hand-rolled bridge to Apple HealthKit for the
  // opt-in "Connect Apple Health" feature. Mirrors the `core`
  // HealthPlatformGateway: isAvailable / requestAuthorization /
  // authorizationStatus / read / write / delete. Only two types are mapped —
  // `menstrualFlow` (HKCategoryType) and `basalBodyTemperature`
  // (HKQuantityType, °C). The channel speaks HealthKit-native numbers; olf's
  // Dart side owns the scale translation. Nothing here touches the network.
  private let healthBridge = HealthKitBridge()

  private func registerHealthChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let channel = FlutterMethodChannel(
      name: "olf/health",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [healthBridge] call, result in
      healthBridge.handle(call, result: result)
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

// MARK: - HealthKit bridge (p6.2)

/// Backs the `olf/health` method channel. Kept deliberately thin: it maps the
/// two shared data types to their HealthKit identifiers, marshals samples to
/// plain dictionaries, and lets olf's Dart side do every unit / scale decision.
final class HealthKitBridge {
  private let store = HKHealthStore()

  /// Wire tokens (the `core` HealthSampleType enum names) → HealthKit types.
  private var categoryType: HKCategoryType? {
    HKObjectType.categoryType(forIdentifier: .menstrualFlow)
  }
  private var quantityType: HKQuantityType? {
    HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)
  }

  private func sampleType(for token: String) -> HKSampleType? {
    switch token {
    case "menstrualFlow": return categoryType
    case "basalBodyTemperature": return quantityType
    default: return nil
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() || call.method == "isAvailable" else {
      result(FlutterError(code: "unavailable", message: "HealthKit is not available on this device.", details: nil))
      return
    }

    switch call.method {
    case "isAvailable":
      result(HKHealthStore.isHealthDataAvailable())

    case "requestAuthorization":
      let types = sampleTypes(from: call.arguments)
      guard !types.isEmpty else { result("denied"); return }
      let share = Set(types)
      let read = Set(types.map { $0 as HKObjectType })
      store.requestAuthorization(toShare: share, read: read) { ok, error in
        DispatchQueue.main.async {
          result(ok && error == nil ? "granted" : "denied")
        }
      }

    case "authorizationStatus":
      let types = sampleTypes(from: call.arguments)
      guard !types.isEmpty else { result("denied"); return }
      // HealthKit only reports share (write) status; read is opaque by design.
      let statuses = types.map { store.authorizationStatus(for: $0) }
      if statuses.contains(.sharingDenied) {
        result("denied")
      } else if statuses.allSatisfy({ $0 == .sharingAuthorized }) {
        result("granted")
      } else {
        result("notDetermined")
      }

    case "read":
      read(call.arguments, result: result)

    case "write":
      write(call.arguments, result: result)

    case "delete":
      delete(call.arguments, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: helpers

  private func sampleTypes(from arguments: Any?) -> [HKSampleType] {
    guard let map = arguments as? [String: Any],
          let tokens = map["types"] as? [String] else { return [] }
    return tokens.compactMap { sampleType(for: $0) }
  }

  private func dateRange(from map: [String: Any]) -> (Date, Date)? {
    guard let fromMs = map["fromMs"] as? NSNumber,
          let toMs = map["toMs"] as? NSNumber else { return nil }
    return (
      Date(timeIntervalSince1970: fromMs.doubleValue / 1000),
      Date(timeIntervalSince1970: toMs.doubleValue / 1000)
    )
  }

  private func ms(_ date: Date) -> Int { Int(date.timeIntervalSince1970 * 1000) }

  private func read(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let map = arguments as? [String: Any],
          let (start, end) = dateRange(from: map) else {
      result(FlutterError(code: "bad_arg", message: "read needs types + fromMs/toMs", details: nil))
      return
    }
    let types = sampleTypes(from: arguments)
    guard !types.isEmpty else { result([[String: Any]]()); return }

    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    let group = DispatchGroup()
    var rows: [[String: Any]] = []
    let lock = NSLock()

    for type in types {
      group.enter()
      let query = HKSampleQuery(
        sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
      ) { _, samples, _ in
        for sample in samples ?? [] {
          guard let row = self.row(for: sample) else { continue }
          lock.lock(); rows.append(row); lock.unlock()
        }
        group.leave()
      }
      store.execute(query)
    }

    group.notify(queue: .main) { result(rows) }
  }

  private func row(for sample: HKSample) -> [String: Any]? {
    let id = sample.sampleType.identifier
    if let category = sample as? HKCategorySample,
       id == HKCategoryTypeIdentifier.menstrualFlow.rawValue {
      return [
        "type": "menstrualFlow",
        "startMs": ms(category.startDate),
        "endMs": ms(category.endDate),
        "value": Double(category.value),
        "externalId": category.uuid.uuidString,
      ]
    }
    if let quantity = sample as? HKQuantitySample,
       id == HKQuantityTypeIdentifier.basalBodyTemperature.rawValue {
      return [
        "type": "basalBodyTemperature",
        "startMs": ms(quantity.startDate),
        "endMs": ms(quantity.endDate),
        "value": quantity.quantity.doubleValue(for: .degreeCelsius()),
        "externalId": quantity.uuid.uuidString,
      ]
    }
    return nil
  }

  private func write(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let map = arguments as? [String: Any],
          let raw = map["samples"] as? [[String: Any]] else {
      result(FlutterError(code: "bad_arg", message: "write needs samples", details: nil))
      return
    }

    var toSave: [HKObject] = []
    for entry in raw {
      guard let token = entry["type"] as? String,
            let startMs = entry["startMs"] as? NSNumber,
            let endMs = entry["endMs"] as? NSNumber,
            let value = entry["value"] as? NSNumber else { continue }
      let start = Date(timeIntervalSince1970: startMs.doubleValue / 1000)
      let end = Date(timeIntervalSince1970: endMs.doubleValue / 1000)

      switch token {
      case "menstrualFlow":
        if let type = categoryType {
          toSave.append(HKCategorySample(
            type: type, value: value.intValue, start: start, end: end
          ))
        }
      case "basalBodyTemperature":
        if let type = quantityType {
          let quantity = HKQuantity(unit: .degreeCelsius(), doubleValue: value.doubleValue)
          toSave.append(HKQuantitySample(type: type, quantity: quantity, start: start, end: end))
        }
      default:
        continue // an unmapped type — silent no-op, matches the Dart contract
      }
    }

    guard !toSave.isEmpty else { result(nil); return }
    store.save(toSave) { ok, error in
      DispatchQueue.main.async {
        if ok && error == nil {
          result(nil)
        } else {
          result(FlutterError(code: "write_failed", message: error?.localizedDescription, details: nil))
        }
      }
    }
  }

  private func delete(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let map = arguments as? [String: Any],
          let token = map["type"] as? String,
          let type = sampleType(for: token),
          let (start, end) = dateRange(from: map) else {
      result(nil) // unmapped type / bad args → no-op
      return
    }
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
    // Only olf-authored samples are deletable; HealthKit enforces that.
    store.deleteObjects(of: type, predicate: predicate) { _, _, _ in
      DispatchQueue.main.async { result(nil) }
    }
  }
}
