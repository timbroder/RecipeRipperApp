import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

/// Data extracted from a video page's HTML.
class ExtractedVideoData {
  final String videoUrl;
  final String? title;
  final String? description;

  ExtractedVideoData({
    required this.videoUrl,
    this.title,
    this.description,
  });
}

/// Extracts video URLs and metadata from video page HTML.
///
/// Uses multiple strategies per platform (meta tags, JSON-LD, embedded JSON)
/// so that if one breaks due to platform changes, others may still work.
/// Also supports generic og:video extraction for unknown sites.
class VideoPageExtractor {
  /// Normalizes an Instagram URL to canonical form.
  ///
  /// Ensures https, strips query params, adds trailing slash.
  static String normalizeInstagramUrl(String url) {
    var uri = Uri.parse(url);

    // Ensure https
    if (uri.scheme == 'http') {
      uri = uri.replace(scheme: 'https');
    }

    // Normalize host: m.instagram.com -> www.instagram.com
    var host = uri.host;
    if (host == 'm.instagram.com') {
      host = 'www.instagram.com';
    } else if (host == 'instagram.com') {
      host = 'www.instagram.com';
    }

    // Strip query params and fragment, ensure trailing slash
    var path = uri.path;
    if (!path.endsWith('/')) {
      path = '$path/';
    }

    return Uri(scheme: 'https', host: host, path: path).toString();
  }

  /// Extracts video data from Instagram page HTML.
  ///
  /// Tries three strategies in order:
  /// 1. og:video meta tags
  /// 2. application/ld+json script tags
  /// 3. Regex for video URLs in embedded JSON
  static ExtractedVideoData? extractInstagramVideoData(String html) {
    return _extractInstagramFromMetaTags(html) ??
        _extractInstagramFromJsonLd(html) ??
        _extractInstagramFromEmbeddedJson(html);
  }

  /// Extracts video data from TikTok page HTML.
  ///
  /// Tries three strategies in order:
  /// 1. __UNIVERSAL_DATA_FOR_REHYDRATION__ script tag
  /// 2. og:video meta tags
  /// 3. Regex for video URLs in script tags
  static ExtractedVideoData? extractTikTokVideoData(String html) {
    return _extractTikTokFromUniversalData(html) ??
        _extractTikTokFromMetaTags(html) ??
        _extractTikTokFromEmbeddedJson(html);
  }

  /// Extracts video data from any HTML page using generic og:video meta tags.
  ///
  /// Works on any site that includes standard Open Graph video tags.
  /// Returns null if no og:video tag is found.
  static ExtractedVideoData? extractGenericVideoData(String html) {
    final document = html_parser.parse(html);

    final videoUrl = _getMetaContent(document, 'og:video:secure_url') ??
        _getMetaContent(document, 'og:video');

    if (videoUrl == null || videoUrl.isEmpty) return null;

    final title = _getMetaContent(document, 'og:title');
    final description = _getMetaContent(document, 'og:description');

    return ExtractedVideoData(
      videoUrl: _unescapeUrl(videoUrl),
      title: title,
      description: description,
    );
  }

  // ---------------------------------------------------------------------------
  // Instagram strategies
  // ---------------------------------------------------------------------------

  static ExtractedVideoData? _extractInstagramFromMetaTags(String html) {
    final document = html_parser.parse(html);

    final videoUrl = _getMetaContent(document, 'og:video:secure_url') ??
        _getMetaContent(document, 'og:video');

    if (videoUrl == null || videoUrl.isEmpty) return null;

    final title = _getMetaContent(document, 'og:title');
    final description = _getMetaContent(document, 'og:description');

    return ExtractedVideoData(
      videoUrl: _unescapeUrl(videoUrl),
      title: title,
      description: description,
    );
  }

