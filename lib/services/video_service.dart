import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/recipe.dart';
import 'video_page_extractor.dart';
import 'web_recipe_extractor.dart';

/// Result of a download attempt — either a video file or an extracted recipe.
sealed class DownloadResult {}

class VideoDownloaded extends DownloadResult {
  final String filePath;
  VideoDownloaded(this.filePath);
}

class WebRecipeExtracted extends DownloadResult {
  final Recipe recipe;
  final String extractionMethod;
  WebRecipeExtracted(this.recipe, this.extractionMethod);
}

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
  final String? description;

  VideoMetadata({
    required this.title,
    required this.duration,
    this.thumbnailPath,
    this.sourceUrl,
    required this.localPath,
    this.fileSizeBytes,
    this.resolution,
    this.description,
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
      'description': description,
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
      description: json['description'] as String?,
    );
  }
}

/// Progress callback for video operations
typedef ProgressCallback = void Function(double progress, String status);

/// Service for handling video input, download, and metadata extraction
class VideoService {
  final Dio _dio = Dio();
  final YoutubeExplode _youtubeExplode = YoutubeExplode();

  /// Cached metadata from the last download
  String? _lastVideoTitle;
  String? _lastVideoDescription;

  /// List of platforms with optimized download support
  static const supportedPlatforms = [
    'YouTube',
    'Instagram',
    'TikTok',
    'Direct Link',
    'Any video URL',
  ];

