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

    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      NSLog("SpendGuard notification permission granted: \(granted), error: \(String(describing: error))")
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }

        switch call.method {
        case "requestAlwaysPermission":
          self.requestAlwaysPermission()
          result(true)

        case "startProLocationMode":
          self.startProLocationMode()
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


  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  private func requestAlwaysPermission() {
    let status = locationManager.authorizationStatus
    if status == .notDetermined {
      locationManager.requestAlwaysAuthorization()
    } else if status == .authorizedWhenInUse {
      locationManager.requestAlwaysAuthorization()
    }
  }


  private func startProLocationMode() {
    requestAlwaysPermission()

    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 10
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false

    if CLLocationManager.significantLocationChangeMonitoringAvailable() {
      locationManager.startMonitoringSignificantLocationChanges()
    }

    locationManager.startMonitoringVisits()
    locationManager.startUpdatingLocation()

    NSLog("SpendGuard Pro Location Mode started")
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
    let clampedRadius = min(max(radius, 25.0), 60.0)
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


  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    NSLog("SpendGuard location authorization changed: \(status.rawValue)")

    if status == .authorizedAlways {
      manager.allowsBackgroundLocationUpdates = true
      manager.pausesLocationUpdatesAutomatically = false
      if CLLocationManager.significantLocationChangeMonitoringAvailable() {
        manager.startMonitoringSignificantLocationChanges()
      }
      manager.startMonitoringVisits()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let last = locations.last else { return }
    NSLog("SpendGuard native location update: \(last.coordinate.latitude), \(last.coordinate.longitude), accuracy \(last.horizontalAccuracy)")
  }

  func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
    NSLog("SpendGuard visit detected: \(visit.coordinate.latitude), \(visit.coordinate.longitude)")
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    guard region.identifier.hasPrefix("spendguard_store_") else { return }

    let storeName = displayName(from: region.identifier)
    let defaults = UserDefaults.standard

    defaults.set(storeName, forKey: "SpendGuardActiveStoreName")
    defaults.set(region.identifier, forKey: "SpendGuardActiveStoreId")

    sendSpendGuardNotification(
      title: "SpendGuard • \(storeName)",
      body: "You are inside \(storeName). Know before you buy.",
      key: "native_entry_\(region.identifier)"
    )
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    guard region.identifier.hasPrefix("spendguard_store_") else { return }

    let defaults = UserDefaults.standard
    let activeId = defaults.string(forKey: "SpendGuardActiveStoreId")
    let activeName = defaults.string(forKey: "SpendGuardActiveStoreName") ?? displayName(from: region.identifier)

    if activeId != nil && activeId != region.identifier {
      NSLog("SpendGuard ignored exit for non-active store: \(region.identifier)")
      return
    }

    sendSpendGuardNotification(
      title: "SpendGuard • Exit",
      body: "You left \(activeName). Your future is still protected.",
      key: "native_exit_\(region.identifier)"
    )

    defaults.removeObject(forKey: "SpendGuardActiveStoreName")
    defaults.removeObject(forKey: "SpendGuardActiveStoreId")
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
