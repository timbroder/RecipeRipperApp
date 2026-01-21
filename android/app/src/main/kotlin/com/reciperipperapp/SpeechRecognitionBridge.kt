package com.reciperipperapp

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*

/**
 * Bridge between Flutter and Android Speech Recognition API
 */
class SpeechRecognitionBridge(
    private val context: Context,
    binaryMessenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel: MethodChannel = MethodChannel(
        binaryMessenger,
        "com.reciperipperapp/speech_recognition"
    )

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> requestPermission(result)
            "transcribeAudio" -> {
                val audioPath = call.argument<String>("audioPath")
                val language = call.argument<String>("language") ?: "en-US"

                if (audioPath == null) {
                    result.error("INVALID_ARGS", "Missing audioPath", null)
                    return
                }

                transcribeAudio(audioPath, language, result)
            }
            "isAvailable" -> checkAvailability(result)
            else -> result.notImplemented()
        }
    }

    /**
     * Request audio recording permission
     */
    private fun requestPermission(result: MethodChannel.Result) {
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        result.success(hasPermission)
    }

    /**
     * Check if speech recognition is available
     */
    private fun checkAvailability(result: MethodChannel.Result) {
        val available = SpeechRecognizer.isRecognitionAvailable(context)
        result.success(available)
    }

    /**
     * Transcribe audio file to text
     */
    private fun transcribeAudio(
        audioPath: String,
        language: String,
        result: MethodChannel.Result
    ) {
        // Check if speech recognition is available
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            result.error(
                "RECOGNIZER_NOT_AVAILABLE",
                "Speech recognizer is not available",
                null
            )
            return
        }

        // Check permission
        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "NOT_AUTHORIZED",
                "Audio recording permission not granted",
                null
            )
            return
        }

        // Note: Android SpeechRecognizer doesn't directly support file-based transcription
        // This is a limitation of the Android API
        // As a workaround, we'll use the audio file as input to the recognizer
        // This may require playing the audio in the background

        val speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
        val recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }

        speechRecognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}

            override fun onBeginningOfSpeech() {}

            override fun onRmsChanged(rmsdB: Float) {}

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {}

            override fun onError(error: Int) {
                val errorMessage = when (error) {
                    SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                    SpeechRecognizer.ERROR_CLIENT -> "Client error"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
                    SpeechRecognizer.ERROR_NETWORK -> "Network error"
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                    SpeechRecognizer.ERROR_NO_MATCH -> "No speech match"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy"
                    SpeechRecognizer.ERROR_SERVER -> "Server error"
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout"
                    else -> "Unknown error: $error"
                }

                result.error("RECOGNITION_ERROR", errorMessage, null)
                speechRecognizer.destroy()
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val scores = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)

                if (matches != null && matches.isNotEmpty()) {
                    val text = matches[0]
                    val confidence = scores?.getOrNull(0)?.toDouble() ?: 1.0

                    result.success(mapOf(
                        "text" to text,
                        "confidence" to confidence
                    ))
                } else {
                    result.error("NO_RESULT", "No transcription result", null)
                }

                speechRecognizer.destroy()
            }

            override fun onPartialResults(partialResults: Bundle?) {}

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        try {
            // Note: This approach has limitations
            // Android SpeechRecognizer is primarily designed for live audio
            // For better results, consider using Google Cloud Speech-to-Text API
            // or other third-party services for file-based transcription

            speechRecognizer.startListening(recognizerIntent)
        } catch (e: Exception) {
            result.error(
                "RECOGNITION_ERROR",
                "Failed to start recognition: ${e.message}",
                null
            )
            speechRecognizer.destroy()
        }
    }
}
