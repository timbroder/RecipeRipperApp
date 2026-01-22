import Foundation
import Flutter
import BackgroundTasks
import UserNotifications

/// Bridge for iOS Background Tasks framework integration with Flutter
/// Handles scheduling and executing background video processing tasks
/// Note: BGTaskScheduler requires iOS 13+, version checks are done internally
class BackgroundTaskBridge: NSObject {
    private static let CHANNEL_NAME = "com.reciperipper/background_tasks"
    private static let TASK_IDENTIFIER = "com.reciperipper.videoProcessing"

    private var channel: FlutterMethodChannel?
    private var pendingJobs: [String: [String: Any]] = [:]

    /// Shared instance for accessing from AppDelegate
    static let shared = BackgroundTaskBridge()

    private override init() {
        super.init()
    }

    /// Check if background tasks are available (iOS 13+)
    private var isBackgroundTasksAvailable: Bool {
        if #available(iOS 13.0, *) {
            return true
        }
        return false
    }

    /// Set up the Flutter method channel
    func setup(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: BackgroundTaskBridge.CHANNEL_NAME,
            binaryMessenger: messenger
        )

        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }

    /// Register background task with the system - must be called before app finishes launching
    func registerBackgroundTask() {
        guard #available(iOS 13.0, *) else { return }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskBridge.TASK_IDENTIFIER,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundTask(task as! BGProcessingTask)
        }
    }

    /// Handle method calls from Flutter
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            // BGTaskScheduler is available on iOS 13+
            result(isBackgroundTasksAvailable)

        case "scheduleProcessing":
            guard let args = call.arguments as? [String: Any],
                  let jobId = args["jobId"] as? String,
                  let videoPath = args["videoPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT",
                                   message: "Missing required arguments",
                                   details: nil))
                return
            }

            let sourceUrl = args["sourceUrl"] as? String
            scheduleProcessing(jobId: jobId, videoPath: videoPath, sourceUrl: sourceUrl, result: result)

        case "cancelJob":
            guard let args = call.arguments as? [String: Any],
                  let jobId = args["jobId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT",
                                   message: "jobId is required",
                                   details: nil))
                return
            }

            cancelJob(jobId: jobId, result: result)

        case "cancelAllJobs":
            cancelAllJobs(result: result)

        case "getJobStatus":
            guard let args = call.arguments as? [String: Any],
                  let jobId = args["jobId"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT",
                                   message: "jobId is required",
                                   details: nil))
                return
            }

            getJobStatus(jobId: jobId, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Schedule a video processing task
    private func scheduleProcessing(jobId: String, videoPath: String, sourceUrl: String?, result: @escaping FlutterResult) {
        guard #available(iOS 13.0, *) else {
            result(FlutterError(code: "UNAVAILABLE",
                               message: "Background tasks require iOS 13+",
                               details: nil))
            return
        }

        // Store job info for when task runs
        pendingJobs[jobId] = [
            "jobId": jobId,
            "videoPath": videoPath,
            "sourceUrl": sourceUrl as Any
        ]

        // Create the background task request
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskBridge.TASK_IDENTIFIER)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        // Set earliest begin date to run as soon as possible
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1)

        do {
            try BGTaskScheduler.shared.submit(request)

            // Show notification that processing will continue in background
            showBackgroundNotification(
                title: "Processing Recipe",
                body: "Video processing will continue in the background."
            )

            result(true)
        } catch {
            print("BackgroundTaskBridge: Failed to schedule task - \(error)")
            result(FlutterError(code: "SCHEDULE_ERROR",
                               message: "Failed to schedule background task: \(error.localizedDescription)",
                               details: nil))
        }
    }

    /// Cancel a specific job
    private func cancelJob(jobId: String, result: @escaping FlutterResult) {
        pendingJobs.removeValue(forKey: jobId)
        // Note: BGTaskScheduler doesn't support canceling specific tasks by custom ID
        // We can only cancel all pending tasks of a given type
        result(true)
    }

    /// Cancel all pending jobs
    private func cancelAllJobs(result: @escaping FlutterResult) {
        pendingJobs.removeAll()
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.cancelAllTaskRequests()
        }
        result(true)
    }

    /// Get status of a job
    private func getJobStatus(jobId: String, result: @escaping FlutterResult) {
        if let job = pendingJobs[jobId] {
            result([
                "state": "ENQUEUED",
                "progress": 0
            ])
        } else {
            result(nil)
        }
    }

    /// Handle the background task when it runs
    @available(iOS 13.0, *)
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        // Set expiration handler
        task.expirationHandler = { [weak self] in
            self?.handleTaskExpiration(task)
        }

        // Get the first pending job
        guard let (jobId, jobInfo) = pendingJobs.first,
              let videoPath = jobInfo["videoPath"] as? String else {
            task.setTaskCompleted(success: true)
            return
        }

        let sourceUrl = jobInfo["sourceUrl"] as? String

        // Update notification
        showBackgroundNotification(
            title: "Processing Recipe",
            body: "Extracting recipe from video..."
        )

        // Call Flutter to process the video
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("processInBackground", arguments: [
                "jobId": jobId,
                "videoPath": videoPath,
                "sourceUrl": sourceUrl as Any
            ]) { result in
                // Remove from pending jobs
                self?.pendingJobs.removeValue(forKey: jobId)

                if let success = result as? Bool, success {
                    self?.showBackgroundNotification(
                        title: "Recipe Ready",
                        body: "Your recipe has been extracted successfully."
                    )
                    task.setTaskCompleted(success: true)
                } else {
                    self?.showBackgroundNotification(
                        title: "Processing Failed",
                        body: "There was an error processing the video."
                    )
                    task.setTaskCompleted(success: false)
                }

                // Schedule next task if there are more pending jobs
                if !(self?.pendingJobs.isEmpty ?? true) {
                    self?.scheduleNextTask()
                }
            }
        }
    }

    /// Handle task expiration
    @available(iOS 13.0, *)
    private func handleTaskExpiration(_ task: BGProcessingTask) {
        // Notify user that task was interrupted
        showBackgroundNotification(
            title: "Processing Paused",
            body: "Video processing will resume when possible."
        )

        // Reschedule the task
        scheduleNextTask()

        task.setTaskCompleted(success: false)
    }

    /// Schedule the next pending task
    @available(iOS 13.0, *)
    private func scheduleNextTask() {
        guard !pendingJobs.isEmpty else { return }

        let request = BGProcessingTaskRequest(identifier: BackgroundTaskBridge.TASK_IDENTIFIER)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Wait 1 minute before retrying

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BackgroundTaskBridge: Failed to reschedule task - \(error)")
        }
    }

    /// Show a local notification
    private func showBackgroundNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("BackgroundTaskBridge: Failed to show notification - \(error)")
            }
        }
    }

    /// Request notification permissions
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("BackgroundTaskBridge: Notification permission error - \(error)")
            }
        }
    }
}
