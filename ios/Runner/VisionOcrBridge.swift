import Flutter
import Vision
import UIKit

/// Bridge between Flutter and iOS Vision framework for OCR
class VisionOcrBridge: NSObject {
    private var channel: FlutterMethodChannel?

    /// Initialize the bridge with Flutter method channel
    func setup(with binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.reciperipperapp/vision_ocr",
            binaryMessenger: binaryMessenger
        )

        channel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call: call, result: result)
        }
    }

    /// Handle method calls from Flutter
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "recognizeText":
            guard let args = call.arguments as? [String: Any],
                  let imagePath = args["imagePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing imagePath", details: nil))
                return
            }
            recognizeText(imagePath: imagePath, result: result)
        case "recognizeTextBatch":
            guard let args = call.arguments as? [String: Any],
                  let imagePaths = args["imagePaths"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing imagePaths", details: nil))
                return
            }
            recognizeTextBatch(imagePaths: imagePaths, result: result)
        case "isAvailable":
            result(true) // Vision framework is always available on iOS 13+
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Recognize text from a single image
    private func recognizeText(imagePath: String, result: @escaping FlutterResult) {
        // Load image
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            result(FlutterError(
                code: "INVALID_IMAGE",
                message: "Failed to load image from path: \(imagePath)",
                details: nil
            ))
            return
        }

        // Create text recognition request
        let request = VNRecognizeTextRequest { vnRequest, error in
            if let error = error {
                result(FlutterError(
                    code: "RECOGNITION_ERROR",
                    message: "OCR failed: \(error.localizedDescription)",
                    details: nil
                ))
                return
            }

            guard let observations = vnRequest.results as? [VNRecognizedTextObservation] else {
                result(["text": "", "confidence": 0.0])
                return
            }

            // Extract text from observations
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            let text = recognizedStrings.joined(separator: "\n")
            let averageConfidence = observations.isEmpty ? 0.0 :
                observations.reduce(0.0) { sum, obs in
                    sum + Double(obs.topCandidates(1).first?.confidence ?? 0.0)
                } / Double(observations.count)

            result([
                "text": text,
                "confidence": averageConfidence,
            ])
        }

        // Configure request for best accuracy
        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        // Perform request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            result(FlutterError(
                code: "HANDLER_ERROR",
                message: "Failed to perform OCR: \(error.localizedDescription)",
                details: nil
            ))
        }
    }

    /// Recognize text from multiple images in batch
    private func recognizeTextBatch(imagePaths: [String], result: @escaping FlutterResult) {
        var results: [[String: Any]] = []
        let group = DispatchGroup()

        for imagePath in imagePaths {
            group.enter()

            // Load image
            guard let image = UIImage(contentsOfFile: imagePath),
                  let cgImage = image.cgImage else {
                group.leave()
                continue
            }

            // Create text recognition request
            let request = VNRecognizeTextRequest { vnRequest, error in
                defer { group.leave() }

                if error != nil {
                    return
                }

                guard let observations = vnRequest.results as? [VNRecognizedTextObservation] else {
                    return
                }

                // Extract text from observations
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let text = recognizedStrings.joined(separator: "\n")
                let averageConfidence = observations.isEmpty ? 0.0 :
                    observations.reduce(0.0) { sum, obs in
                        sum + Double(obs.topCandidates(1).first?.confidence ?? 0.0)
                    } / Double(observations.count)

                if !text.isEmpty {
                    results.append([
                        "imagePath": imagePath,
                        "text": text,
                        "confidence": averageConfidence,
                    ])
                }
            }

            // Configure request
            request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            // Perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                group.leave()
            }
        }

        // Wait for all requests to complete
        group.notify(queue: .main) {
            result(results)
        }
    }
}
