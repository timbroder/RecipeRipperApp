import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/processing_job.dart';
import '../models/recipe.dart';
import 'audio_extraction_service.dart';
import 'database_service.dart';
import 'frame_extraction_service.dart';
import 'ocr_service.dart';
import 'speech_transcription_service.dart';
import 'recipe_parsing_service.dart';

/// Service that orchestrates the entire video processing pipeline
class ProcessingService {
  final DatabaseService _databaseService;
  final AudioExtractionService _audioService;
  final SpeechTranscriptionService _speechService;
  final FrameExtractionService _frameService;
  final OcrService _ocrService;
  final _uuid = const Uuid();

  ProcessingService({
    required DatabaseService databaseService,
    AudioExtractionService? audioService,
    SpeechTranscriptionService? speechService,
    FrameExtractionService? frameService,
    OcrService? ocrService,
  })  : _databaseService = databaseService,
        _audioService = audioService ?? AudioExtractionService(),
        _speechService = speechService ?? SpeechTranscriptionService(),
        _frameService = frameService ?? FrameExtractionService(),
        _ocrService = ocrService ?? OcrService();

  /// Process a video file and extract recipe
  ///
  /// [videoPath] - Path to the video file
  /// [sourceUrl] - Optional source URL for the video
  /// [existingJobId] - Optional existing job ID (for background processing)
  /// [onProgress] - Callback for progress updates (jobId, status, progress, currentStep)
  /// Returns the processing job ID
  Future<String> processVideo(
    String videoPath, {
    String? sourceUrl,
    String? existingJobId,
    void Function(String jobId, ProcessingStatus status, double progress,
            String currentStep)?
        onProgress,
  }) async {
    // Use existing job ID or create new one
    final jobId = existingJobId ?? _uuid.v4();

    // Check if job already exists (for background processing)
    final existingJob = await _databaseService.getProcessingJob(jobId);
    if (existingJob == null) {
      // Create new processing job
      final job = ProcessingJob(
        id: jobId,
        sourceUrl: sourceUrl,
        localVideoPath: videoPath,
        status: ProcessingStatus.queued,
        progress: 0.0,
        createdAt: DateTime.now(),
      );
      await _databaseService.insertProcessingJob(job);
    }

    String? audioPath;
    List<String> framePaths = [];

    try {
      // Update job status to transcribing
      await _updateJob(
        jobId,
        status: ProcessingStatus.transcribing,
        progress: 0.0,
        currentStep: 'Extracting audio from video...',
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.transcribing,
        0.0,
        'Extracting audio from video...',
      );

      // Step 1: Extract audio from video
      audioPath = await _audioService.extractAudio(videoPath);

      await _updateJob(
        jobId,
        progress: 0.1,
        currentStep: 'Transcribing audio to text...',
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.transcribing,
        0.1,
        'Transcribing audio to text...',
      );

      // Step 2: Transcribe audio to text
      final transcriptionResult = await _speechService.transcribeAudio(
        audioPath,
        onProgress: (p) {
          final overallProgress = 0.1 + (p * 0.4); // 10% - 50%
          _updateJob(
            jobId,
            progress: overallProgress,
            currentStep: 'Transcribing audio... ${(p * 100).toInt()}%',
          );
          onProgress?.call(
            jobId,
            ProcessingStatus.transcribing,
            overallProgress,
            'Transcribing audio... ${(p * 100).toInt()}%',
          );
        },
      );

      final transcript = transcriptionResult.text;

      // Step 3: Extract frames from video
      await _updateJob(
        jobId,
        status: ProcessingStatus.extractingText,
        progress: 0.5,
        currentStep: 'Extracting frames from video...',
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.extractingText,
        0.5,
        'Extracting frames from video...',
      );

      framePaths = await _frameService.extractFrames(
        videoPath,
        onProgress: (p) {
          final overallProgress = 0.5 + (p * 0.1); // 50% - 60%
          _updateJob(
            jobId,
            progress: overallProgress,
            currentStep: 'Extracting frames... ${(p * 100).toInt()}%',
          );
          onProgress?.call(
            jobId,
            ProcessingStatus.extractingText,
            overallProgress,
            'Extracting frames... ${(p * 100).toInt()}%',
          );
        },
      );

      await _updateJob(
        jobId,
        progress: 0.6,
        currentStep: 'Recognizing text from frames...',
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.extractingText,
        0.6,
        'Recognizing text from frames...',
      );

      // Step 4: Perform OCR on frames
      final ocrText = await _ocrService.recognizeAndDeduplicateFrames(
        framePaths,
        onProgress: (p) {
          final overallProgress = 0.6 + (p * 0.3); // 60% - 90%
          _updateJob(
            jobId,
            progress: overallProgress,
            currentStep: 'Processing OCR... ${(p * 100).toInt()}%',
          );
          onProgress?.call(
            jobId,
            ProcessingStatus.extractingText,
            overallProgress,
            'Processing OCR... ${(p * 100).toInt()}%',
          );
        },
      );

      // Step 5: Parse recipe from extracted data
      await _updateJob(
        jobId,
        status: ProcessingStatus.parsing,
        progress: 0.9,
        currentStep: 'Parsing recipe...',
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.parsing,
        0.9,
        'Parsing recipe...',
      );

      // Calculate processing time
      final startTime = (await _databaseService.getProcessingJob(jobId))
              ?.createdAt ??
          DateTime.now();
      final processingTimeSeconds =
          DateTime.now().difference(startTime).inSeconds;

      // Use RecipeParsingService to parse the recipe
      final videoFileName = path.basenameWithoutExtension(videoPath);
      final recipe = await RecipeParsingService.parseRecipe(
        transcript: transcript,
        ocrText: ocrText,
        videoTitle: videoFileName,
        sourceUrl: sourceUrl,
        sourcePlatform: _detectPlatform(sourceUrl),
        metadata: RecipeMetadata(
          transcript: transcript,
          ocrText: ocrText,
          processingTimeSeconds: processingTimeSeconds,
          frameCount: framePaths.length,
        ),
      );

      // Save recipe to database
      final recipeId = await _databaseService.insertRecipe(recipe);

      // Update job as completed
      await _updateJob(
        jobId,
        status: ProcessingStatus.completed,
        progress: 1.0,
        currentStep: 'Completed!',
        recipeId: recipeId,
        completedAt: DateTime.now(),
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.completed,
        1.0,
        'Completed!',
      );

      // Cleanup temporary files
      await _cleanup(audioPath, framePaths);

      return jobId;
    } catch (e) {
      // Update job as failed
      await _updateJob(
        jobId,
        status: ProcessingStatus.failed,
        errorMessage: e.toString(),
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.failed,
        0.0,
        'Failed: ${e.toString()}',
      );

      // Cleanup temporary files
      await _cleanup(audioPath, framePaths);

      rethrow;
    }
  }

