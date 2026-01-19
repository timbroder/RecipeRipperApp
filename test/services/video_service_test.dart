import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/video_service.dart';

void main() {
  group('VideoService', () {
    late VideoService videoService;

    setUp(() {
      videoService = VideoService();
    });

    tearDown(() {
      videoService.dispose();
    });

    group('URL Validation', () {
      test('should validate correct HTTP URLs', () {
        expect(videoService.isValidUrl('http://example.com/video.mp4'), isTrue);
        expect(videoService.isValidUrl('https://example.com/video.mp4'), isTrue);
      });

      test('should validate YouTube URLs', () {
        expect(videoService.isValidUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
        expect(videoService.isValidUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      });

      test('should reject invalid URLs', () {
        expect(videoService.isValidUrl('not a url'), isFalse);
        expect(videoService.isValidUrl(''), isFalse);
        expect(videoService.isValidUrl('ftp://example.com'), isFalse);
      });

      test('should reject URLs with no scheme', () {
        expect(videoService.isValidUrl('example.com/video.mp4'), isFalse);
        expect(videoService.isValidUrl('www.youtube.com/watch?v=123'), isFalse);
      });
    });

    group('URL Type Detection', () {
      test('should detect YouTube URLs', () {
        expect(
          videoService.detectUrlType('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          equals('youtube'),
        );
        expect(
          videoService.detectUrlType('https://youtu.be/dQw4w9WgXcQ'),
          equals('youtube'),
        );
        expect(
          videoService.detectUrlType('https://m.youtube.com/watch?v=dQw4w9WgXcQ'),
          equals('youtube'),
        );
      });

      test('should detect Vimeo URLs', () {
        expect(
          videoService.detectUrlType('https://vimeo.com/123456789'),
          equals('vimeo'),
        );
      });

      test('should detect Dailymotion URLs', () {
        expect(
          videoService.detectUrlType('https://www.dailymotion.com/video/x123456'),
          equals('dailymotion'),
        );
      });

      test('should detect direct video URLs', () {
        expect(
          videoService.detectUrlType('https://example.com/video.mp4'),
          equals('direct'),
        );
        expect(
          videoService.detectUrlType('https://example.com/video.mov'),
          equals('direct'),
        );
        expect(
          videoService.detectUrlType('https://example.com/video.avi'),
          equals('direct'),
        );
        expect(
          videoService.detectUrlType('https://example.com/video.mkv'),
          equals('direct'),
        );
      });

      test('should detect unknown URLs', () {
        expect(
          videoService.detectUrlType('https://example.com/page'),
          equals('unknown'),
        );
        expect(
          videoService.detectUrlType('https://twitter.com/status/123'),
          equals('unknown'),
        );
      });
    });

    group('VideoSource', () {
      test('should create URL source', () {
        final source = VideoSource.url('https://example.com/video.mp4');
        expect(source.isUrl, isTrue);
        expect(source.isFile, isFalse);
        expect(source.url, equals('https://example.com/video.mp4'));
        expect(source.filePath, isNull);
      });

      test('should create file source', () {
        final source = VideoSource.file('/path/to/video.mp4');
        expect(source.isFile, isTrue);
        expect(source.isUrl, isFalse);
        expect(source.filePath, equals('/path/to/video.mp4'));
        expect(source.url, isNull);
      });
    });

    group('VideoMetadata', () {
      test('should serialize to JSON', () {
        final metadata = VideoMetadata(
          title: 'Test Video',
          duration: const Duration(minutes: 5, seconds: 30),
          thumbnailPath: '/path/to/thumbnail.jpg',
          sourceUrl: 'https://example.com/video.mp4',
          localPath: '/path/to/video.mp4',
          fileSizeBytes: 1024 * 1024 * 10, // 10 MB
          resolution: '1920x1080',
        );

        final json = metadata.toJson();

        expect(json['title'], equals('Test Video'));
        expect(json['duration_seconds'], equals(330));
        expect(json['thumbnail_path'], equals('/path/to/thumbnail.jpg'));
        expect(json['source_url'], equals('https://example.com/video.mp4'));
        expect(json['local_path'], equals('/path/to/video.mp4'));
        expect(json['file_size_bytes'], equals(1024 * 1024 * 10));
        expect(json['resolution'], equals('1920x1080'));
      });

      test('should deserialize from JSON', () {
        final json = {
          'title': 'Test Video',
          'duration_seconds': 330,
          'thumbnail_path': '/path/to/thumbnail.jpg',
          'source_url': 'https://example.com/video.mp4',
          'local_path': '/path/to/video.mp4',
          'file_size_bytes': 1024 * 1024 * 10,
          'resolution': '1920x1080',
        };

        final metadata = VideoMetadata.fromJson(json);

        expect(metadata.title, equals('Test Video'));
        expect(metadata.duration, equals(const Duration(minutes: 5, seconds: 30)));
        expect(metadata.thumbnailPath, equals('/path/to/thumbnail.jpg'));
        expect(metadata.sourceUrl, equals('https://example.com/video.mp4'));
        expect(metadata.localPath, equals('/path/to/video.mp4'));
        expect(metadata.fileSizeBytes, equals(1024 * 1024 * 10));
        expect(metadata.resolution, equals('1920x1080'));
      });

      test('should handle null values in JSON', () {
        final json = {
          'title': 'Test Video',
          'duration_seconds': 120,
          'thumbnail_path': null,
          'source_url': null,
          'local_path': '/path/to/video.mp4',
          'file_size_bytes': null,
          'resolution': null,
        };

        final metadata = VideoMetadata.fromJson(json);

        expect(metadata.title, equals('Test Video'));
        expect(metadata.duration, equals(const Duration(minutes: 2)));
        expect(metadata.thumbnailPath, isNull);
        expect(metadata.sourceUrl, isNull);
        expect(metadata.localPath, equals('/path/to/video.mp4'));
        expect(metadata.fileSizeBytes, isNull);
        expect(metadata.resolution, isNull);
      });
    });

    group('VideoException', () {
      test('should format exception message with code', () {
        final exception = VideoException('Test error', code: 'TEST_CODE');
        expect(
          exception.toString(),
          equals('VideoException: Test error (TEST_CODE)'),
        );
      });

      test('should format exception message without code', () {
        final exception = VideoException('Test error');
        expect(exception.toString(), equals('VideoException: Test error'));
      });
    });
  });
}
