import UIKit
import Flutter
import CoreLocation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private let channelName = "spendguard/native_geofence"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    locationManager.delegate = self
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }

        switch call.method {
        case "requestAlwaysPermission":
          self.requestAlwaysPermission()
          result(true)

        case "startMonitoringStore":
          guard let args = call.arguments as? [String: Any],
                let name = args["name"] as? String,
                let lat = args["lat"] as? Double,
                let lng = args["lng"] as? Double else {
            result(FlutterError(code: "BAD_ARGS", message: "Missing store geofence args", details: nil))
            return
          }

          let radius = args["radius"] as? Double ?? 60.0
          self.startMonitoringStore(name: name, lat: lat, lng: lng, radius: radius)
          result(true)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func requestAlwaysPermission() {
    let status = locationManager.authorizationStatus
    if status == .notDetermined {
      locationManager.requestAlwaysAuthorization()
    } else if status == .authorizedWhenInUse {
      locationManager.requestAlwaysAuthorization()
    }
  }

  private func startMonitoringStore(name: String, lat: Double, lng: Double, radius: Double) {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }

    requestAlwaysPermission()

    let safeName = name
      .lowercased()
      .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

    let identifier = "spendguard_store_\(safeName)"
    let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
    let clampedRadius = min(max(radius, 35.0), 120.0)
    let region = CLCircularRegion(center: center, radius: clampedRadius, identifier: identifier)
    region.notifyOnEntry = true
    region.notifyOnExit = true

    // iOS allows about 20 monitored regions per app. Keep the newest store and remove
    // the oldest SpendGuard store regions if we are close to the limit.
    let spendGuardRegions = locationManager.monitoredRegions.filter { $0.identifier.hasPrefix("spendguard_store_") }
    if spendGuardRegions.count >= 18 {
      for old in spendGuardRegions.prefix(spendGuardRegions.count - 17) {
        locationManager.stopMonitoring(for: old)
      }
    }

    for old in locationManager.monitoredRegions where old.identifier == identifier {
      locationManager.stopMonitoring(for: old)
    }

    locationManager.startMonitoring(for: region)
    locationManager.requestState(for: region)
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    guard region.identifier.hasPrefix("spendguard_store_") else { return }
    let storeName = displayName(from: region.identifier)
    sendSpendGuardNotification(
      title: "SpendGuard • \(storeName)",
      body: "You are inside \(storeName). Know before you buy.",
      key: "native_entry_\(region.identifier)"
    )
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    guard region.identifier.hasPrefix("spendguard_store_") else { return }
    let storeName = displayName(from: region.identifier)
    sendSpendGuardNotification(
      title: "SpendGuard • Exit",
      body: "You left \(storeName). Your future is still protected.",
      key: "native_exit_\(region.identifier)"
    )
  }

  func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
    // Do not notify here. This callback is used only to let iOS evaluate the region.
  }

  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    NSLog("SpendGuard geofence monitoring failed: \(error.localizedDescription)")
  }

  private func displayName(from identifier: String) -> String {
    let raw = identifier.replacingOccurrences(of: "spendguard_store_", with: "")
    let words = raw.split(separator: "_").map { part -> String in
      let lower = String(part)
      return lower.prefix(1).uppercased() + lower.dropFirst()
    }
    return words.joined(separator: " ")
  }

  private func sendSpendGuardNotification(title: String, body: String, key: String) {
    let defaults = UserDefaults.standard
    let now = Date().timeIntervalSince1970
    let lastKey = defaults.string(forKey: "SpendGuardNativeLastNotificationKey")
    let lastAt = defaults.double(forKey: "SpendGuardNativeLastNotificationAt")

    if lastKey == key && now - lastAt < 60 {
      return
    }

    defaults.set(key, forKey: "SpendGuardNativeLastNotificationKey")
    defaults.set(now, forKey: "SpendGuardNativeLastNotificationAt")

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.badge = 1
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .timeSensitive
    }

    let request = UNNotificationRequest(
      identifier: "\(key)_\(Int(now))",
      content: content,
      trigger: nil
    )

    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }
}