  static ExtractedVideoData? _extractInstagramFromJsonLd(String html) {
    final document = html_parser.parse(html);

    final scripts =
        document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      final text = script.text;
      if (text.isEmpty) continue;

      try {
        final json = jsonDecode(text);
        final data = json is List ? json.first : json;

        if (data is Map<String, dynamic>) {
          final contentUrl = data['contentUrl'] as String?;
          if (contentUrl != null && contentUrl.isNotEmpty) {
            return ExtractedVideoData(
              videoUrl: _unescapeUrl(contentUrl),
              title: data['name'] as String?,
              description: data['description'] as String?,
            );
          }
        }
      } catch (_) {
        // JSON parse failed, try next script tag
      }
    }
    return null;
  }

  static ExtractedVideoData? _extractInstagramFromEmbeddedJson(String html) {
    // Look for video_url or playback_url in embedded JSON
    for (final key in ['video_url', 'playback_url']) {
      final pattern = RegExp('"$key"\\s*:\\s*"([^"]+)"');
      final match = pattern.firstMatch(html);
      if (match != null) {
        final url = _unescapeUrl(match.group(1)!);
        if (url.startsWith('http')) {
          return ExtractedVideoData(videoUrl: url);
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // TikTok strategies
  // ---------------------------------------------------------------------------

  static ExtractedVideoData? _extractTikTokFromUniversalData(String html) {
    final document = html_parser.parse(html);

    final script =
        document.querySelector('script#__UNIVERSAL_DATA_FOR_REHYDRATION__');
    if (script == null || script.text.isEmpty) return null;

    try {
      final json = jsonDecode(script.text) as Map<String, dynamic>;
      final defaultScope = json['__DEFAULT_SCOPE__'] as Map<String, dynamic>?;
      if (defaultScope == null) return null;

      final videoDetail =
          defaultScope['webapp.video-detail'] as Map<String, dynamic>?;
      if (videoDetail == null) return null;

      final itemInfo = videoDetail['itemInfo'] as Map<String, dynamic>?;
      final itemStruct = itemInfo?['itemStruct'] as Map<String, dynamic>?;
      if (itemStruct == null) return null;

      final video = itemStruct['video'] as Map<String, dynamic>?;
      if (video == null) return null;

      // Try multiple URL fields in priority order
      String? videoUrl = video['downloadAddr'] as String?;
      videoUrl ??= video['playAddr'] as String?;

      // Try bitrateInfo array
      if (videoUrl == null || videoUrl.isEmpty) {
        final bitrateInfo = video['bitrateInfo'] as List?;
        if (bitrateInfo != null && bitrateInfo.isNotEmpty) {
          final first = bitrateInfo.first as Map<String, dynamic>?;
          videoUrl = first?['PlayAddr']?['UrlList']?.first as String?;
        }
      }

      if (videoUrl == null || videoUrl.isEmpty) return null;

      final desc = itemStruct['desc'] as String?;
      final author = itemStruct['author'] as Map<String, dynamic>?;
      final nickname = author?['nickname'] as String?;

      return ExtractedVideoData(
        videoUrl: _unescapeUrl(videoUrl),
        title: nickname != null ? '$nickname - TikTok' : null,
        description: desc,
      );
    } catch (_) {
      return null;
    }
  }

  static ExtractedVideoData? _extractTikTokFromMetaTags(String html) {
    final document = html_parser.parse(html);

    final videoUrl = _getMetaContent(document, 'og:video:secure_url') ??
        _getMetaContent(document, 'og:video');

    if (videoUrl == null || videoUrl.isEmpty) return null;

    final title = _getMetaContent(document, 'og:title');
    final description = _getMetaContent(document, 'og:description');

    return ExtractedVideoData(
      videoUrl: _unescapeUrl(videoUrl),
      title: title,
      description: description,
    );
  }

  static ExtractedVideoData? _extractTikTokFromEmbeddedJson(String html) {
    for (final key in ['playAddr', 'downloadAddr']) {
      final pattern = RegExp('"$key"\\s*:\\s*"([^"]+)"');
      final match = pattern.firstMatch(html);
      if (match != null) {
        final url = _unescapeUrl(match.group(1)!);
        if (url.startsWith('http')) {
          return ExtractedVideoData(videoUrl: url);
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Gets the content attribute of a meta tag by property name.
  static String? _getMetaContent(dynamic document, String property) {
    final element = document.querySelector('meta[property="$property"]');
    return element?.attributes['content'];
  }

  /// Unescapes common URL escape sequences found in embedded JSON.
  static String _unescapeUrl(String url) {
    return url
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u003d', '=');
  }
}
