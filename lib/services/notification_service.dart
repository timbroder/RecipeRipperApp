import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/processing_job.dart';

/// Service for managing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Request permission for notifications (iOS only)
  Future<bool?> requestPermission() async {
    if (!_initialized) await initialize();

    return await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Show a processing started notification
  Future<void> showProcessingStarted(String jobId, String videoTitle) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'processing_channel',
      'Recipe Processing',
      channelDescription: 'Notifications for recipe processing status',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: 0,
      ongoing: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      jobId.hashCode,
      'Processing Recipe',
      'Starting to process: $videoTitle',
      details,
    );
  }

  /// Update processing progress notification
  Future<void> updateProcessingProgress(
    String jobId,
    String videoTitle,
    double progress,
    String currentStep,
  ) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'processing_channel',
      'Recipe Processing',
      channelDescription: 'Notifications for recipe processing status',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).round(),
      ongoing: true,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      jobId.hashCode,
      'Processing Recipe',
      currentStep,
      details,
    );
  }

  /// Show processing completed notification
  Future<void> showProcessingCompleted(
    String jobId,
    String videoTitle,
  ) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'processing_channel',
      'Recipe Processing',
      channelDescription: 'Notifications for recipe processing status',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      jobId.hashCode,
      'Recipe Ready! 🎉',
      'Successfully processed: $videoTitle',
      details,
    );
  }

  /// Show processing failed notification
  Future<void> showProcessingFailed(
    String jobId,
    String videoTitle,
    String errorMessage,
  ) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'processing_channel',
      'Recipe Processing',
      channelDescription: 'Notifications for recipe processing status',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      jobId.hashCode,
      'Processing Failed',
      'Failed to process: $videoTitle',
      details,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(String jobId) async {
    await _notifications.cancel(jobId.hashCode);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    // In a real app, you would navigate to the appropriate screen
    // For now, this is a no-op. Navigation will be added when deep linking
    // is implemented in a future sprint.
    // ignore: unused_local_variable
    final payload = response.payload;
  }

  /// Show notification for processing job status
  Future<void> showJobStatusNotification(ProcessingJob job) async {
    switch (job.status) {
      case ProcessingStatus.transcribing:
      case ProcessingStatus.extractingText:
      case ProcessingStatus.parsing:
        await updateProcessingProgress(
          job.id,
          job.localVideoPath ?? 'Video',
          job.progress,
          job.currentStep ?? 'Processing...',
        );
        break;
      case ProcessingStatus.completed:
        await showProcessingCompleted(
          job.id,
          job.localVideoPath ?? 'Video',
        );
        break;
      case ProcessingStatus.failed:
        await showProcessingFailed(
          job.id,
          job.localVideoPath ?? 'Video',
          job.errorMessage ?? 'Unknown error',
        );
        break;
      default:
        break;
    }
  }
}
