import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/video_page_extractor.dart';

void main() {
  group('VideoPageExtractor', () {
    group('normalizeInstagramUrl', () {
      test('should add trailing slash', () {
        expect(
          VideoPageExtractor.normalizeInstagramUrl(
              'https://www.instagram.com/reel/abc123'),
          equals('https://www.instagram.com/reel/abc123/'),
        );
      });

      test('should keep existing trailing slash', () {
        expect(
          VideoPageExtractor.normalizeInstagramUrl(
              'https://www.instagram.com/reel/abc123/'),
          equals('https://www.instagram.com/reel/abc123/'),
        );
      });

      test('should upgrade http to https', () {
        expect(
          VideoPageExtractor.normalizeInstagramUrl(
              'http://www.instagram.com/reel/abc123'),
          equals('https://www.instagram.com/reel/abc123/'),
        );
      });

      test('should normalize m.instagram.com to www', () {
        expect(
          VideoPageExtractor.normalizeInstagramUrl(
              'https://m.instagram.com/reel/abc123'),
          equals('https://www.instagram.com/reel/abc123/'),
        );
      });

      test('should normalize bare instagram.com to www', () {
        expect(
          VideoPageExtractor.normalizeInstagramUrl(
              'https://instagram.com/reel/abc123'),
          equals('https://www.instagram.com/reel/abc123/'),
        );
      });

      test('should strip query params', () {
        expect(
          VideoPageExtractor.normalizeInstagramUrl(
              'https://www.instagram.com/reel/abc123/?igsh=xyz'),
          equals('https://www.instagram.com/reel/abc123/'),
        );
      });
    });

    group('extractInstagramVideoData', () {
      test('should extract from og:video meta tags', () {
        const html = '''
<html><head>
  <meta property="og:video" content="https://scontent.cdninstagram.com/v/video.mp4?_nc=123" />
  <meta property="og:title" content="Chef John on Instagram" />
  <meta property="og:description" content="Best pasta recipe ever" />
</head><body></body></html>''';

        final result = VideoPageExtractor.extractInstagramVideoData(html);
        expect(result, isNotNull);
        expect(result!.videoUrl,
            equals('https://scontent.cdninstagram.com/v/video.mp4?_nc=123'));
        expect(result.title, equals('Chef John on Instagram'));
        expect(result.description, equals('Best pasta recipe ever'));
      });

      test('should prefer og:video:secure_url over og:video', () {
        const html = '''
<html><head>
  <meta property="og:video" content="http://insecure.example.com/video.mp4" />
  <meta property="og:video:secure_url" content="https://secure.example.com/video.mp4" />
</head><body></body></html>''';

        final result = VideoPageExtractor.extractInstagramVideoData(html);
        expect(result, isNotNull);
        expect(
            result!.videoUrl, equals('https://secure.example.com/video.mp4'));
      });

      test('should extract from JSON-LD', () {
        const html = '''
<html><head>
  <script type="application/ld+json">
  {"@type": "VideoObject", "contentUrl": "https://cdn.example.com/video.mp4", "name": "Cooking Tutorial", "description": "How to make pasta"}
  </script>
</head><body></body></html>''';

        final result = VideoPageExtractor.extractInstagramVideoData(html);
        expect(result, isNotNull);
        expect(result!.videoUrl, equals('https://cdn.example.com/video.mp4'));
        expect(result.title, equals('Cooking Tutorial'));
        expect(result.description, equals('How to make pasta'));
      });

      test('should extract from JSON-LD array format', () {
        const html = '''
<html><head>
  <script type="application/ld+json">
  [{"@type": "VideoObject", "contentUrl": "https://cdn.example.com/video.mp4"}]
  </script>
</head><body></body></html>''';

        final result = VideoPageExtractor.extractInstagramVideoData(html);
        expect(result, isNotNull);
        expect(result!.videoUrl, equals('https://cdn.example.com/video.mp4'));
      });

      test('should extract from embedded JSON with video_url key', () {
        const html = '''
<html><head></head><body>
<script>window.__additionalData = {"video_url":"https:\\/\\/video.cdninstagram.com\\/v\\/video.mp4"};</script>
</body></html>''';

        final result = VideoPageExtractor.extractInstagramVideoData(html);
        expect(result, isNotNull);
        expect(result!.videoUrl, startsWith('https://video.cdninstagram.com/'));
      });

      test('should extract from embedded JSON with playback_url key', () {
        const html = '''
<html><head></head><body>
<script>window.__data = {"playback_url":"https:\\/\\/video.example.com\\/play.mp4"};</script>
</body></html>''';

        final result = VideoPageExtractor.extractInstagramVideoData(html);
        expect(result, isNotNull);
        expect(result!.videoUrl, equals('https://video.example.com/play.mp4'));
      });

      test('should handle escaped URLs with backslash-slash', () {
        const html = '''
<html><head>
  <meta property="og:video" content="https:\\/\\/cdn.example.com\\/v\\/video.mp4?a=1\\u0026b=2" />
</head><body></body></html>''';

        final result = VideoPageExtractor.extractInstagramVideoData(html);
        expect(result, isNotNull);
        expect(result!.videoUrl,
            equals('https://cdn.example.com/v/video.mp4?a=1&b=2'));
      });

      test('should return null for empty HTML', () {
        final result = VideoPageExtractor.extractInstagramVideoData('');
        expect(result, isNull);
      });

      test('should return null when no video found', () {
        const html = '''
<html><head>
  <meta property="og:title" content="Just a photo" />
  <meta property="og:image" content="https://example.com/photo.jpg" />
</head><body></body></html>''';

        final result = VideoPageExtractor.extractInstagramVideoData(html);
        expect(result, isNull);
      });

      test('should handle malformed JSON-LD gracefully', () {
        const html = '''
<html><head>
  <script type="application/ld+json">
  {not valid json}
  </script>
</head><body></body></html>''';

        final result = VideoPageExtractor.extractInstagramVideoData(html);
        expect(result, isNull);
      });
    });

    group('extractTikTokVideoData', () {
      test('should extract from __UNIVERSAL_DATA_FOR_REHYDRATION__', () {
        const html = '''
<html><head></head><body>
<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">
{
  "__DEFAULT_SCOPE__": {
    "webapp.video-detail": {
      "itemInfo": {
        "itemStruct": {
          "desc": "Amazing recipe #cooking",
          "author": {"nickname": "ChefTok"},
          "video": {
            "downloadAddr": "https://v16.tiktokcdn.com/video.mp4",
            "playAddr": "https://v16.tiktokcdn.com/play.mp4"
          }
        }
      }
    }
  }
}
</script>
</body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNotNull);
        expect(result!.videoUrl, equals('https://v16.tiktokcdn.com/video.mp4'));
        expect(result.title, equals('ChefTok - TikTok'));
        expect(result.description, equals('Amazing recipe #cooking'));
      });

      test('should fall back to playAddr when downloadAddr is missing', () {
        const html = '''
<html><head></head><body>
<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">
{
  "__DEFAULT_SCOPE__": {
    "webapp.video-detail": {
      "itemInfo": {
        "itemStruct": {
          "desc": "Test",
          "video": {
            "playAddr": "https://v16.tiktokcdn.com/play.mp4"
          }
        }
      }
    }
  }
}
</script>
</body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNotNull);
        expect(result!.videoUrl, equals('https://v16.tiktokcdn.com/play.mp4'));
      });

      test('should fall back to bitrateInfo when other URLs are missing', () {
        const html = '''
<html><head></head><body>
<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">
{
  "__DEFAULT_SCOPE__": {
    "webapp.video-detail": {
      "itemInfo": {
        "itemStruct": {
          "desc": "Test",
          "video": {
            "bitrateInfo": [
              {"PlayAddr": {"UrlList": ["https://v16.tiktokcdn.com/bitrate.mp4"]}}
            ]
          }
        }
      }
    }
  }
}
</script>
</body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNotNull);
        expect(
            result!.videoUrl, equals('https://v16.tiktokcdn.com/bitrate.mp4'));
      });

      test('should extract from og:video meta tags', () {
        const html = '''
<html><head>
  <meta property="og:video:secure_url" content="https://v16.tiktokcdn.com/og-video.mp4" />
  <meta property="og:title" content="TikTok Recipe Video" />
  <meta property="og:description" content="Quick pasta recipe" />
</head><body></body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNotNull);
        expect(
            result!.videoUrl, equals('https://v16.tiktokcdn.com/og-video.mp4'));
        expect(result.title, equals('TikTok Recipe Video'));
        expect(result.description, equals('Quick pasta recipe'));
      });

      test('should extract from embedded JSON with playAddr', () {
        const html = '''
<html><head></head><body>
<script>window.__data = {"playAddr":"https:\\/\\/v16.tiktokcdn.com\\/embedded.mp4"};</script>
</body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNotNull);
        expect(
            result!.videoUrl, equals('https://v16.tiktokcdn.com/embedded.mp4'));
      });

      test('should extract from embedded JSON with downloadAddr', () {
        const html = '''
<html><head></head><body>
<script>window.__data = {"downloadAddr":"https:\\/\\/v16.tiktokcdn.com\\/download.mp4"};</script>
</body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNotNull);
        expect(
            result!.videoUrl, equals('https://v16.tiktokcdn.com/download.mp4'));
      });

      test('should handle escaped URLs in universal data', () {
        const html = '''
<html><head></head><body>
<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">
{
  "__DEFAULT_SCOPE__": {
    "webapp.video-detail": {
      "itemInfo": {
        "itemStruct": {
          "desc": "Test",
          "video": {
            "downloadAddr": "https:\\/\\/v16.tiktokcdn.com\\/video.mp4?a=1\\u0026b=2"
          }
        }
      }
    }
  }
}
</script>
</body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNotNull);
        // The JSON parser handles the escapes within JSON strings,
        // and _unescapeUrl handles any remaining
        expect(result!.videoUrl, contains('tiktokcdn.com'));
      });

      test('should return null for empty HTML', () {
        final result = VideoPageExtractor.extractTikTokVideoData('');
        expect(result, isNull);
      });

      test('should return null when no video found', () {
        const html = '''
<html><head>
  <meta property="og:title" content="TikTok page" />
</head><body></body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNull);
      });

      test('should handle title without author nickname', () {
        const html = '''
<html><head></head><body>
<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">
{
  "__DEFAULT_SCOPE__": {
    "webapp.video-detail": {
      "itemInfo": {
        "itemStruct": {
          "desc": "A video",
          "video": {
            "downloadAddr": "https://v16.tiktokcdn.com/video.mp4"
          }
        }
      }
    }
  }
}
</script>
</body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNotNull);
        expect(result!.title, isNull);
        expect(result.description, equals('A video'));
      });

      test('should handle malformed universal data JSON gracefully', () {
        const html = '''
<html><head></head><body>
<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">
{not valid json at all}
</script>
</body></html>''';

        final result = VideoPageExtractor.extractTikTokVideoData(html);
        expect(result, isNull);
      });
    });
  });
}
