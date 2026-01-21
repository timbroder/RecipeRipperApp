import 'dart:io';
import 'package:flutter/services.dart';

/// Result of OCR text recognition
class OcrResult {
  final String text;
  final double confidence;

  OcrResult({
    required this.text,
    required this.confidence,
  });

  factory OcrResult.fromMap(Map<dynamic, dynamic> map) {
    return OcrResult(
      text: map['text'] as String? ?? '',
      confidence: map['confidence'] as double? ?? 0.0,
    );
  }
}

/// Result of batch OCR processing
class BatchOcrResult {
  final String imagePath;
  final String text;
  final double confidence;

  BatchOcrResult({
    required this.imagePath,
    required this.text,
    required this.confidence,
  });

  factory BatchOcrResult.fromMap(Map<dynamic, dynamic> map) {
    return BatchOcrResult(
      imagePath: map['imagePath'] as String? ?? '',
      text: map['text'] as String? ?? '',
      confidence: map['confidence'] as double? ?? 0.0,
    );
  }
}

/// Service for optical character recognition (OCR) using platform-specific APIs
class OcrService {
  // Use different channels for iOS and Android
  static MethodChannel? _channel;

  static MethodChannel get channel {
    if (_channel != null) return _channel!;

    // Determine which channel to use based on platform
    if (Platform.isIOS) {
      _channel = const MethodChannel('com.reciperipperapp/vision_ocr');
    } else if (Platform.isAndroid) {
      _channel = const MethodChannel('com.reciperipperapp/mlkit_ocr');
    } else {
      throw UnsupportedError('OCR is only supported on iOS and Android');
    }

    return _channel!;
  }

  /// Check if OCR is available on this device
  Future<bool> isAvailable() async {
    try {
      final result = await channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to check OCR availability: ${e.message}');
    }
  }

  /// Recognize text from a single image
  ///
  /// [imagePath] - Path to the image file (JPEG or PNG)
  /// Returns OCR result with text and confidence score
  Future<OcrResult> recognizeText(String imagePath) async {
    // Validate image file exists
    if (!await File(imagePath).exists()) {
      throw Exception('Image file not found: $imagePath');
    }

    try {
      final result = await channel.invokeMethod<Map<dynamic, dynamic>>(
        'recognizeText',
        {'imagePath': imagePath},
      );

      if (result == null) {
        throw Exception('OCR returned null result');
      }

      return OcrResult.fromMap(result);
    } on PlatformException catch (e) {
      throw Exception('OCR failed: ${e.message}');
    }
  }

  /// Recognize text from multiple images in batch
  ///
  /// [imagePaths] - List of paths to image files
  /// [onProgress] - Optional callback for progress updates (0.0 to 1.0)
  /// Returns list of OCR results
  Future<List<BatchOcrResult>> recognizeTextBatch(
    List<String> imagePaths, {
    void Function(double progress)? onProgress,
  }) async {
    // Validate all image files exist
    for (final path in imagePaths) {
      if (!await File(path).exists()) {
        throw Exception('Image file not found: $path');
      }
    }

    if (imagePaths.isEmpty) {
      return [];
    }

    try {
      final result = await channel.invokeMethod<List<dynamic>>(
        'recognizeTextBatch',
        {'imagePaths': imagePaths},
      );

      if (result == null) {
        throw Exception('Batch OCR returned null result');
      }

      // Report progress as complete since batch processing is done
      onProgress?.call(1.0);

      return result
          .map((item) => BatchOcrResult.fromMap(item as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      throw Exception('Batch OCR failed: ${e.message}');
    }
  }

  /// Process frames and deduplicate similar text
  ///
  /// This is useful for video frames where the same text may appear multiple times
  /// [imagePaths] - List of paths to frame images
  /// [onProgress] - Optional callback for progress updates
  /// Returns deduplicated text from all frames
  Future<String> recognizeAndDeduplicateFrames(
    List<String> imagePaths, {
    void Function(double progress)? onProgress,
  }) async {
    final results = await recognizeTextBatch(
      imagePaths,
      onProgress: onProgress,
    );

    // Deduplicate text using a simple line-based approach
    final seenLines = <String>{};
    final deduplicatedLines = <String>[];

    for (final result in results) {
      if (result.text.isEmpty) continue;

      // Split into lines and deduplicate
      final lines = result.text.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !seenLines.contains(trimmed)) {
          seenLines.add(trimmed);
          deduplicatedLines.add(trimmed);
        }
      }
    }

    return deduplicatedLines.join('\n');
  }

  /// Clean up OCR artifacts and improve text quality
  String cleanOcrText(String text) {
    // Remove excessive whitespace
    var cleaned = text.replaceAll(RegExp(r'\s+'), ' ');

    // Remove common OCR artifacts
    cleaned = cleaned.replaceAll(RegExp(r'[|\\]'), '');

    // Normalize line breaks
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n+'), '\n\n');

    return cleaned.trim();
  }
}
