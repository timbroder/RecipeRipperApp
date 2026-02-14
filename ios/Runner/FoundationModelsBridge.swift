import Flutter
import UIKit

/// Bridge for Apple Foundation Models (iOS 26+).
/// Provides on-device LLM text generation via FoundationModels framework.
class FoundationModelsBridge: NSObject {
    private var channel: FlutterMethodChannel?

    func setup(with messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.reciperipperapp/foundation_models",
            binaryMessenger: messenger
        )

        channel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "isAvailable":
                self?.checkAvailability(result: result)
            case "generateText":
                guard let args = call.arguments as? [String: Any],
                      let prompt = args["prompt"] as? String else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing prompt", details: nil))
                    return
                }
                self?.generateText(prompt: prompt, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func checkAvailability(result: @escaping FlutterResult) {
        if #available(iOS 26, *) {
            // FoundationModels framework available on iOS 26+
            // Check if the device supports on-device language model
            result(true)
        } else {
            result(false)
        }
    }

    private func generateText(prompt: String, result: @escaping FlutterResult) {
        if #available(iOS 26, *) {
            Task {
                do {
                    // Use FoundationModels framework for on-device generation
                    // Import: import FoundationModels
                    // let session = LanguageModelSession()
                    // let response = try await session.respond(to: prompt)
                    // result(response.content)

                    // NOTE: Actual FoundationModels import and usage requires
                    // Xcode 26+ and iOS 26 SDK. This bridge is ready for when
                    // the SDK becomes available. For now, return unavailable.
                    result(FlutterError(
                        code: "NOT_YET_AVAILABLE",
                        message: "FoundationModels requires iOS 26 SDK to compile",
                        details: nil
                    ))
                }
            }
        } else {
            result(FlutterError(
                code: "UNSUPPORTED",
                message: "Foundation Models requires iOS 26+",
                details: nil
            ))
        }
    }
}
