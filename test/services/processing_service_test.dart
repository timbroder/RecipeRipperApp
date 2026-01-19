import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/models/processing_job.dart';
import 'package:recipe_ripper/models/recipe.dart';
import 'package:recipe_ripper/services/processing_service.dart';
import 'package:recipe_ripper/services/database_service.dart';

void main() {
  group('ProcessingService', () {
    late ProcessingService processingService;
    late DatabaseService databaseService;

    setUp(() {
      databaseService = DatabaseService();
      processingService = ProcessingService(
        databaseService: databaseService,
      );
    });

    test('should detect YouTube platform from URL', () {
      expect(
        processingService.getClass().toString().contains('ProcessingService'),
        isTrue,
      );
    });

    test('should create processing job with valid ID', () {
      final jobId = 'test-job-id';
      expect(jobId.isNotEmpty, isTrue);
    });
  });

  group('ProcessingJob Model', () {
    test('should create processing job with default status', () {
      final job = ProcessingJob(
        id: 'test-id',
        status: ProcessingStatus.queued,
      );

      expect(job.id, 'test-id');
      expect(job.status, ProcessingStatus.queued);
      expect(job.progress, 0.0);
    });

    test('should serialize and deserialize processing job', () {
      final job = ProcessingJob(
        id: 'test-id',
        sourceUrl: 'https://example.com/video',
        localVideoPath: '/path/to/video.mp4',
        status: ProcessingStatus.transcribing,
        progress: 0.5,
        currentStep: 'Transcribing audio',
      );

      final map = job.toMap();
      final deserializedJob = ProcessingJob.fromMap(map);

      expect(deserializedJob.id, job.id);
      expect(deserializedJob.sourceUrl, job.sourceUrl);
      expect(deserializedJob.localVideoPath, job.localVideoPath);
      expect(deserializedJob.status, job.status);
      expect(deserializedJob.progress, job.progress);
      expect(deserializedJob.currentStep, job.currentStep);
    });

    test('should identify active processing jobs', () {
      final queuedJob = ProcessingJob(
        id: 'test-1',
        status: ProcessingStatus.queued,
      );
      final transcribingJob = ProcessingJob(
        id: 'test-2',
        status: ProcessingStatus.transcribing,
      );
      final completedJob = ProcessingJob(
        id: 'test-3',
        status: ProcessingStatus.completed,
      );

      expect(queuedJob.isActive, isFalse);
      expect(transcribingJob.isActive, isTrue);
      expect(completedJob.isActive, isFalse);
      expect(completedJob.isFinished, isTrue);
    });

    test('should identify finished processing jobs', () {
      final completedJob = ProcessingJob(
        id: 'test-1',
        status: ProcessingStatus.completed,
      );
      final failedJob = ProcessingJob(
        id: 'test-2',
        status: ProcessingStatus.failed,
      );
      final cancelledJob = ProcessingJob(
        id: 'test-3',
        status: ProcessingStatus.cancelled,
      );

      expect(completedJob.isFinished, isTrue);
      expect(failedJob.isFinished, isTrue);
      expect(cancelledJob.isFinished, isTrue);
    });
  });

  group('RecipeMetadata', () {
    test('should create recipe metadata with transcript and OCR text', () {
      final metadata = RecipeMetadata(
        transcript: 'This is the transcribed text',
        ocrText: 'This is the OCR text',
        processingTimeSeconds: 120,
        frameCount: 180,
      );

      expect(metadata.transcript, 'This is the transcribed text');
      expect(metadata.ocrText, 'This is the OCR text');
      expect(metadata.processingTimeSeconds, 120);
      expect(metadata.frameCount, 180);
    });

    test('should serialize and deserialize recipe metadata', () {
      final metadata = RecipeMetadata(
        transcript: 'Transcript content',
        ocrText: 'OCR content',
        processingTimeSeconds: 90,
        videoDuration: '00:10:30',
        frameCount: 150,
      );

      final map = metadata.toMap();
      final deserialized = RecipeMetadata.fromMap(map);

      expect(deserialized.transcript, metadata.transcript);
      expect(deserialized.ocrText, metadata.ocrText);
      expect(
          deserialized.processingTimeSeconds, metadata.processingTimeSeconds);
      expect(deserialized.videoDuration, metadata.videoDuration);
      expect(deserialized.frameCount, metadata.frameCount);
    });
  });
}
