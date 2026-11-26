import UIKit
import Flutter
import BackgroundTasks
import CloudKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let SHARED_URL_CHANNEL = "com.reciperipper/shared_url"
  private let APP_GROUP_IDENTIFIER = "group.com.reciperipperapp"
  private let SHARED_URL_KEY = "SharedURL"
  private var sharedUrl: String?
  private var sharedUrlChannel: FlutterMethodChannel?
  private var incomingUrlHandler: IncomingUrlSceneHandler?
  private var speechRecognitionBridge: SpeechRecognitionBridge?
  private var visionOcrBridge: VisionOcrBridge?
  private var iCloudBridge: ICloudBridge?
  private var foundationModelsBridge: FoundationModelsBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // BGTaskScheduler requires registration before the app finishes launching.
    // The method channel is attached later in didInitializeImplicitFlutterEngine.
    BackgroundTaskBridge.shared.registerBackgroundTask()
    BackgroundTaskBridge.shared.requestNotificationPermission()

    // Check for URL shared via Share Extension on launch
    checkForSharedUrlFromExtension()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Under the UIScene lifecycle the window (and its FlutterViewController) is
  // created by the scene, after didFinishLaunching, so plugins and platform
  // channels are registered here instead of via window.rootViewController.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    BackgroundTaskBridge.shared.setup(with: messenger)

    // Set up method channel for shared URLs (Sprint 1)
    let channel = FlutterMethodChannel(
      name: SHARED_URL_CHANNEL,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
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
    sharedUrlChannel = channel

    // URL schemes and universal links now arrive through the scene, so listen
    // for them as a scene life-cycle delegate.
    let urlHandler = IncomingUrlSceneHandler(
      onUrl: { [weak self] url in self?.handleIncomingUrl(url) ?? false },
      onUserActivity: { [weak self] activity in self?.handleUserActivity(activity) ?? false }
    )
    engineBridge.pluginRegistry.registrar(forPlugin: "RecipeSlurpIncomingUrls")?
      .addSceneDelegate(urlHandler)
    incomingUrlHandler = urlHandler

    // Set up Sprint 2 platform channels
    speechRecognitionBridge = SpeechRecognitionBridge()
    speechRecognitionBridge?.setup(with: messenger)

    visionOcrBridge = VisionOcrBridge()
    visionOcrBridge?.setup(with: messenger)

    // Set up Sprint 5 iCloud sync
    iCloudBridge = ICloudBridge.shared
    iCloudBridge?.setup(with: messenger)

    // Set up Foundation Models bridge for on-device LLM
    let fmBridge = FoundationModelsBridge()
    fmBridge.setup(with: messenger)
    foundationModelsBridge = fmBridge
  }

  // MARK: - Incoming URLs

  /// Handle URL schemes (reciperipper://). Returns true if the URL was handled.
  private func handleIncomingUrl(_ url: URL) -> Bool {
    guard url.scheme == "reciperipper" else {
      return false
    }

    // Check if this is from the Share Extension
    if url.host == "shared" {
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

  /// Handle Universal Links (https://). Returns true if the activity was handled.
  private func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else {
      return false
    }
    sharedUrl = url.absoluteString
    notifyFlutterOfUrl(url.absoluteString)
    return true
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
    sharedUrlChannel?.invokeMethod("urlReceived", arguments: urlString)
  }
}

/// Receives URL and user-activity scene events (cold launch and while running)
/// and forwards them to the app delegate.
private final class IncomingUrlSceneHandler: NSObject, FlutterSceneLifeCycleDelegate {
  private let onUrl: (URL) -> Bool
  private let onUserActivity: (NSUserActivity) -> Bool

  init(onUrl: @escaping (URL) -> Bool, onUserActivity: @escaping (NSUserActivity) -> Bool) {
    self.onUrl = onUrl
    self.onUserActivity = onUserActivity
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let options = connectionOptions else { return false }
    for context in options.urlContexts {
      _ = onUrl(context.url)
    }
    for activity in options.userActivities {
      _ = onUserActivity(activity)
    }
    // Don't claim the connection so other plugins still see the launch options.
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in URLContexts where onUrl(context.url) {
      handled = true
    }
    return handled
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    return onUserActivity(userActivity)
  }
}
