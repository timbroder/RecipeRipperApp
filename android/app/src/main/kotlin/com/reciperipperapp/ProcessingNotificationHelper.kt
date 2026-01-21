package com.reciperipperapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Helper class for creating notifications for background processing.
 * Used by WorkManager to show foreground service notifications.
 */
object ProcessingNotificationHelper {
    const val CHANNEL_ID = "recipe_processing_channel"
    const val NOTIFICATION_ID = 1001

    /**
     * Create notification channel for Android 8.0+
     */
    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Recipe Processing"
            val description = "Shows progress when processing videos in the background"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                this.description = description
                setShowBadge(false)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Create a notification for background processing
     */
    fun createNotification(
        context: Context,
        title: String = "Processing Recipe",
        content: String = "Extracting recipe from video...",
        progress: Int = 0,
        indeterminate: Boolean = true
    ): Notification {
        createNotificationChannel(context)

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_rotate)
            .setContentTitle(title)
            .setContentText(content)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)

        if (indeterminate) {
            builder.setProgress(100, 0, true)
        } else {
            builder.setProgress(100, progress, false)
        }

        return builder.build()
    }

    /**
     * Update an existing notification with new progress
     */
    fun updateNotification(
        context: Context,
        title: String,
        content: String,
        progress: Int
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager

        val notification = createNotification(
            context = context,
            title = title,
            content = content,
            progress = progress,
            indeterminate = false
        )

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    /**
     * Cancel the processing notification
     */
    fun cancelNotification(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
