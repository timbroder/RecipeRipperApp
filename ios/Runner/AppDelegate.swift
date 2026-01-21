import UIKit
import Flutter
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let SHARED_URL_CHANNEL = "com.reciperipper/shared_url"
  private var sharedUrl: String?
  private var speechRecognitionBridge: SpeechRecognitionBridge?
  private var visionOcrBridge: VisionOcrBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController

    // Register background tasks before app finishes launching
    if #available(iOS 13.0, *) {
      BackgroundTaskBridge.shared.registerBackgroundTask()
      BackgroundTaskBridge.shared.setup(with: controller.binaryMessenger)
      BackgroundTaskBridge.shared.requestNotificationPermission()
    }

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

    // Set up Sprint 2 platform channels
    speechRecognitionBridge = SpeechRecognitionBridge()
    speechRecognitionBridge?.setup(with: controller.binaryMessenger)

    visionOcrBridge = VisionOcrBridge()
    visionOcrBridge?.setup(with: controller.binaryMessenger)

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
