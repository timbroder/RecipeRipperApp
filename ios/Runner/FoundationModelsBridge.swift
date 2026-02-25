import Flutter
import UIKit
import FoundationModels

/// Bridge for Apple Foundation Models.
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
                let instructions = args["instructions"] as? String
                self?.generateText(prompt: prompt, instructions: instructions, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func checkAvailability(result: @escaping FlutterResult) {
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            result(["available": true])
        case .unavailable(.deviceNotEligible):
            result(["available": false, "reason": "deviceNotEligible"])
        case .unavailable(.appleIntelligenceNotEnabled):
            result(["available": false, "reason": "appleIntelligenceNotEnabled"])
        case .unavailable(.modelNotReady):
            result(["available": false, "reason": "modelNotReady"])
        @unknown default:
            result(["available": false, "reason": "unknown"])
        }
    }

    private func generateText(prompt: String, instructions: String?, result: @escaping FlutterResult) {
        Task {
            do {
                let session: LanguageModelSession
                if let instructions = instructions {
                    session = LanguageModelSession(instructions: instructions)
                } else {
                    session = LanguageModelSession()
                }

                let response = try await session.respond(to: prompt)
                result(response.content)
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .exceededContextWindowSize:
                    result(FlutterError(
                        code: "CONTEXT_OVERFLOW",
                        message: "Input exceeded the model's context window size",
                        details: nil
                    ))
                case .guardrailViolation:
                    result(FlutterError(
                        code: "GUARDRAIL",
                        message: "Content was blocked by safety guardrails",
                        details: nil
                    ))
                @unknown default:
                    result(FlutterError(
                        code: "GENERATION_ERROR",
                        message: "Generation failed: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            } catch {
                result(FlutterError(
                    code: "GENERATION_ERROR",
                    message: "Generation failed: \(error.localizedDescription)",
                    details: nil
                ))
            }
        }
    }
}
