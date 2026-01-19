import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Exception thrown when video operations fail
class VideoException implements Exception {
  final String message;
  final String? code;

  VideoException(this.message, {this.code});

  @override
  String toString() =>
      'VideoException: $message${code != null ? ' ($code)' : ''}';
}

/// Represents a video source (URL or local file)
class VideoSource {
  final String? url;
  final String? filePath;
  final VideoSourceType type;

  VideoSource.url(this.url)
      : filePath = null,
        type = VideoSourceType.url;

  VideoSource.file(this.filePath)
      : url = null,
        type = VideoSourceType.file;

  bool get isUrl => type == VideoSourceType.url;
  bool get isFile => type == VideoSourceType.file;
}

enum VideoSourceType { url, file }

/// Video metadata extracted from a video file
class VideoMetadata {
  final String title;
  final Duration duration;
  final String? thumbnailPath;
  final String? sourceUrl;
  final String localPath;
  final int? fileSizeBytes;
  final String? resolution;

  VideoMetadata({
    required this.title,
    required this.duration,
    this.thumbnailPath,
    this.sourceUrl,
    required this.localPath,
    this.fileSizeBytes,
    this.resolution,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'duration_seconds': duration.inSeconds,
      'thumbnail_path': thumbnailPath,
      'source_url': sourceUrl,
      'local_path': localPath,
      'file_size_bytes': fileSizeBytes,
      'resolution': resolution,
    };
  }

  factory VideoMetadata.fromJson(Map<String, dynamic> json) {
    return VideoMetadata(
      title: json['title'] as String,
      duration: Duration(seconds: json['duration_seconds'] as int),
      thumbnailPath: json['thumbnail_path'] as String?,
      sourceUrl: json['source_url'] as String?,
      localPath: json['local_path'] as String,
      fileSizeBytes: json['file_size_bytes'] as int?,
      resolution: json['resolution'] as String?,
    );
  }
}

/// Progress callback for video operations
typedef ProgressCallback = void Function(double progress, String status);

/// Service for handling video input, download, and metadata extraction
class VideoService {
  final Dio _dio = Dio();
  final YoutubeExplode _youtubeExplode = YoutubeExplode();

