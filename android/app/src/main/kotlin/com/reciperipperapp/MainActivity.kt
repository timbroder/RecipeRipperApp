package com.reciperipperapp

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val SHARED_URL_CHANNEL = "com.reciperipper/shared_url"
    private var sharedUrl: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        // Platform channels will be set up here in future sprints
        // Sprint 2: Speech recognition channel
        // Sprint 2: OCR/ML Kit channel
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
