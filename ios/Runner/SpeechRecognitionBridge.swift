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

        // TODO: DEV HARNESS — remove before release
        // Log audio file info
        if let attrs = try? FileManager.default.attributesOfItem(atPath: audioPath),
           let fileSize = attrs[.size] as? Int64 {
            print("=== SPEECH BRIDGE: Audio file: \(fileSize) bytes (\(fileSize / 1024) KB)")
        } else {
            print("=== SPEECH BRIDGE: WARNING - Cannot read file at \(audioPath)")
            print("=== SPEECH BRIDGE: File exists: \(FileManager.default.fileExists(atPath: audioPath))")
        }

        // Log audio duration via AVAudioFile
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            let frames = audioFile.length
            let sampleRate = audioFile.processingFormat.sampleRate
            let channels = audioFile.processingFormat.channelCount
            let duration = Double(frames) / sampleRate
            print("=== SPEECH BRIDGE: Audio duration: \(String(format: "%.1f", duration))s, sampleRate: \(sampleRate), channels: \(channels)")
        } catch {
            print("=== SPEECH BRIDGE: WARNING - Cannot read audio format: \(error.localizedDescription)")
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

        // TODO: DEV HARNESS — remove before release
        print("=== SPEECH BRIDGE: supportsOnDeviceRecognition: \(recognizer.supportsOnDeviceRecognition)")

        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation  // Better for continuous speech like recipe narration
        request.addsPunctuation = true

        // TODO: DEV HARNESS — remove before release
        print("=== SPEECH BRIDGE: Starting recognition for \(audioPath)")
        print("=== SPEECH BRIDGE: Language: \(language), onDevice: true, taskHint: dictation")

        var hasCalledResult = false
        // Track best partial result — on-device recognizer sometimes returns empty
        // final result despite producing valid partial results
        var bestPartialText = ""

        recognizer.recognitionTask(with: request) { recognitionResult, error in
            // TODO: DEV HARNESS — remove before release
            print("=== SPEECH BRIDGE: Callback fired - error: \(String(describing: error)), result: \(recognitionResult != nil), isFinal: \(recognitionResult?.isFinal ?? false)")

            if let error = error {
                let nsError = error as NSError
                print("=== SPEECH BRIDGE: ERROR: \(error.localizedDescription)")
                print("=== SPEECH BRIDGE: ERROR domain: \(nsError.domain), code: \(nsError.code)")
                print("=== SPEECH BRIDGE: ERROR userInfo: \(nsError.userInfo)")
                if !hasCalledResult {
                    hasCalledResult = true
                    // Even on error, return best partial if we have one
                    if !bestPartialText.isEmpty {
                        print("=== SPEECH BRIDGE: Error occurred but returning best partial (\(bestPartialText.count) chars)")
                        result([
                            "text": bestPartialText,
                            "confidence": 0.8,
                        ])
                    } else {
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
                print("=== SPEECH BRIDGE: No result object")
                if !hasCalledResult {
                    hasCalledResult = true
                    if !bestPartialText.isEmpty {
                        print("=== SPEECH BRIDGE: No result but returning best partial (\(bestPartialText.count) chars)")
                        result([
                            "text": bestPartialText,
                            "confidence": 0.8,
                        ])
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

            // Always capture the longest partial text as fallback
            let currentText = recognitionResult.bestTranscription.formattedString
            if currentText.count > bestPartialText.count {
                bestPartialText = currentText
            }

            if recognitionResult.isFinal {
                let transcription = recognitionResult.bestTranscription.formattedString
                let segmentCount = recognitionResult.bestTranscription.segments.count
                let preview = String(transcription.prefix(200))
                print("=== SPEECH BRIDGE: FINAL text (\(transcription.count) chars, \(segmentCount) segments): \(preview)...")

                // Use best partial as fallback if final result is empty
                let outputText: String
                if transcription.isEmpty && !bestPartialText.isEmpty {
                    print("=== SPEECH BRIDGE: Final was empty, using best partial (\(bestPartialText.count) chars)")
                    outputText = bestPartialText
                } else {
                    outputText = transcription
                }

                if !hasCalledResult {
                    hasCalledResult = true
                    result([
                        "text": outputText,
                        "confidence": transcription.isEmpty ? 0.8 : 1.0,
                    ])
                }
            } else {
                let partial = recognitionResult.bestTranscription.formattedString
                print("=== SPEECH BRIDGE: Partial (\(partial.count) chars), bestPartial: \(bestPartialText.count) chars")
            }
        }
    }
}
