import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

import '../models/processing_job.dart';
import 'audio_extraction_service.dart';
import 'database_service.dart';
import 'frame_extraction_service.dart';
import 'notification_service.dart';
import 'ocr_service.dart';
import 'processing_service.dart';
import 'speech_transcription_service.dart';

/// Unique task name for video processing
const String backgroundProcessingTask = 'com.reciperipper.processVideo';

/// Top-level callback dispatcher for WorkManager (Android)
/// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == backgroundProcessingTask) {
        final jobId = inputData?['jobId'] as String?;
        final videoPath = inputData?['videoPath'] as String?;
        final sourceUrl = inputData?['sourceUrl'] as String?;

        if (jobId == null || videoPath == null) {
          debugPrint('BackgroundProcessing: Missing required parameters');
          return Future.value(false);
        }

        debugPrint('BackgroundProcessing: Starting job $jobId');

        // Initialize services for background processing
        final databaseService = DatabaseService();
        await databaseService.initialize();

        final notificationService = NotificationService();
        await notificationService.initialize();

        final processingService = ProcessingService(
          databaseService: databaseService,
          audioService: AudioExtractionService(),
          speechService: SpeechTranscriptionService(),
          frameService: FrameExtractionService(),
          ocrService: OcrService(),
        );

        // Process the video
        await processingService.processVideo(
          videoPath,
          sourceUrl: sourceUrl,
          existingJobId: jobId,
          onProgress: (id, status, progress, currentStep) {
            debugPrint(
              'BackgroundProcessing: $currentStep (${(progress * 100).toInt()}%)',
            );

            // Update notification with progress
            final job = ProcessingJob(
              id: id,
              localVideoPath: videoPath,
              sourceUrl: sourceUrl,
              status: status,
              progress: progress,
              currentStep: currentStep,
            );
            notificationService.showJobStatusNotification(job);
          },
        );

        debugPrint('BackgroundProcessing: Job $jobId completed');
        return Future.value(true);
      }

      return Future.value(false);
    } catch (e) {
      debugPrint('BackgroundProcessing: Error - $e');
      return Future.value(false);
    }
  });
}

/// Service for managing background video processing
/// Uses WorkManager on Android and BGTaskScheduler on iOS
class BackgroundProcessingService {
  // Platform channels
  static const _workManagerChannel = MethodChannel(
    'com.reciperipper/workmanager',
  );
  static const _iosBackgroundChannel = MethodChannel(
    'com.reciperipper/background_tasks',
  );

  static bool _isInitialized = false;

