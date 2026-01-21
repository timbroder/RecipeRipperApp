package com.reciperipperapp

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.work.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity: FlutterActivity() {
    private val SHARED_URL_CHANNEL = "com.reciperipper/shared_url"
    private val WORKMANAGER_CHANNEL = "com.reciperipper/workmanager"
    private var sharedUrl: String? = null
    private var speechRecognitionBridge: SpeechRecognitionBridge? = null
    private var mlKitOcrBridge: MlKitOcrBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Create notification channel for background processing
        ProcessingNotificationHelper.createNotificationChannel(this)

        // Set up method channel for shared URLs (Sprint 1)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARED_URL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedUrl" -> {
                    result.success(sharedUrl)
                    sharedUrl = null  // Clear after retrieval
                }
                else -> result.notImplemented()
            }
        }

        // Set up method channel for WorkManager (Sprint 2 - Background Processing)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WORKMANAGER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWorkManagerAvailable" -> {
                    result.success(true)
                }
                "cancelWork" -> {
                    val jobId = call.argument<String>("jobId")
                    if (jobId != null) {
                        WorkManager.getInstance(applicationContext).cancelUniqueWork(jobId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "jobId is required", null)
                    }
                }
                "cancelAllWork" -> {
                    WorkManager.getInstance(applicationContext).cancelAllWork()
                    result.success(true)
                }
                "getWorkStatus" -> {
                    val jobId = call.argument<String>("jobId")
                    if (jobId != null) {
                        val workInfo = WorkManager.getInstance(applicationContext)
                            .getWorkInfosForUniqueWork(jobId)
                            .get()
                            .firstOrNull()

                        if (workInfo != null) {
                            result.success(mapOf(
                                "state" to workInfo.state.name,
                                "progress" to workInfo.progress.getInt("progress", 0)
                            ))
                        } else {
                            result.success(null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "jobId is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Set up Sprint 2 platform channels
        speechRecognitionBridge = SpeechRecognitionBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        mlKitOcrBridge = MlKitOcrBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        super.onDestroy()
        mlKitOcrBridge?.close()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    // Handle shared text (URL)
                    intent.getStringExtra(Intent.EXTRA_TEXT)?.let { sharedText ->
                        sharedUrl = sharedText

                        // Notify Flutter that a URL was shared
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, SHARED_URL_CHANNEL)
                                .invokeMethod("urlReceived", sharedText)
                        }
                    }
                } else if (intent.type?.startsWith("video/") == true) {
                    // Handle shared video file
                    intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)?.let { videoUri ->
                        val videoPath = videoUri.toString()
                        sharedUrl = videoPath

                        // Notify Flutter that a video was shared
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            MethodChannel(messenger, SHARED_URL_CHANNEL)
                                .invokeMethod("urlReceived", videoPath)
                        }
                    }
                }
            }
        }
    }
}