  /// Validates if a string is a valid video URL
  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Checks if a URL is from a supported platform (YouTube, Instagram, TikTok)
  bool isSupportedPlatform(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      return host.contains('youtube.com') ||
          host.contains('youtu.be') ||
          host.contains('instagram.com') ||
          host.contains('tiktok.com');
    } catch (e) {
      return false;
    }
  }

  /// Returns the platform name for a URL, or null if unsupported
  String? getPlatformName(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      if (host.contains('youtube.com') || host.contains('youtu.be')) {
        return 'YouTube';
      } else if (host.contains('instagram.com')) {
        return 'Instagram';
      } else if (host.contains('tiktok.com')) {
        return 'TikTok';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Detects the type of video URL (YouTube, Instagram, TikTok, direct, etc.)
  String detectUrlType(String url) {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();

    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return 'youtube';
    } else if (host.contains('instagram.com')) {
      return 'instagram';
    } else if (host.contains('tiktok.com')) {
      return 'tiktok';
    } else if (url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.avi') ||
        url.endsWith('.mkv') ||
        url.endsWith('.m4v') ||
        url.endsWith('.webm')) {
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

  /// Downloads a video from a URL, or extracts a recipe from an HTML page.
  ///
  /// Supports YouTube, Instagram, TikTok (optimized), direct video URLs,
  /// any URL that serves video content or has og:video meta tags, and
  /// HTML pages containing recipe data (JSON-LD or heuristic extraction).
  ///
  /// Returns [VideoDownloaded] for video files, or [WebRecipeExtracted]
  /// if a recipe was found directly on an HTML page.
  Future<DownloadResult> downloadVideo(
    String url, {
    ProgressCallback? onProgress,
  }) async {
    final urlType = detectUrlType(url);

    switch (urlType) {
      case 'youtube':
        return VideoDownloaded(
            await _downloadYouTubeVideo(url, onProgress: onProgress));
      case 'instagram':
        return VideoDownloaded(
            await _downloadInstagramVideo(url, onProgress: onProgress));
      case 'tiktok':
        return VideoDownloaded(
            await _downloadTikTokVideo(url, onProgress: onProgress));
      case 'direct':
        return VideoDownloaded(
            await _downloadDirectVideo(url, onProgress: onProgress));
      default:
        return await _downloadUnknownUrl(url, onProgress: onProgress);
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
      _lastVideoTitle = video.title;
      _lastVideoDescription = video.description;

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

  static const _mobileUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/17.0 Mobile/15E148 Safari/604.1';

  /// Downloads an Instagram video by fetching the page HTML and extracting
  /// the actual video URL.
  Future<String> _downloadInstagramVideo(
    String url, {
    ProgressCallback? onProgress,
  }) async {
    _lastVideoTitle = null;
    _lastVideoDescription = null;

    try {
      onProgress?.call(0.1, 'Loading Instagram page...');

      final normalizedUrl = VideoPageExtractor.normalizeInstagramUrl(url);

      final response = await _dio.get<String>(
        normalizedUrl,
        options: Options(
          headers: {
            'User-Agent': _mobileUserAgent,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      final html = response.data;
      if (html == null || html.isEmpty) {
        throw VideoException(
          'Could not load Instagram page. The video may be private or the link may be invalid.',
          code: 'INSTAGRAM_PAGE_EMPTY',
        );
      }

      onProgress?.call(0.3, 'Extracting video URL...');

      final extracted = VideoPageExtractor.extractInstagramVideoData(html);
      if (extracted == null) {
        throw VideoException(
          'Could not find video. The post may be private or Instagram may have changed its page format.',
          code: 'INSTAGRAM_VIDEO_NOT_FOUND',
        );
      }

      _lastVideoTitle = extracted.title;
      _lastVideoDescription = extracted.description;

      onProgress?.call(0.4, 'Downloading video...');

      return await _downloadVideoFile(
        extracted.videoUrl,
        onProgress: onProgress,
        refererUrl: 'https://www.instagram.com/',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw VideoException(
          'This Instagram video is private or requires login.',
          code: 'INSTAGRAM_PRIVATE',
        );
      }
      if (e.response?.statusCode == 429) {
        throw VideoException(
          'Instagram rate limit reached. Please try again in a few minutes.',
          code: 'INSTAGRAM_RATE_LIMITED',
        );
      }
      throw VideoException(
        'Failed to download Instagram video: $e',
        code: 'INSTAGRAM_DOWNLOAD_FAILED',
      );
    } catch (e) {
      if (e is VideoException) rethrow;
      throw VideoException(
        'Failed to download Instagram video: $e',
        code: 'INSTAGRAM_DOWNLOAD_FAILED',
      );
    }
  }

  /// Downloads a TikTok video by fetching the page HTML and extracting
  /// the actual video URL.
  Future<String> _downloadTikTokVideo(
    String url, {
    ProgressCallback? onProgress,
  }) async {
    _lastVideoTitle = null;
    _lastVideoDescription = null;

    try {
      onProgress?.call(0.1, 'Loading TikTok page...');

      final response = await _dio.get<String>(
        url,
        options: Options(
          headers: {
            'User-Agent': _mobileUserAgent,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
          followRedirects: true,
          maxRedirects: 10,
        ),
      );

      final html = response.data;
      if (html == null || html.isEmpty) {
        throw VideoException(
          'Could not load TikTok page. The video may be private or the link may be invalid.',
          code: 'TIKTOK_PAGE_EMPTY',
        );
      }

      onProgress?.call(0.3, 'Extracting video URL...');

      final extracted = VideoPageExtractor.extractTikTokVideoData(html);
      if (extracted == null) {
        throw VideoException(
          'Could not find video. The post may be private or TikTok may have changed its page format.',
          code: 'TIKTOK_VIDEO_NOT_FOUND',
        );
      }

      _lastVideoTitle = extracted.title;
      _lastVideoDescription = extracted.description;

      onProgress?.call(0.4, 'Downloading video...');

      return await _downloadVideoFile(
        extracted.videoUrl,
        onProgress: onProgress,
        refererUrl: 'https://www.tiktok.com/',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw VideoException(
          'This TikTok video is private or requires login.',
          code: 'TIKTOK_PRIVATE',
        );
      }
      if (e.response?.statusCode == 429) {
        throw VideoException(
          'TikTok rate limit reached. Please try again in a few minutes.',
          code: 'TIKTOK_RATE_LIMITED',
        );
      }
      throw VideoException(
        'Failed to download TikTok video: $e',
        code: 'TIKTOK_DOWNLOAD_FAILED',
      );
    } catch (e) {
      if (e is VideoException) rethrow;
      throw VideoException(
        'Failed to download TikTok video: $e',
        code: 'TIKTOK_DOWNLOAD_FAILED',
      );
    }
  }

  /// Downloads a video from a direct URL (e.g. .mp4, .mov).
  Future<String> _downloadDirectVideo(
    String url, {
    ProgressCallback? onProgress,
  }) async {
    _lastVideoTitle = null;
    _lastVideoDescription = null;

    try {
      onProgress?.call(0.1, 'Downloading video...');
      return await _downloadVideoFile(url, onProgress: onProgress);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw VideoException(
          'This video is private or requires login.',
          code: 'URL_PRIVATE',
        );
      }
      throw VideoException(
        'Could not reach this URL. Please check the link and try again.',
        code: 'URL_UNREACHABLE',
      );
    } catch (e) {
      if (e is VideoException) rethrow;
      throw VideoException(
        'Failed to download video: $e',
        code: 'DIRECT_DOWNLOAD_FAILED',
      );
    }
  }

  /// Probes an unknown URL via HEAD request and attempts to download video.
  ///
  /// If Content-Type is video/*, downloads directly. If text/html, fetches
  /// the page and tries: 1) og:video extraction, 2) web recipe extraction.
  /// Otherwise throws.
  Future<DownloadResult> _downloadUnknownUrl(
    String url, {
    ProgressCallback? onProgress,
  }) async {
    _lastVideoTitle = null;
    _lastVideoDescription = null;

    try {
      onProgress?.call(0.05, 'Checking URL...');

      // HEAD request to probe Content-Type
      final headResponse = await _dio.head<dynamic>(
        url,
        options: Options(
          headers: {'User-Agent': _mobileUserAgent},
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      final contentType =
          headResponse.headers.value('content-type')?.toLowerCase() ?? '';

      if (contentType.startsWith('video/')) {
        onProgress?.call(0.1, 'Downloading video...');
        return VideoDownloaded(
            await _downloadVideoFile(url, onProgress: onProgress));
      }

      if (contentType.startsWith('text/html')) {
        onProgress?.call(0.1, 'Loading page...');

        final response = await _dio.get<String>(
          url,
          options: Options(
            headers: {
              'User-Agent': _mobileUserAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
            followRedirects: true,
            maxRedirects: 5,
          ),
        );

        final html = response.data;
        if (html == null || html.isEmpty) {
          throw VideoException(
            'Could not find a video or recipe on this page. '
            'The site may require login or block direct access.',
            code: 'NOT_A_VIDEO',
          );
        }

        // Try og:video extraction first
        onProgress?.call(0.3, 'Extracting video URL...');

        final extracted = VideoPageExtractor.extractGenericVideoData(html);
        if (extracted != null) {
          _lastVideoTitle = extracted.title;
          _lastVideoDescription = extracted.description;

          onProgress?.call(0.4, 'Downloading video...');
          return VideoDownloaded(await _downloadVideoFile(extracted.videoUrl,
              onProgress: onProgress));
        }

        // No video found — try web recipe extraction
        onProgress?.call(0.5, 'Looking for recipe data...');

        final recipeResult =
            WebRecipeExtractor.extractFromHtml(html, sourceUrl: url);
        if (recipeResult != null) {
          onProgress?.call(1.0, 'Recipe found!');
          return WebRecipeExtracted(
            recipeResult.recipe,
            recipeResult.extractionMethod,
          );
        }

        throw VideoException(
          'Could not find a video or recipe on this page. '
          'The site may require login or block direct access.',
          code: 'NOT_A_VIDEO',
        );
      }

      // Content-Type is neither video nor HTML
      throw VideoException(
        'Could not find a video or recipe on this page. '
        'The site may require login or block direct access.',
        code: 'NOT_A_VIDEO',
      );
    } on DioException catch (e) {
      if (e is VideoException) rethrow;
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw VideoException(
          'This video is private or requires login.',
          code: 'URL_PRIVATE',
        );
      }
      throw VideoException(
        'Could not reach this URL. Please check the link and try again.',
        code: 'URL_UNREACHABLE',
      );
    } catch (e) {
      if (e is VideoException) rethrow;
      throw VideoException(
        'Could not reach this URL. Please check the link and try again.',
        code: 'URL_UNREACHABLE',
      );
    }
  }

  /// Downloads a video file from a direct URL with progress tracking.
  ///
  /// Validates that the downloaded file is >10KB to catch expired URLs
  /// that return error pages instead of actual video data.
  Future<String> _downloadVideoFile(
    String videoUrl, {
    ProgressCallback? onProgress,
    String? refererUrl,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${appDir.path}/videos');
    if (!await videosDir.exists()) {
      await videosDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
    final filePath = '${videosDir.path}/$fileName';

    await _dio.download(
      videoUrl,
      filePath,
      options: Options(
        headers: {
          'User-Agent': _mobileUserAgent,
          if (refererUrl != null) 'Referer': refererUrl,
        },
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = 0.4 + (received / total * 0.55);
          onProgress?.call(
            progress,
            'Downloading: ${(received / 1024 / 1024).toStringAsFixed(1)} MB',
          );
        }
      },
    );

    // Validate file size — expired URLs often return small error pages
    final file = File(filePath);
    final fileSize = await file.length();
    if (fileSize < 10240) {
      await file.delete();
      throw VideoException(
        'Downloaded file is too small to be a video. The video URL may have expired.',
        code: 'DOWNLOAD_TOO_SMALL',
      );
    }

    onProgress?.call(1.0, 'Download complete!');
    return filePath;
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
        description: _lastVideoDescription,
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
    // Use actual YouTube title if available
    if (_lastVideoTitle != null && _lastVideoTitle!.isNotEmpty) {
      return _lastVideoTitle!;
    }

    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(sourceUrl);
        final host = uri.host.toLowerCase();
        if (host.contains('youtube.com') || host.contains('youtu.be')) {
          return 'YouTube Video';
        } else if (host.contains('instagram.com')) {
          return 'Instagram Video';
        } else if (host.contains('tiktok.com')) {
          return 'TikTok Video';
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

  /// Fetches just the YouTube description without downloading the video.
  /// Useful for the description-only fast path.
  Future<String?> fetchYouTubeDescription(String url) async {
    try {
      final yt = YoutubeExplode();
      try {
        final video = await yt.videos.get(url);
        return video.description;
      } finally {
        yt.close();
      }
    } catch (e) {
      debugPrint('Failed to fetch YouTube description: $e');
      return null;
    }
  }

  void dispose() {
    _youtubeExplode.close();
  }
}
