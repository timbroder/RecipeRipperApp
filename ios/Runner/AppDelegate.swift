import UIKit
import Flutter
import BackgroundTasks
import CloudKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let SHARED_URL_CHANNEL = "com.reciperipper/shared_url"
  private let APP_GROUP_IDENTIFIER = "group.com.reciperipperapp"
  private let SHARED_URL_KEY = "SharedURL"
  private var sharedUrl: String?
  private var speechRecognitionBridge: SpeechRecognitionBridge?
  private var visionOcrBridge: VisionOcrBridge?
  private var iCloudBridge: ICloudBridge?
  private var foundationModelsBridge: AnyObject?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController

    // Register background tasks before app finishes launching
    // Note: BackgroundTaskBridge internally checks for iOS 13+ availability
    BackgroundTaskBridge.shared.registerBackgroundTask()
    BackgroundTaskBridge.shared.setup(with: controller.binaryMessenger)
    BackgroundTaskBridge.shared.requestNotificationPermission()

    // Set up method channel for shared URLs (Sprint 1)
    let sharedUrlChannel = FlutterMethodChannel(
      name: SHARED_URL_CHANNEL,
      binaryMessenger: controller.binaryMessenger
    )

    sharedUrlChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getSharedUrl" {
        // First check App Groups for URL from Share Extension
        if let appGroupUrl = self?.getSharedUrlFromAppGroup() {
          result(appGroupUrl)
        } else if let url = self?.sharedUrl {
          result(url)
          self?.sharedUrl = nil  // Clear after retrieval
        } else {
          result(nil)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Check for URL shared via Share Extension on launch
    checkForSharedUrlFromExtension()

    // Set up Sprint 2 platform channels
    speechRecognitionBridge = SpeechRecognitionBridge()
    speechRecognitionBridge?.setup(with: controller.binaryMessenger)

    visionOcrBridge = VisionOcrBridge()
    visionOcrBridge?.setup(with: controller.binaryMessenger)

    // Set up Sprint 5 iCloud sync
    iCloudBridge = ICloudBridge.shared
    iCloudBridge?.setup(with: controller.binaryMessenger)

    // Set up Foundation Models bridge for on-device LLM
    if #available(iOS 26, *) {
      let bridge = FoundationModelsBridge()
      bridge.setup(with: controller.binaryMessenger)
      foundationModelsBridge = bridge
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle URL schemes (reciperipper://)
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // Check if this is from the Share Extension
    if url.scheme == "reciperipper" && url.host == "shared" {
      // Get URL from App Groups (set by Share Extension)
      if let appGroupUrl = getSharedUrlFromAppGroup() {
        sharedUrl = appGroupUrl
        notifyFlutterOfUrl(appGroupUrl)
      }
      return true
    }

    // Store the URL to be retrieved by Flutter
    sharedUrl = url.absoluteString
    notifyFlutterOfUrl(url.absoluteString)

    return true
  }

  // Handle Universal Links (https://)
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    // Handle universal links for web URLs
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      sharedUrl = url.absoluteString
      notifyFlutterOfUrl(url.absoluteString)
      return true
    }

    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  // MARK: - Share Extension Helpers

  /// Check for URL shared via Share Extension on app launch
  private func checkForSharedUrlFromExtension() {
    if let url = getSharedUrlFromAppGroup() {
      sharedUrl = url
    }
  }

  /// Retrieve and clear shared URL from App Groups
  private func getSharedUrlFromAppGroup() -> String? {
    guard let userDefaults = UserDefaults(suiteName: APP_GROUP_IDENTIFIER) else {
      return nil
    }

    guard let url = userDefaults.string(forKey: SHARED_URL_KEY) else {
      return nil
    }

    // Check if the URL is recent (within last 5 minutes) to avoid stale data
    if let timestamp = userDefaults.object(forKey: "SharedURLTimestamp") as? Date {
      let fiveMinutesAgo = Date().addingTimeInterval(-300)
      if timestamp < fiveMinutesAgo {
        // URL is stale, clear it
        userDefaults.removeObject(forKey: SHARED_URL_KEY)
        userDefaults.removeObject(forKey: "SharedURLTimestamp")
        userDefaults.synchronize()
        return nil
      }
    }

    // Clear the URL after retrieval
    userDefaults.removeObject(forKey: SHARED_URL_KEY)
    userDefaults.removeObject(forKey: "SharedURLTimestamp")
    userDefaults.synchronize()

    return url
  }

  /// Notify Flutter about a received URL
  private func notifyFlutterOfUrl(_ urlString: String) {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: SHARED_URL_CHANNEL,
        binaryMessenger: controller.binaryMessenger
      )
      channel.invokeMethod("urlReceived", arguments: urlString)
    }
  }
}
