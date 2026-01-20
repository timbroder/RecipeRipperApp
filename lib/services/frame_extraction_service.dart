import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for extracting frames from video files using FFmpeg
class FrameExtractionService {
  /// Default FPS for frame extraction (1 frame every 0.6 seconds)
  static const double defaultFps = 1.0 / 0.6;

  /// Maximum number of frames to extract to prevent memory issues
  static const int maxFrames = 180;

  /// Extracts frames from a video file at specified FPS
  ///
  /// [videoPath] - Path to the video file
  /// [fps] - Frames per second to extract (default: 1 frame per 0.6 seconds)
  /// [maxFrameCount] - Maximum frames to extract (default: 180)
  /// [onProgress] - Optional callback for progress updates (0.0 to 1.0)
  /// Returns list of paths to extracted frame images
  Future<List<String>> extractFrames(
    String videoPath, {
    double fps = defaultFps,
    int maxFrameCount = maxFrames,
    void Function(double progress)? onProgress,
  }) async {
    if (!await File(videoPath).exists()) {
      throw Exception('Video file not found: $videoPath');
    }

    // Create output directory in temporary directory
    final tempDir = await getTemporaryDirectory();
    final videoFileName = path.basenameWithoutExtension(videoPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputDir = path.join(
      tempDir.path,
      'frames_${videoFileName}_$timestamp',
    );

    final outputDirObj = Directory(outputDir);
    if (!await outputDirObj.exists()) {
      await outputDirObj.create(recursive: true);
    }

    // Extract frames using FFmpeg
    // -vf fps=X: extract X frames per second
    // -vframes N: limit to N frames
    // -q:v 2: high quality JPEG (1-31, lower is better)
    final outputPattern = path.join(outputDir, 'frame_%04d.jpg');
    final command =
        '-i "$videoPath" -vf fps=$fps -vframes $maxFrameCount -q:v 2 "$outputPattern"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      final failStackTrace = await session.getFailStackTrace();
      throw Exception(
        'Failed to extract frames from video.\nOutput: $output\nStack: $failStackTrace',
      );
    }

    // Get list of extracted frame files
    final framePaths = <String>[];
    final dir = Directory(outputDir);
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.jpg')) {
        framePaths.add(entity.path);
      }
    }

    // Sort frames by filename to maintain order
    framePaths.sort();

    if (framePaths.isEmpty) {
      throw Exception('No frames were extracted from video');
    }

    return framePaths;
  }

  /// Extracts a single frame from a video at a specific time
  ///
  /// [videoPath] - Path to the video file
  /// [timeInSeconds] - Time position to extract frame (default: 1.0 second)
  /// Returns path to the extracted frame
  Future<String> extractSingleFrame(
    String videoPath, {
    double timeInSeconds = 1.0,
  }) async {
    if (!await File(videoPath).exists()) {
      throw Exception('Video file not found: $videoPath');
    }

    // Create output path in temporary directory
    final tempDir = await getTemporaryDirectory();
    final videoFileName = path.basenameWithoutExtension(videoPath);
    final outputPath = path.join(
      tempDir.path,
      'frame_${videoFileName}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    // Extract frame at specific time
    // -ss: seek to position (in seconds)
    // -vframes 1: extract only 1 frame
    // -q:v 2: high quality
    final command =
        '-ss $timeInSeconds -i "$videoPath" -vframes 1 -q:v 2 "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      throw Exception('Failed to extract frame from video: $output');
    }

    // Verify output file was created
    if (!await File(outputPath).exists()) {
      throw Exception('Frame extraction completed but output file not found');
    }

    return outputPath;
  }

  /// Cleans up extracted frame files
  Future<void> deleteFrames(List<String> framePaths) async {
    for (final framePath in framePaths) {
      try {
        final file = File(framePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Continue with other files if one fails
      }
    }

    // Try to delete parent directory if empty
    if (framePaths.isNotEmpty) {
      try {
        final parentDir = Directory(path.dirname(framePaths.first));
        if (await parentDir.exists()) {
          final contents = await parentDir.list().toList();
          if (contents.isEmpty) {
            await parentDir.delete();
          }
        }
      } catch (e) {
        // Silently fail - cleanup is not critical
      }
    }
  }

  /// Cleans up a single frame file
  Future<void> deleteFrame(String framePath) async {
    try {
      final file = File(framePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silently fail - cleanup is not critical
    }
  }
}
