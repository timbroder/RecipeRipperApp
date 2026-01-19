import 'dart:io';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for extracting audio from video files using FFmpeg
class AudioExtractionService {
  /// Extracts audio from a video file and saves it as WAV format
  ///
  /// [videoPath] - Path to the video file
  /// [onProgress] - Optional callback for progress updates (0.0 to 1.0)
  /// Returns the path to the extracted audio file
  Future<String> extractAudio(
    String videoPath, {
    void Function(double progress)? onProgress,
  }) async {
    if (!await File(videoPath).exists()) {
      throw Exception('Video file not found: $videoPath');
    }

    // Create output path in temporary directory
    final tempDir = await getTemporaryDirectory();
    final videoFileName = path.basenameWithoutExtension(videoPath);
    final outputPath = path.join(
      tempDir.path,
      'audio_${videoFileName}_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    // Extract audio using FFmpeg
    // Use WAV format for better compatibility with speech recognition
    // -vn: no video
    // -acodec pcm_s16le: PCM signed 16-bit little-endian (WAV format)
    // -ar 16000: 16kHz sample rate (optimal for speech recognition)
    // -ac 1: mono audio (reduces size and is sufficient for speech)
    final command =
        '-i "$videoPath" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      final failStackTrace = await session.getFailStackTrace();
      throw Exception(
        'Failed to extract audio from video.\nOutput: $output\nStack: $failStackTrace',
      );
    }

    // Verify output file was created
    if (!await File(outputPath).exists()) {
      throw Exception('Audio extraction completed but output file not found');
    }

    return outputPath;
  }

  /// Gets the duration of a video file in seconds
  Future<double> getVideoDuration(String videoPath) async {
    if (!await File(videoPath).exists()) {
      throw Exception('Video file not found: $videoPath');
    }

    // Use ffmpeg -i to get duration from video metadata
    final session = await FFmpegKit.execute('-i "$videoPath" 2>&1');
    final output = await session.getOutput();

    // Parse duration from output
    final durationRegex = RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2}\.\d{2})');
    final match = durationRegex.firstMatch(output ?? '');

    if (match != null) {
      final hours = int.parse(match.group(1)!);
      final minutes = int.parse(match.group(2)!);
      final seconds = double.parse(match.group(3)!);
      return hours * 3600 + minutes * 60 + seconds;
    }

    return 0.0;
  }

  /// Cleans up extracted audio file
  Future<void> deleteAudioFile(String audioPath) async {
    try {
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silently fail - cleanup is not critical
    }
  }
}
