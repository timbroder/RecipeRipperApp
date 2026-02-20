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
            let requireOnDevice = args["requireOnDevice"] as? Bool ?? true
            transcribeAudio(audioPath: audioPath, language: language, requireOnDevice: requireOnDevice, result: result)
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
    private func transcribeAudio(audioPath: String, language: String, requireOnDevice: Bool, result: @escaping FlutterResult) {
        // Log audio file info
        let fileURL = URL(fileURLWithPath: audioPath)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: audioPath),
           let fileSize = attrs[.size] as? Int64 {
            print("=== SPEECH BRIDGE: Audio file size: \(fileSize) bytes (\(fileSize / 1024) KB)")
        } else {
            print("=== SPEECH BRIDGE: WARNING - Could not read audio file attributes at \(audioPath)")
            print("=== SPEECH BRIDGE: File exists: \(FileManager.default.fileExists(atPath: audioPath))")
        }

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
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = requireOnDevice

        // Start recognition
        // TODO: DEV HARNESS — remove before release
        print("=== SPEECH BRIDGE: Starting recognition for \(audioPath)")
        print("=== SPEECH BRIDGE: Language: \(language), requireOnDevice: \(requireOnDevice)")

        var hasCalledResult = false

        recognizer.recognitionTask(with: request) { recognitionResult, error in
            // TODO: DEV HARNESS — remove before release
            print("=== SPEECH BRIDGE: Callback fired - error: \(String(describing: error)), result: \(recognitionResult != nil), isFinal: \(recognitionResult?.isFinal ?? false)")

            if let error = error {
                print("=== SPEECH BRIDGE: ERROR: \(error.localizedDescription)")
                if !hasCalledResult {
                    hasCalledResult = true
                    result(FlutterError(
                        code: "RECOGNITION_ERROR",
                        message: "Transcription failed: \(error.localizedDescription)",
                        details: nil
                    ))
                }
                return
            }

            guard let recognitionResult = recognitionResult else {
                print("=== SPEECH BRIDGE: No result object")
                if !hasCalledResult {
                    hasCalledResult = true
                    result(FlutterError(
                        code: "NO_RESULT",
                        message: "No transcription result",
                        details: nil
                    ))
                }
                return
            }

            if recognitionResult.isFinal {
                let transcription = recognitionResult.bestTranscription.formattedString
                let preview = String(transcription.prefix(200))
                print("=== SPEECH BRIDGE: FINAL text (\(transcription.count) chars): \(preview)...")
                if !hasCalledResult {
                    hasCalledResult = true
                    result([
                        "text": transcription,
                        "confidence": 1.0,
                    ])
                }
            } else {
                let partial = recognitionResult.bestTranscription.formattedString
                print("=== SPEECH BRIDGE: Partial (\(partial.count) chars)")
            }
        }
    }
}
