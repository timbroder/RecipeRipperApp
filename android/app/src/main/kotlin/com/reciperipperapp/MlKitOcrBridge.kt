package com.reciperipperapp

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Bridge between Flutter and Google ML Kit for text recognition (OCR)
 */
class MlKitOcrBridge(
    private val context: Context,
    binaryMessenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel: MethodChannel = MethodChannel(
        binaryMessenger,
        "com.reciperipperapp/mlkit_ocr"
    )

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "recognizeText" -> {
                val imagePath = call.argument<String>("imagePath")
                if (imagePath == null) {
                    result.error("INVALID_ARGS", "Missing imagePath", null)
                    return
                }
                recognizeText(imagePath, result)
            }
            "recognizeTextBatch" -> {
                val imagePaths = call.argument<List<String>>("imagePaths")
                if (imagePaths == null) {
                    result.error("INVALID_ARGS", "Missing imagePaths", null)
                    return
                }
                recognizeTextBatch(imagePaths, result)
            }
            "isAvailable" -> result.success(true) // ML Kit is always available
            else -> result.notImplemented()
        }
    }

    /**
     * Recognize text from a single image
     */
    private fun recognizeText(imagePath: String, result: MethodChannel.Result) {
        try {
            val file = File(imagePath)
            if (!file.exists()) {
                result.error("INVALID_IMAGE", "Image file not found: $imagePath", null)
                return
            }

            val image = InputImage.fromFilePath(context, Uri.fromFile(file))

            recognizer.process(image)
                .addOnSuccessListener { visionText ->
                    val text = visionText.text
                    // ML Kit v16+ doesn't expose confidence scores directly
                    // Use 1.0 if text was recognized, 0.0 otherwise
                    val confidence = if (text.isNotEmpty()) 1.0 else 0.0

                    result.success(mapOf(
                        "text" to text,
                        "confidence" to confidence
                    ))
                }
                .addOnFailureListener { e ->
                    result.error(
                        "RECOGNITION_ERROR",
                        "OCR failed: ${e.message}",
                        null
                    )
                }
        } catch (e: Exception) {
            result.error(
                "HANDLER_ERROR",
                "Failed to process image: ${e.message}",
                null
            )
        }
    }

    /**
     * Recognize text from multiple images in batch
     */
    private fun recognizeTextBatch(
        imagePaths: List<String>,
        result: MethodChannel.Result
    ) {
        val results = mutableListOf<Map<String, Any>>()
        var processedCount = 0
        val totalCount = imagePaths.size

        if (totalCount == 0) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        for (imagePath in imagePaths) {
            try {
                val file = File(imagePath)
                if (!file.exists()) {
                    processedCount++
                    if (processedCount == totalCount) {
                        result.success(results)
                    }
                    continue
                }

                val image = InputImage.fromFilePath(context, Uri.fromFile(file))

                recognizer.process(image)
                    .addOnSuccessListener { visionText ->
                        val text = visionText.text
                        if (text.isNotEmpty()) {
                            // ML Kit v16+ doesn't expose confidence scores directly
                            results.add(mapOf(
                                "imagePath" to imagePath,
                                "text" to text,
                                "confidence" to 1.0
                            ))
                        }

                        processedCount++
                        if (processedCount == totalCount) {
                            result.success(results)
                        }
                    }
                    .addOnFailureListener { _ ->
                        processedCount++
                        if (processedCount == totalCount) {
                            result.success(results)
                        }
                    }
            } catch (e: Exception) {
                processedCount++
                if (processedCount == totalCount) {
                    result.success(results)
                }
            }
        }
    }

    /**
     * Clean up resources
     */
    fun close() {
        recognizer.close()
    }
}
