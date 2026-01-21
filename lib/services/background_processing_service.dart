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

/// Top-level callback dispatcher for WorkManager
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

/// Service for managing background video processing using WorkManager
class BackgroundProcessingService {
  static const _workManagerChannel = MethodChannel(
    'com.reciperipper/workmanager',
  );

  /// Initialize WorkManager - must be called once at app startup
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    debugPrint('BackgroundProcessingService: Initialized');
  }

  /// Check if background processing is available on this platform
  static Future<bool> isAvailable() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _workManagerChannel.invokeMethod<bool>(
        'isWorkManagerAvailable',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Schedule a video for background processing
  ///
  /// Returns the job ID that can be used to track or cancel the job
  static Future<String> scheduleProcessing({
    required String jobId,
    required String videoPath,
    String? sourceUrl,
  }) async {
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

    debugPrint('BackgroundProcessingService: Scheduled job $jobId');
    return jobId;
  }

  /// Cancel a specific background job
  static Future<void> cancelJob(String jobId) async {
    try {
      await _workManagerChannel.invokeMethod('cancelWork', {'jobId': jobId});
      debugPrint('BackgroundProcessingService: Cancelled job $jobId');
    } on PlatformException catch (e) {
      debugPrint('BackgroundProcessingService: Failed to cancel job - $e');
    }
  }

  /// Cancel all background jobs
  static Future<void> cancelAllJobs() async {
    try {
      await _workManagerChannel.invokeMethod('cancelAllWork');
      debugPrint('BackgroundProcessingService: Cancelled all jobs');
    } on PlatformException catch (e) {
      debugPrint('BackgroundProcessingService: Failed to cancel all jobs - $e');
    }
  }

  /// Get the status of a background job
  static Future<BackgroundJobStatus?> getJobStatus(String jobId) async {
    try {
      final result =
          await _workManagerChannel.invokeMethod<Map<Object?, Object?>>(
        'getWorkStatus',
        {'jobId': jobId},
      );

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
