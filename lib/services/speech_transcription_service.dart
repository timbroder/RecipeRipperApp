import 'dart:io';
import 'package:flutter/services.dart';

/// Result of speech transcription
class TranscriptionResult {
  final String text;
  final double confidence;

  TranscriptionResult({
    required this.text,
    required this.confidence,
  });

  factory TranscriptionResult.fromMap(Map<dynamic, dynamic> map) {
    return TranscriptionResult(
      text: map['text'] as String? ?? '',
      confidence: map['confidence'] as double? ?? 0.0,
    );
  }
}

/// Service for transcribing audio using platform-specific speech recognition
class SpeechTranscriptionService {
  static const _channel = MethodChannel('com.reciperipperapp/speech_recognition');

  /// Request permission for speech recognition
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception(
        'Failed to request speech recognition permission: ${e.message}',
      );
    }
  }

  /// Check if speech recognition is available on this device
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception(
        'Failed to check speech recognition availability: ${e.message}',
      );
    }
  }

  /// Transcribe an audio file to text
  ///
  /// [audioPath] - Path to the audio file (WAV format recommended)
  /// [language] - Language code (default: en-US)
  /// [onProgress] - Optional callback for progress updates (0.0 to 1.0)
  /// Returns transcription result with text and confidence score
  Future<TranscriptionResult> transcribeAudio(
    String audioPath, {
    String language = 'en-US',
    void Function(double progress)? onProgress,
  }) async {
    // Validate audio file exists
    if (!await File(audioPath).exists()) {
      throw Exception('Audio file not found: $audioPath');
    }

    try {
      // Call platform-specific transcription
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'transcribeAudio',
        {
          'audioPath': audioPath,
          'language': language,
        },
      );

      if (result == null) {
        throw Exception('Transcription returned null result');
      }

      return TranscriptionResult.fromMap(result);
    } on PlatformException catch (e) {
      throw Exception('Speech recognition failed: ${e.message}');
    }
  }

  /// Transcribe audio with automatic language detection
  /// Currently supports English, but can be extended
  Future<TranscriptionResult> transcribeAudioWithLanguageDetection(
    String audioPath, {
    void Function(double progress)? onProgress,
  }) async {
    // For MVP, we'll just use English
    // In future, we can try multiple languages and pick the best result
    return transcribeAudio(
      audioPath,
      language: 'en-US',
      onProgress: onProgress,
    );
  }

  /// Get supported languages for transcription
  /// Note: This is a simplified list. Actual support depends on the device.
  List<String> getSupportedLanguages() {
    return [
      'en-US', // English (US)
      'en-GB', // English (UK)
      'es-ES', // Spanish
      'es-MX', // Spanish (Mexico)
      'fr-FR', // French
      'de-DE', // German
      'it-IT', // Italian
      'pt-BR', // Portuguese (Brazil)
      'pt-PT', // Portuguese (Portugal)
      'ja-JP', // Japanese
      'ko-KR', // Korean
      'zh-CN', // Chinese (Simplified)
      'zh-TW', // Chinese (Traditional)
    ];
  }
}