  /// Update processing job in database
  Future<void> _updateJob(
    String jobId, {
    ProcessingStatus? status,
    double? progress,
    String? currentStep,
    String? errorMessage,
    String? recipeId,
    DateTime? completedAt,
  }) async {
    final existingJob = await _databaseService.getProcessingJob(jobId);
    if (existingJob == null) return;

    final updatedJob = existingJob.copyWith(
      status: status,
      progress: progress,
      currentStep: currentStep,
      errorMessage: errorMessage,
      recipeId: recipeId,
      completedAt: completedAt,
      startedAt: existingJob.startedAt ?? DateTime.now(),
    );

    await _databaseService.updateProcessingJob(updatedJob);
  }

  /// Detect platform from source URL
  String? _detectPlatform(String? url) {
    if (url == null) return null;

    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return 'YouTube';
    } else if (url.contains('vimeo.com')) {
      return 'Vimeo';
    } else if (url.contains('dailymotion.com')) {
      return 'Dailymotion';
    } else if (url.contains('instagram.com')) {
      return 'Instagram';
    } else if (url.contains('tiktok.com')) {
      return 'TikTok';
    }

    return 'Unknown';
  }

  /// Cleanup temporary files
  Future<void> _cleanup(String? audioPath, List<String> framePaths) async {
    try {
      if (audioPath != null) {
        await _audioService.deleteAudioFile(audioPath);
      }

      if (framePaths.isNotEmpty) {
        await _frameService.deleteFrames(framePaths);
      }
    } catch (e) {
      // Silently fail - cleanup is not critical
    }
  }

  /// Cancel a processing job
  Future<void> cancelJob(String jobId) async {
    await _updateJob(
      jobId,
      status: ProcessingStatus.cancelled,
      currentStep: 'Cancelled by user',
    );
  }

  /// Get active processing jobs
  Future<List<ProcessingJob>> getActiveJobs() async {
    return _databaseService.getActiveProcessingJobs();
  }

  /// Get a specific processing job
  Future<ProcessingJob?> getJob(String jobId) async {
    return _databaseService.getProcessingJob(jobId);
  }

  /// Create a processing job without starting processing
  /// Used for background processing where we need to create the job first,
  /// then schedule it via WorkManager
  Future<String> createJob({
    required String videoPath,
    String? sourceUrl,
  }) async {
    final jobId = _uuid.v4();
    final job = ProcessingJob(
      id: jobId,
      sourceUrl: sourceUrl,
      localVideoPath: videoPath,
      status: ProcessingStatus.queued,
      progress: 0.0,
      currentStep: 'Waiting to start...',
      createdAt: DateTime.now(),
    );

    await _databaseService.insertProcessingJob(job);
    return jobId;
  }
}
