import Foundation
import Flutter
import CloudKit

/// Bridge for iCloud sync functionality
class ICloudBridge: NSObject {
    static let shared = ICloudBridge()

    private let channelName = "com.reciperipperapp/icloud"
    private var channel: FlutterMethodChannel?

    // iCloud Drive container identifier - should match your app's bundle ID
    private let containerId = "iCloud.com.reciperipperapp"

    private override init() {
        super.init()
    }

    func setup(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: messenger
        )

        channel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            checkAvailability(result: result)

        case "getAccount":
            getAccountInfo(result: result)

        case "saveToICloud":
            guard let args = call.arguments as? [String: Any],
                  let filename = args["filename"] as? String,
                  let content = args["content"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "Missing filename or content",
                                   details: nil))
                return
            }
            saveToICloud(filename: filename, content: content, result: result)

        case "loadFromICloud":
            guard let args = call.arguments as? [String: Any],
                  let filename = args["filename"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "Missing filename",
                                   details: nil))
                return
            }
            loadFromICloud(filename: filename, result: result)

        case "deleteFromICloud":
            guard let args = call.arguments as? [String: Any],
                  let filename = args["filename"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "Missing filename",
                                   details: nil))
                return
            }
            deleteFromICloud(filename: filename, result: result)

        case "listFiles":
            listICloudFiles(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - iCloud Availability

    private func checkAvailability(result: @escaping FlutterResult) {
        if let containerUrl = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            result(true)
        } else {
            result(false)
        }
    }

    // MARK: - Account Info

    private func getAccountInfo(result: @escaping FlutterResult) {
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                var accountInfo: [String: Any] = [:]

                switch status {
                case .available:
                    accountInfo["isSignedIn"] = true
                    // Get user record ID for display name
                    CKContainer.default().fetchUserRecordID { recordID, error in
                        if let recordID = recordID {
                            accountInfo["email"] = recordID.recordName
                        }
                        result(accountInfo)
                    }
                    return

                case .noAccount:
                    accountInfo["isSignedIn"] = false
                    accountInfo["error"] = "No iCloud account"

                case .restricted:
                    accountInfo["isSignedIn"] = false
                    accountInfo["error"] = "iCloud access restricted"

                case .couldNotDetermine:
                    accountInfo["isSignedIn"] = false
                    accountInfo["error"] = "Could not determine iCloud status"

                case .temporarilyUnavailable:
                    accountInfo["isSignedIn"] = false
                    accountInfo["error"] = "iCloud temporarily unavailable"

                @unknown default:
                    accountInfo["isSignedIn"] = false
                    accountInfo["error"] = "Unknown iCloud status"
                }

                result(accountInfo)
            }
        }
    }

    // MARK: - File Operations

    private func getICloudDocumentsURL() -> URL? {
        guard let containerUrl = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        let documentsUrl = containerUrl.appendingPathComponent("Documents")

        // Create Documents directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: documentsUrl.path) {
            try? FileManager.default.createDirectory(at: documentsUrl, withIntermediateDirectories: true)
        }

        return documentsUrl
    }

    private func saveToICloud(filename: String, content: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let documentsUrl = self?.getICloudDocumentsURL() else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "UNAVAILABLE",
                                       message: "iCloud is not available",
                                       details: nil))
                }
                return
            }

            let fileUrl = documentsUrl.appendingPathComponent(filename)

            do {
                try content.write(to: fileUrl, atomically: true, encoding: .utf8)

                // Explicitly move file to iCloud
                try FileManager.default.startDownloadingUbiquitousItem(at: fileUrl)

                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SAVE_ERROR",
                                       message: "Failed to save to iCloud: \(error.localizedDescription)",
                                       details: nil))
                }
            }
        }
    }

    private func loadFromICloud(filename: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let documentsUrl = self?.getICloudDocumentsURL() else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "UNAVAILABLE",
                                       message: "iCloud is not available",
                                       details: nil))
                }
                return
            }

            let fileUrl = documentsUrl.appendingPathComponent(filename)

            // Try to download the file if it's in iCloud
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: fileUrl)
            } catch {
                // File might already be downloaded or doesn't exist
            }

            // Wait a bit for download to complete
            Thread.sleep(forTimeInterval: 0.5)

            // Check if file exists
            guard FileManager.default.fileExists(atPath: fileUrl.path) else {
                DispatchQueue.main.async {
                    result(nil) // File doesn't exist, return nil
                }
                return
            }

            do {
                let content = try String(contentsOf: fileUrl, encoding: .utf8)
                DispatchQueue.main.async {
                    result(content)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LOAD_ERROR",
                                       message: "Failed to load from iCloud: \(error.localizedDescription)",
                                       details: nil))
                }
            }
        }
    }

    private func deleteFromICloud(filename: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let documentsUrl = self?.getICloudDocumentsURL() else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "UNAVAILABLE",
                                       message: "iCloud is not available",
                                       details: nil))
                }
                return
            }

            let fileUrl = documentsUrl.appendingPathComponent(filename)

            do {
                if FileManager.default.fileExists(atPath: fileUrl.path) {
                    try FileManager.default.removeItem(at: fileUrl)
                }
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "DELETE_ERROR",
                                       message: "Failed to delete from iCloud: \(error.localizedDescription)",
                                       details: nil))
                }
            }
        }
    }

    private func listICloudFiles(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let documentsUrl = self?.getICloudDocumentsURL() else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "UNAVAILABLE",
                                       message: "iCloud is not available",
                                       details: nil))
                }
                return
            }

            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: documentsUrl,
                    includingPropertiesForKeys: [.nameKey, .fileSizeKey, .creationDateKey],
                    options: .skipsHiddenFiles
                )

                let files = contents.map { url -> [String: Any] in
                    var info: [String: Any] = ["name": url.lastPathComponent]
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
                        info["size"] = attributes[.size] as? Int ?? 0
                        if let date = attributes[.creationDate] as? Date {
                            info["createdAt"] = ISO8601DateFormatter().string(from: date)
                        }
                    }
                    return info
                }

                DispatchQueue.main.async {
                    result(files)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LIST_ERROR",
                                       message: "Failed to list iCloud files: \(error.localizedDescription)",
                                       details: nil))
                }
            }
        }
    }
}
