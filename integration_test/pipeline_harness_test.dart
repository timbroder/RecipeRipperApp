/// Pipeline harness: runs the app's real URL → recipe pipeline with no UI.
///
/// Run it with `tool/harness.sh <url>` (see the README). It runs on an iOS
/// simulator or a device, so every stage is the code the app ships: the
/// download, metadata extraction, the description fast path, FFmpeg audio
/// and frame extraction, Speech transcription, Vision OCR, Foundation Models
/// and post-processing.
///
/// This file deliberately contains no recipe logic. It calls the same
/// functions, in the same order, as the video preview and processing screens,
/// records a PipelineTrace, and hands the result to the host-side driver
/// (test_driver/integration_test.dart), which prints it and saves it under
/// harness_runs/.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recipe_ripper/services/database_service.dart';
import 'package:recipe_ripper/services/pipeline_trace.dart';
import 'package:recipe_ripper/services/processing_service.dart';
import 'package:recipe_ripper/services/video_service.dart';

const videoUrl = String.fromEnvironment('VIDEO_URL');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'pipeline harness',
    (tester) async {
      final report = <String, dynamic>{
        'url': videoUrl,
        'startedAt': DateTime.now().toIso8601String(),
      };
      final trace = PipelineTrace();
      final clock = Stopwatch()..start();

      // Same services the app builds (main.dart and ProcessingScreen).
      final databaseService = DatabaseService();
      await databaseService.initialize();
      final videoService = VideoService();
      final processingService =
          ProcessingService(databaseService: databaseService);

      try {
        await trace.capture(() async {
          // VideoPreviewScreen._loadVideo
          final prepared = await videoService.prepareFromUrl(videoUrl);

          switch (prepared) {
            case PreparedWebRecipe(:final recipe, :final extractionMethod):
              report['webRecipe'] = {
                'extractionMethod': extractionMethod,
                'recipe': recipe.toJson(),
              };

            case PreparedVideo(:final metadata):
              report['metadata'] = {
                'title': metadata.title,
                'description': metadata.description,
                'durationMs': metadata.duration.inMilliseconds,
                'resolution': metadata.resolution,
                'fileSizeBytes': metadata.fileSizeBytes,
              };

              // VideoPreviewScreen._processVideo → ProcessingScreen
              final jobId = await processingService.processVideo(
                metadata.localPath,
                sourceUrl: metadata.sourceUrl,
                videoTitle: metadata.title,
                description: metadata.description,
              );

              final job = await databaseService.getProcessingJob(jobId);
              final recipeId = job?.recipeId;
              final recipe = recipeId == null
                  ? null
                  : await databaseService.getRecipe(recipeId);
              report['recipe'] = recipe?.toJson();

              await videoService.deleteVideo(
                metadata.localPath,
                thumbnailPath: metadata.thumbnailPath,
              );
          }
        });
      } catch (e, stack) {
        report['error'] = e.toString();
        report['stack'] = stack.toString();
      }

      report['totalMs'] = clock.elapsedMilliseconds;
      report['trace'] = trace.toJson();
      binding.reportData = report;
    },
    // Only runs when given a URL: tool/harness.sh <url>, or
    // --dart-define=VIDEO_URL=<url>.
    skip: videoUrl.isEmpty,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
