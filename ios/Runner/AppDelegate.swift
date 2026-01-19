import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private let SHARED_URL_CHANNEL = "com.reciperipper/shared_url"
  private var sharedUrl: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController

    // Set up method channel for shared URLs (Sprint 1)
    let sharedUrlChannel = FlutterMethodChannel(
      name: SHARED_URL_CHANNEL,
      binaryMessenger: controller.binaryMessenger
    )

    sharedUrlChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getSharedUrl" {
        if let url = self?.sharedUrl {
          result(url)
          self?.sharedUrl = nil  // Clear after retrieval
        } else {
          result(nil)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Platform channels will be set up here in future sprints
    // Sprint 2: Speech recognition channel
    // Sprint 2: OCR/Vision framework channel

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle URL schemes (reciperipper://)
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // Store the URL to be retrieved by Flutter
    sharedUrl = url.absoluteString

    // Notify Flutter that a URL was shared
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: SHARED_URL_CHANNEL,
        binaryMessenger: controller.binaryMessenger
      )
      channel.invokeMethod("urlReceived", arguments: url.absoluteString)
    }

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

      // Notify Flutter that a URL was shared
      if let controller = window?.rootViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(
          name: SHARED_URL_CHANNEL,
          binaryMessenger: controller.binaryMessenger
        )
        channel.invokeMethod("urlReceived", arguments: url.absoluteString)
      }

      return true
    }

    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}
