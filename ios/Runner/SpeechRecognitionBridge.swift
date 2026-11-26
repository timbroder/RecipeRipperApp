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
        var transcript = TranscriptAccumulator()

        recognizer.recognitionTask(with: request) { recognitionResult, error in
            if let error = error {
                if !hasCalledResult {
                    hasCalledResult = true
                    // On error, return what was recognized so far, if anything
                    let partialText = transcript.text
                    if !partialText.isEmpty {
                        result(["text": partialText, "confidence": 0.8])
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
                    let partialText = transcript.text
                    if !partialText.isEmpty {
                        result(["text": partialText, "confidence": 0.8])
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
            transcript.add(currentText)

            if recognitionResult.isFinal && !hasCalledResult {
                hasCalledResult = true
                let (fullText, confidence) = transcript.finish(finalText: currentText)
                result([
                    "text": fullText,
                    "confidence": fullText.isEmpty ? 0.0 : confidence,
                ])
            }
        }
    }
}

/// Builds the full transcript from on-device speech recognition results.
///
/// The on-device recognizer processes long audio in segments, and each
/// segment's partial results start over (e.g. 3→558 chars, then 4→279 chars
/// for the next segment). The final result covers only the last segment, and
/// is sometimes empty. So the transcript is every segment's longest partial
/// text, joined in order.
struct TranscriptAccumulator {
    private(set) var completedSegments: [String] = []
    private(set) var currentSegmentBest = ""

    /// Record a partial or final result's text.
    mutating func add(_ text: String) {
        // A big drop in length means the recognizer started a new segment.
        if text.count < currentSegmentBest.count / 2 && currentSegmentBest.count > 20 {
            completedSegments.append(currentSegmentBest)
            currentSegmentBest = text
        } else if text.count >= currentSegmentBest.count {
            currentSegmentBest = text
        }
    }

    /// Every segment recognized so far, joined.
    var text: String {
        (completedSegments + [currentSegmentBest])
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The full transcript and a confidence once the final result arrives.
    ///
    /// With a single segment, the final text is the whole transcript (and is
    /// better punctuated than the partials), so it's used when present.
    /// With several segments, the final text is normally just the last one,
    /// so the joined segments are used. The exception is a final text that
    /// starts the way the first segment did: it already covers everything.
    func finish(finalText: String) -> (text: String, confidence: Double) {
        guard let firstSegment = completedSegments.first else {
            return finalText.isEmpty ? (text, 0.9) : (finalText, 1.0)
        }
        let opening = firstSegment.prefix(20).lowercased()
        if finalText.lowercased().hasPrefix(opening) {
            return (finalText, 1.0)
        }
        return (text, 0.9)
    }
}
