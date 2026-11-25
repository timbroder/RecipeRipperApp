import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/processing_job.dart';
import '../models/recipe.dart';
import '../utils/cross_reference_checker.dart';
import 'audio_extraction_service.dart';
import 'confidence_calculator_service.dart';
import 'database_service.dart';
import 'frame_extraction_service.dart';
import 'llm/llm_service.dart';
import 'llm/llm_service_factory.dart';
import 'llm_recipe_extraction_service.dart';
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
  final LlmService? _llmService;
  final _uuid = const Uuid();

  ProcessingService({
    required DatabaseService databaseService,
    AudioExtractionService? audioService,
    SpeechTranscriptionService? speechService,
    FrameExtractionService? frameService,
    OcrService? ocrService,
    LlmService? llmService,
  })  : _databaseService = databaseService,
        _audioService = audioService ?? AudioExtractionService(),
        _speechService = speechService ?? SpeechTranscriptionService(),
        _frameService = frameService ?? FrameExtractionService(),
        _ocrService = ocrService ?? OcrService(),
        _llmService = llmService ?? LlmServiceFactory.create();

  /// Process a video file and extract recipe
  ///
  /// [videoPath] - Path to the video file
  /// [sourceUrl] - Optional source URL for the video
  /// [description] - Optional video description (for description-only fast path)
  /// [existingJobId] - Optional existing job ID (for background processing)
  /// [onProgress] - Callback for progress updates (jobId, status, progress, currentStep)
  /// Returns the processing job ID
  Future<String> processVideo(
    String videoPath, {
    String? sourceUrl,
    String? description,
    String? videoTitle,
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
      final videoFileName =
          videoTitle ?? path.basenameWithoutExtension(videoPath);
      final sourcePlatform = _detectPlatform(sourceUrl);

      // Step 0: Description-only fast path (YouTube only)
      final llm = _llmService;
      final llmAvailable = llm != null && await llm.isAvailable();

      if (description != null && description.isNotEmpty && llmAvailable) {
        await _updateJob(
          jobId,
          status: ProcessingStatus.analyzingDescription,
          progress: 0.0,
          currentStep: 'Analyzing description...',
        );
        onProgress?.call(
          jobId,
          ProcessingStatus.analyzingDescription,
          0.0,
          'Analyzing description...',
        );

        final descriptionRecipe =
            await LlmRecipeExtractionService.tryDescriptionOnly(
          description: description,
          llmService: _llmService!,
          videoTitle: videoFileName,
          sourceUrl: sourceUrl,
          sourcePlatform: sourcePlatform,
        );

        if (descriptionRecipe != null) {
          // Fast path succeeded — skip full pipeline
          await _updateJob(
            jobId,
            progress: 0.05,
            currentStep: 'Recipe found in description!',
          );
          onProgress?.call(
            jobId,
            ProcessingStatus.analyzingDescription,
            0.05,
            'Recipe found in description!',
          );

          // Calculate processing time
          final startTime =
              (await _databaseService.getProcessingJob(jobId))?.createdAt ??
                  DateTime.now();
          final processingTimeSeconds =
              DateTime.now().difference(startTime).inSeconds;

          // Add processing time and confidence
          var recipe = descriptionRecipe.copyWith(
            metadata: descriptionRecipe.metadata?.copyWith(
              processingTimeSeconds: processingTimeSeconds,
              description: description,
            ),
          );

          final confidenceScore = ConfidenceCalculatorService.calculate(recipe);
          recipe = recipe.copyWith(
            metadata:
                recipe.metadata?.copyWith(confidenceScore: confidenceScore),
          );

          final recipeId = await _databaseService.insertRecipe(recipe);

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

          return jobId;
        }
      }

      // Step 1: Extract audio from video
      await _updateJob(
        jobId,
        status: ProcessingStatus.transcribing,
        progress: 0.05,
        currentStep: 'Extracting audio from video...',
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.transcribing,
        0.05,
        'Extracting audio from video...',
      );

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

      // Step 2: Request speech permission and transcribe audio to text
      final hasPermission = await _speechService.requestPermission();
      if (!hasPermission) {
        throw Exception(
          'Speech recognition permission denied. '
          'Please grant permission in Settings > Privacy & Security > Speech Recognition.',
        );
      }

      final transcriptionResult = await _speechService.transcribeAudio(
        audioPath,
        onProgress: (p) {
          final overallProgress = 0.1 + (p * 0.35); // 10% - 45%
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
        progress: 0.45,
        currentStep: 'Extracting frames from video...',
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.extractingText,
        0.45,
        'Extracting frames from video...',
      );

      framePaths = await _frameService.extractFrames(
        videoPath,
        onProgress: (p) {
          final overallProgress = 0.45 + (p * 0.1); // 45% - 55%
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
        progress: 0.55,
        currentStep: 'Recognizing text from frames...',
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.extractingText,
        0.55,
        'Recognizing text from frames...',
      );

      // Step 4: Perform OCR on frames
      final ocrText = await _ocrService.recognizeAndDeduplicateFrames(
        framePaths,
        onProgress: (p) {
          final overallProgress = 0.55 + (p * 0.25); // 55% - 80%
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

      // Calculate processing time
      final startTime =
          (await _databaseService.getProcessingJob(jobId))?.createdAt ??
              DateTime.now();
      final processingTimeSeconds =
          DateTime.now().difference(startTime).inSeconds;

      final baseMetadata = RecipeMetadata(
        transcript: transcript,
        ocrText: ocrText,
        processingTimeSeconds: processingTimeSeconds,
        frameCount: framePaths.length,
        description: description,
      );

      Recipe? recipe;

      // Step 5: Try LLM extraction if available
      if (llmAvailable) {
        await _updateJob(
          jobId,
          status: ProcessingStatus.aiExtracting,
          progress: 0.80,
          currentStep: 'Extracting recipe with AI...',
        );
        onProgress?.call(
          jobId,
          ProcessingStatus.aiExtracting,
          0.80,
          'Extracting recipe with AI...',
        );

        recipe = await LlmRecipeExtractionService.tryFullLlm(
          transcript: transcript,
          ocrText: ocrText,
          description: description,
          llmService: _llmService!,
          videoTitle: videoFileName,
          sourceUrl: sourceUrl,
          sourcePlatform: sourcePlatform,
          existingMetadata: baseMetadata,
        );
      }

      // Step 6: Heuristic fallback
      if (recipe == null) {
        await _updateJob(
          jobId,
          status: ProcessingStatus.parsing,
          progress: 0.90,
          currentStep: 'Parsing recipe...',
        );
        onProgress?.call(
          jobId,
          ProcessingStatus.parsing,
          0.90,
          'Parsing recipe...',
        );

        recipe = await RecipeParsingService.parseRecipe(
          transcript: transcript,
          ocrText: ocrText,
          videoTitle: videoFileName,
          sourceUrl: sourceUrl,
          sourcePlatform: sourcePlatform,
          description: description,
          metadata: baseMetadata.copyWith(processingMethod: 'heuristic'),
        );

        // Run cross-reference check on heuristic results
        final crossRef = CrossReferenceChecker.check(
          ingredients: recipe.ingredients,
          directions: recipe.directions,
        );

        if (crossRef.autoAddedIngredients.isNotEmpty ||
            crossRef.warnings.isNotEmpty) {
          recipe = recipe.copyWith(
            ingredients: [
              ...recipe.ingredients,
              ...crossRef.autoAddedIngredients,
            ],
            metadata: recipe.metadata?.copyWith(
              warnings: crossRef.warnings.isNotEmpty ? crossRef.warnings : null,
            ),
          );
        }
      }

      // Step 7: Calculate confidence score
      await _updateJob(
        jobId,
        progress: 0.95,
        currentStep: 'Calculating confidence...',
      );
      onProgress?.call(
        jobId,
        ProcessingStatus.parsing,
        0.95,
        'Calculating confidence...',
      );

      final confidenceScore = ConfidenceCalculatorService.calculate(recipe);
      recipe = recipe.copyWith(
        metadata: recipe.metadata?.copyWith(confidenceScore: confidenceScore) ??
            RecipeMetadata(confidenceScore: confidenceScore),
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