  /// Validates if a string is a valid video URL
  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Detects the type of video URL (YouTube, direct, etc.)
  String detectUrlType(String url) {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();

    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return 'youtube';
    } else if (host.contains('vimeo.com')) {
      return 'vimeo';
    } else if (host.contains('dailymotion.com')) {
      return 'dailymotion';
    } else if (url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.avi') ||
        url.endsWith('.mkv')) {
      return 'direct';
    } else {
      return 'unknown';
    }
  }

  /// Opens the device's file picker to select a local video file
  Future<String?> pickVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'm4v', 'webm'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        // Copy to app's documents directory for consistent access
        return await _copyToAppStorage(filePath);
      }

      return null;
    } catch (e) {
      throw VideoException('Failed to pick video file: $e',
          code: 'PICK_FAILED');
    }
  }

  /// Downloads a video from a URL
  Future<String> downloadVideo(
    String url, {
    ProgressCallback? onProgress,
  }) async {
    final urlType = detectUrlType(url);

    switch (urlType) {
      case 'youtube':
        return await _downloadYouTubeVideo(url, onProgress: onProgress);
      case 'direct':
        return await _downloadDirectVideo(url, onProgress: onProgress);
      default:
        throw VideoException(
          'Unsupported video platform. Please use YouTube or direct video links.',
          code: 'UNSUPPORTED_PLATFORM',
        );
    }
  }

  /// Downloads a YouTube video
  Future<String> _downloadYouTubeVideo(
    String url, {
    ProgressCallback? onProgress,
  }) async {
    try {
      onProgress?.call(0.1, 'Fetching video information...');

      // Get video metadata
      final video = await _youtubeExplode.videos.get(url);

      onProgress?.call(0.2, 'Preparing download...');

      // Get manifest and select best quality
      final manifest =
          await _youtubeExplode.videos.streamsClient.getManifest(video.id);

      if (manifest.muxed.isEmpty) {
        throw VideoException('No suitable video stream found',
            code: 'NO_STREAM');
      }

      final streamInfo = manifest.muxed.withHighestBitrate();

      onProgress?.call(0.3, 'Downloading video...');

      // Generate local file path
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${videosDir.path}/$fileName';

      // Download video stream
      final file = File(filePath);
      final stream = _youtubeExplode.videos.streamsClient.get(streamInfo);

      final output = file.openWrite();
      var received = 0;
      final total = streamInfo.size.totalBytes;

      await for (final chunk in stream) {
        output.add(chunk);
        received += chunk.length;
        final progress = 0.3 + (received / total * 0.6); // 30-90% for download
        onProgress?.call(progress,
            'Downloading: ${(received / 1024 / 1024).toStringAsFixed(1)} MB');
      }

      await output.close();

      onProgress?.call(1.0, 'Download complete!');

      return filePath;
    } catch (e) {
      if (e is VideoException) rethrow;
      throw VideoException('Failed to download YouTube video: $e',
          code: 'YOUTUBE_DOWNLOAD_FAILED');
    } finally {
      _youtubeExplode.close();
    }
  }

  /// Downloads a direct video URL
  Future<String> _downloadDirectVideo(
    String url, {
    ProgressCallback? onProgress,
  }) async {
    try {
      onProgress?.call(0.1, 'Starting download...');

      // Generate local file path
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      final extension = path.extension(url).replaceAll('.', '');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = '${videosDir.path}/$fileName';

      // Download with progress tracking
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress =
                0.1 + (received / total * 0.8); // 10-90% for download
            onProgress?.call(
              progress,
              'Downloading: ${(received / 1024 / 1024).toStringAsFixed(1)} MB',
            );
          }
        },
      );

      onProgress?.call(1.0, 'Download complete!');

      return filePath;
    } catch (e) {
      throw VideoException('Failed to download video: $e',
          code: 'DOWNLOAD_FAILED');
    }
  }

  /// Extracts metadata from a video file
  Future<VideoMetadata> extractMetadata(
    String filePath, {
    String? sourceUrl,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw VideoException('Video file not found', code: 'FILE_NOT_FOUND');
      }

      // Get file size
      final fileSizeBytes = await file.length();

      // Generate thumbnail
      final thumbnailPath = await _generateThumbnail(filePath);

      // Get video duration and other metadata using video_player
      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      final duration = controller.value.duration;
      final size = controller.value.size;
      final resolution = size.width > 0 && size.height > 0
          ? '${size.width.toInt()}x${size.height.toInt()}'
          : null;

      await controller.dispose();

      // Generate title from file name or URL
      final title = _generateTitle(filePath, sourceUrl);

      return VideoMetadata(
        title: title,
        duration: duration,
        thumbnailPath: thumbnailPath,
        sourceUrl: sourceUrl,
        localPath: filePath,
        fileSizeBytes: fileSizeBytes,
        resolution: resolution,
      );
    } catch (e) {
      if (e is VideoException) rethrow;
      throw VideoException('Failed to extract video metadata: $e',
          code: 'METADATA_EXTRACTION_FAILED');
    }
  }

  /// Generates a thumbnail from the video's first frame
  Future<String?> _generateThumbnail(String videoPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory('${appDir.path}/thumbnails');
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }

      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailsDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 85,
      );

      return thumbnail;
    } catch (e) {
      // Thumbnail generation is non-critical, so we just log and continue
      debugPrint('Warning: Failed to generate thumbnail: $e');
      return null;
    }
  }

  /// Copies a video file to app storage
  Future<String> _copyToAppStorage(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      final sourceFile = File(sourcePath);
      final extension = path.extension(sourcePath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
      final destPath = '${videosDir.path}/$fileName';

      await sourceFile.copy(destPath);

      return destPath;
    } catch (e) {
      throw VideoException('Failed to copy video to app storage: $e',
          code: 'COPY_FAILED');
    }
  }

  /// Generates a title from file path or URL
  String _generateTitle(String filePath, String? sourceUrl) {
    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(sourceUrl);
        if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
          return 'YouTube Video';
        }
        return 'Video from ${uri.host}';
      } catch (e) {
        // Fall through to file name
      }
    }

    // Use file name without extension
    final fileName = path.basenameWithoutExtension(filePath);
    if (fileName.contains(RegExp(r'^\d+$'))) {
      // If filename is just a timestamp, return a generic name
      return 'Imported Video';
    }

    return fileName;
  }

  /// Deletes a video file and its thumbnail
  Future<void> deleteVideo(String videoPath, {String? thumbnailPath}) async {
    try {
      final videoFile = File(videoPath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }

      if (thumbnailPath != null) {
        final thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }
    } catch (e) {
      throw VideoException('Failed to delete video: $e', code: 'DELETE_FAILED');
    }
  }

  /// Gets the total size of all stored videos
  Future<int> getTotalVideoSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/videos');

      if (!await videosDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in videosDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Cleans up old videos to free up space
  Future<void> cleanupOldVideos({int maxAgeInDays = 7}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/videos');

      if (!await videosDir.exists()) {
        return;
      }

      final now = DateTime.now();
      await for (final entity in videosDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          if (age.inDays > maxAgeInDays) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Warning: Failed to cleanup old videos: $e');
    }
  }

  void dispose() {
    _youtubeExplode.close();
  }
}
