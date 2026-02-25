import Flutter
import Speech
import AVFoundation

/// Bridge between Flutter and iOS Speech framework for audio transcription
class SpeechRecognitionBridge: NSObject {
    private var channel: FlutterMethodChannel?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    /// Initialize the bridge with Flutter method channel
    func setup(with binaryMessenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.reciperipperapp/speech_recognition",
            binaryMessenger: binaryMessenger
        )

        channel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call: call, result: result)
        }
    }

    /// Handle method calls from Flutter
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            requestPermission(result: result)
        case "transcribeAudio":
            guard let args = call.arguments as? [String: Any],
                  let audioPath = args["audioPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing audioPath", details: nil))
                return
            }
            let language = args["language"] as? String ?? "en-US"
            transcribeAudio(audioPath: audioPath, language: language, result: result)
        case "isAvailable":
            checkAvailability(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Request speech recognition permission
    private func requestPermission(result: @escaping FlutterResult) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    result(true)
                case .denied, .restricted, .notDetermined:
                    result(false)
                @unknown default:
                    result(false)
                }
            }
        }
    }

    /// Check if speech recognition is available
    private func checkAvailability(result: @escaping FlutterResult) {
        result(speechRecognizer?.isAvailable ?? false)
    }

    /// Transcribe audio file to text
    private func transcribeAudio(audioPath: String, language: String, result: @escaping FlutterResult) {
        let fileURL = URL(fileURLWithPath: audioPath)

        // Check if speech recognition is available
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)) else {
            result(FlutterError(
                code: "RECOGNIZER_NOT_AVAILABLE",
                message: "Speech recognizer not available for language: \(language)",
                details: nil
            ))
            return
        }

        guard recognizer.isAvailable else {
            result(FlutterError(
                code: "RECOGNIZER_NOT_AVAILABLE",
                message: "Speech recognizer is not available",
                details: nil
            ))
            return
        }

        // Check authorization status
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            result(FlutterError(
                code: "NOT_AUTHORIZED",
                message: "Speech recognition not authorized",
                details: nil
            ))
            return
        }

        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation  // Better for continuous speech like recipe narration
        request.addsPunctuation = true

        var hasCalledResult = false
        // The on-device recognizer processes audio in segments. Each segment's
        // partial results build up independently (e.g., 3→558 chars, then resets
        // to 4→279 chars for the next segment). The final isFinal=true callback
        // often returns empty text. We accumulate all segments to get the full
        // transcript.
        var completedSegments: [String] = []
        var currentSegmentBest = ""

        recognizer.recognitionTask(with: request) { recognitionResult, error in
            if let error = error {
                if !hasCalledResult {
                    hasCalledResult = true
                    // On error, return accumulated segments if we have them
                    if !currentSegmentBest.isEmpty {
                        completedSegments.append(currentSegmentBest)
                    }
                    let fullText = completedSegments.joined(separator: " ")
                    if !fullText.isEmpty {
                        result([
                            "text": fullText,
                            "confidence": 0.8,
                        ])
                    } else {
                        let nsError = error as NSError
                        result(FlutterError(
                            code: "RECOGNITION_ERROR",
                            message: "Transcription failed: \(error.localizedDescription)",
                            details: "domain=\(nsError.domain) code=\(nsError.code)"
                        ))
                    }
                }
                return
            }

            guard let recognitionResult = recognitionResult else {
                if !hasCalledResult {
                    hasCalledResult = true
                    if !currentSegmentBest.isEmpty {
                        completedSegments.append(currentSegmentBest)
                    }
                    let fullText = completedSegments.joined(separator: " ")
                    if !fullText.isEmpty {
                        result(["text": fullText, "confidence": 0.8])
                    } else {
                        result(FlutterError(
                            code: "NO_RESULT",
                            message: "No transcription result",
                            details: nil
                        ))
                    }
                }
                return
            }

            let currentText = recognitionResult.bestTranscription.formattedString

            // Detect segment boundary: when partial length drops significantly,
            // the recognizer has started a new audio segment
            if currentText.count < currentSegmentBest.count / 2 && currentSegmentBest.count > 20 {
                completedSegments.append(currentSegmentBest)
                currentSegmentBest = currentText
            } else if currentText.count >= currentSegmentBest.count {
                currentSegmentBest = currentText
            }

            if recognitionResult.isFinal {
                let transcription = recognitionResult.bestTranscription.formattedString

                // Finalize: use final text if non-empty, otherwise use accumulated segments
                if !transcription.isEmpty {
                    if !hasCalledResult {
                        hasCalledResult = true
                        result(["text": transcription, "confidence": 1.0])
                    }
                } else {
                    // Final was empty — use accumulated segments
                    if !currentSegmentBest.isEmpty {
                        completedSegments.append(currentSegmentBest)
                    }
                    let fullText = completedSegments.joined(separator: " ")
                    if !hasCalledResult {
                        hasCalledResult = true
                        result([
                            "text": fullText,
                            "confidence": fullText.isEmpty ? 0.0 : 0.9,
                        ])
                    }
                }
            }
        }
    }
}