  /// Initialize background processing - must be called once at app startup
  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      debugPrint(
          'BackgroundProcessingService: Android WorkManager initialized');
    } else if (Platform.isIOS) {
      // Set up method call handler for iOS background processing callbacks
      _iosBackgroundChannel.setMethodCallHandler(_handleIosMethodCall);
      debugPrint(
          'BackgroundProcessingService: iOS BGTaskScheduler initialized');
    }

    _isInitialized = true;
  }

  /// Handle method calls from iOS native code
  static Future<dynamic> _handleIosMethodCall(MethodCall call) async {
    if (call.method == 'processInBackground') {
      final args = call.arguments as Map<Object?, Object?>;
      final jobId = args['jobId'] as String?;
      final videoPath = args['videoPath'] as String?;
      final sourceUrl = args['sourceUrl'] as String?;

      if (jobId == null || videoPath == null) {
        debugPrint('BackgroundProcessing iOS: Missing required parameters');
        return false;
      }

      try {
        debugPrint('BackgroundProcessing iOS: Starting job $jobId');

        // Initialize services for background processing
        final databaseService = DatabaseService();
        await databaseService.initialize();

        final notificationService = NotificationService();
        await notificationService.initialize();

        final processingService = ProcessingService(
          databaseService: databaseService,
          audioService: AudioExtractionService(),
          speechService: SpeechTranscriptionService(),
          frameService: FrameExtractionService(),
          ocrService: OcrService(),
        );

        // Process the video
        await processingService.processVideo(
          videoPath,
          sourceUrl: sourceUrl,
          existingJobId: jobId,
          onProgress: (id, status, progress, currentStep) {
            debugPrint(
              'BackgroundProcessing iOS: $currentStep (${(progress * 100).toInt()}%)',
            );
          },
        );

        debugPrint('BackgroundProcessing iOS: Job $jobId completed');
        return true;
      } catch (e) {
        debugPrint('BackgroundProcessing iOS: Error - $e');
        return false;
      }
    }
    return null;
  }

  /// Check if background processing is available on this platform
  static Future<bool> isAvailable() async {
    if (Platform.isAndroid) {
      try {
        final result = await _workManagerChannel.invokeMethod<bool>(
          'isWorkManagerAvailable',
        );
        return result ?? false;
      } on PlatformException {
        return false;
      }
    } else if (Platform.isIOS) {
      try {
        final result = await _iosBackgroundChannel.invokeMethod<bool>(
          'isAvailable',
        );
        return result ?? false;
      } on PlatformException {
        return false;
      }
    }
    return false;
  }

  /// Schedule a video for background processing
  ///
  /// Returns the job ID that can be used to track or cancel the job
  static Future<String> scheduleProcessing({
    required String jobId,
    required String videoPath,
    String? sourceUrl,
  }) async {
    if (Platform.isAndroid) {
      // Schedule with WorkManager
      await Workmanager().registerOneOffTask(
        jobId,
        backgroundProcessingTask,
        inputData: {
          'jobId': jobId,
          'videoPath': videoPath,
          'sourceUrl': sourceUrl,
        },
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 10),
        tag: 'recipe_processing',
      );
      debugPrint('BackgroundProcessingService: Android scheduled job $jobId');
    } else if (Platform.isIOS) {
      // Schedule with BGTaskScheduler
      await _iosBackgroundChannel.invokeMethod('scheduleProcessing', {
        'jobId': jobId,
        'videoPath': videoPath,
        'sourceUrl': sourceUrl,
      });
      debugPrint('BackgroundProcessingService: iOS scheduled job $jobId');
    }

    return jobId;
  }

  /// Cancel a specific background job
  static Future<void> cancelJob(String jobId) async {
    try {
      if (Platform.isAndroid) {
        await _workManagerChannel.invokeMethod('cancelWork', {'jobId': jobId});
      } else if (Platform.isIOS) {
        await _iosBackgroundChannel.invokeMethod('cancelJob', {'jobId': jobId});
      }
      debugPrint('BackgroundProcessingService: Cancelled job $jobId');
    } on PlatformException catch (e) {
      debugPrint('BackgroundProcessingService: Failed to cancel job - $e');
    }
  }

  /// Cancel all background jobs
  static Future<void> cancelAllJobs() async {
    try {
      if (Platform.isAndroid) {
        await _workManagerChannel.invokeMethod('cancelAllWork');
      } else if (Platform.isIOS) {
        await _iosBackgroundChannel.invokeMethod('cancelAllJobs');
      }
      debugPrint('BackgroundProcessingService: Cancelled all jobs');
    } on PlatformException catch (e) {
      debugPrint('BackgroundProcessingService: Failed to cancel all jobs - $e');
    }
  }

  /// Get the status of a background job
  static Future<BackgroundJobStatus?> getJobStatus(String jobId) async {
    try {
      Map<Object?, Object?>? result;

      if (Platform.isAndroid) {
        result = await _workManagerChannel.invokeMethod<Map<Object?, Object?>>(
          'getWorkStatus',
          {'jobId': jobId},
        );
      } else if (Platform.isIOS) {
        result =
            await _iosBackgroundChannel.invokeMethod<Map<Object?, Object?>>(
          'getJobStatus',
          {'jobId': jobId},
        );
      }

      if (result == null) return null;

      final state = result['state'] as String?;
      final progress = result['progress'] as int? ?? 0;

      return BackgroundJobStatus(
        state: _parseWorkState(state),
        progress: progress,
      );
    } on PlatformException {
      return null;
    }
  }

  static BackgroundWorkState _parseWorkState(String? state) {
    switch (state) {
      case 'ENQUEUED':
        return BackgroundWorkState.enqueued;
      case 'RUNNING':
        return BackgroundWorkState.running;
      case 'SUCCEEDED':
        return BackgroundWorkState.succeeded;
      case 'FAILED':
        return BackgroundWorkState.failed;
      case 'BLOCKED':
        return BackgroundWorkState.blocked;
      case 'CANCELLED':
        return BackgroundWorkState.cancelled;
      default:
        return BackgroundWorkState.unknown;
    }
  }
}

/// Status of a background job
class BackgroundJobStatus {
  final BackgroundWorkState state;
  final int progress;

  BackgroundJobStatus({
    required this.state,
    required this.progress,
  });
}

/// WorkManager work states
enum BackgroundWorkState {
  enqueued,
  running,
  succeeded,
  failed,
  blocked,
  cancelled,
  unknown,
}
