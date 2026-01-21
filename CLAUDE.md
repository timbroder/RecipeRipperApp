# CLAUDE_APP.md - RecipeRipper Mobile

This file provides context for AI assistants working on the mobile app version of this project.

## Project Overview

RecipeRipper Mobile is a Flutter application that extracts structured recipes from cooking videos. It's a mobile conversion of the original Python CLI tool, designed to run entirely on-device using native iOS and Android ML capabilities.

**Original Project**: https://github.com/timbroder/RecipeRipper (Python CLI)
**Mobile Project**: https://github.com/timbroder/RecipeRipperApp (Flutter)

## Core Functionality

- Accept video URLs via share sheet or pick local videos from camera roll
- Download and preview videos before processing
- Extract audio and transcribe using on-device speech recognition
- Extract on-screen text using OCR from video frames
- Parse transcription + OCR text into structured recipes (ingredients + directions)
- Store recipes locally with optional cloud sync
- Allow full editing of extracted recipes
- Export recipes as JSON/Markdown
- Process in background with notifications
- Delete videos after processing to save space

## Tech Stack

### Framework & Languages
- **Flutter 3.x+** (Dart 3.x+)
- **iOS**: Swift for native Speech + Vision frameworks
- **Android**: Kotlin for native Speech Recognition + ML Kit

### Key Dependencies
- `sqflite` - Local SQLite database
- `image_picker` / `file_picker` - Video selection
- `ffmpeg_kit_flutter` - Video/audio processing
- `video_player` - Video playback and thumbnail generation
- `shared_preferences` - App settings
- `path_provider` - File system access

### Native Integrations
- **iOS**: Speech framework (transcription), Vision framework (OCR)
- **Android**: SpeechRecognizer API, ML Kit Text Recognition
- **iOS**: Background Tasks framework, CloudKit/iCloud Drive
- **Android**: WorkManager, Google Drive API

## Architecture

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models (Recipe, Ingredient, Direction)
├── services/                 # Business logic
│   ├── video_service.dart    # Download, extract frames
│   ├── speech_service.dart   # Platform channel for transcription
│   ├── ocr_service.dart      # Platform channel for OCR
│   ├── parsing_service.dart  # Recipe parsing heuristics
│   ├── database_service.dart # SQLite operations
│   └── sync_service.dart     # Cloud sync
├── screens/                  # UI screens
│   ├── home_screen.dart      # Recipe grid
│   ├── detail_screen.dart    # Recipe view
│   └── edit_screen.dart      # Recipe editing
├── widgets/                  # Reusable components
└── utils/                    # Helpers and constants

ios/
├── Runner/
│   ├── AppDelegate.swift
│   ├── SpeechBridge.swift   # Native speech transcription
│   └── VisionBridge.swift   # Native OCR

android/
├── app/src/main/kotlin/
│   ├── MainActivity.kt
│   ├── SpeechBridge.kt      # Native speech transcription
│   └── OcrBridge.kt         # Native OCR
```

## Development Workflow

### Setup
```bash
flutter pub get
flutter run
```

### Testing
```bash
flutter test                    # Unit tests
flutter test integration_test/  # Integration tests
```

### Building
```bash
flutter build ios
flutter build apk
flutter build appbundle
```

## Key Design Decisions

### Why On-Device ML?
- No API costs
- Works offline
- Privacy (no data leaves device)
- Faster (no network latency)

### Why Delete Videos After Processing?
- Mobile storage is limited
- Users need recipes, not videos
- Can always re-download from source
- Reduces app footprint

### Why Flutter?
- Single codebase for iOS + Android
- Native performance for video/ML workloads
- Excellent plugin ecosystem
- Fast development with hot reload

## Parsing Heuristics (Ported from Python)

### Ingredient Detection
- Has quantities/units (1 cup, 2 tbsp, etc.)
- Contains common ingredient keywords (flour, sugar, salt, etc.)
- Shorter text (ingredients are concise)
- Often bullet-pointed or listed

### Direction Detection
- Imperative verbs (bake, mix, pour, stir, etc.)
- Contains temperatures (350°F, 180°C)
- Contains times (10 minutes, 2 hours)
- Numbered steps
- Longer, sentence-form text

### Normalization
- Convert unit abbreviations (tbsp→tablespoon, tsp→teaspoon)
- Handle fractions (1/2, ¼, ½)
- Deduplicate similar ingredients
- Clean up OCR artifacts

## Testing Strategy

### Unit Tests (>90% coverage target)
- All parsing functions
- Unit conversions
- Ingredient/direction classification
- Text normalization

### Widget Tests
- All screens render correctly
- User interactions work
- State management updates UI

### Integration Tests
- Share URL → Process → View recipe (end-to-end)
- Pick local video → Edit recipe → Export
- Background processing with notifications

### Manual Testing Checklist
See PROJECT_PLAN.md for comprehensive test plan

## Common Commands

```bash
# Run on specific device
flutter run -d <device-id>

# Run tests with coverage
flutter test --coverage

# Build release
flutter build ios --release
flutter build appbundle --release

# Clean build
flutter clean && flutter pub get

# Format code
dart format .

# Analyze code
flutter analyze
```

## Platform-Specific Notes

### iOS
- Requires iOS 14+ for Speech framework offline support
- Add privacy descriptions in Info.plist:
  - `NSSpeechRecognitionUsageDescription`
  - `NSMicrophoneUsageDescription` (even though we don't use mic live)
  - `NSPhotoLibraryUsageDescription`
- Enable Background Modes capability (Audio, Processing)
- Enable iCloud capability for sync

### Android
- Min SDK 26 (Android 8.0) for Speech Recognition
- Add permissions in AndroidManifest.xml:
  - `RECORD_AUDIO`
  - `READ_EXTERNAL_STORAGE`
  - `INTERNET` (for URL downloads)
- Configure WorkManager for background tasks
- Set up Google Drive API credentials for sync

## Known Limitations

- YouTube downloading may violate TOS (focus on local videos)
- Processing long videos (>30 min) may drain battery
- OCR accuracy depends on video quality and text clarity
- Transcription accuracy depends on audio quality and accents
- Background processing may be killed by OS under extreme memory pressure
- **FFmpeg Kit Retired (January 2026)**: The original `ffmpeg_kit_flutter` package was retired and CDN binaries removed. We migrated to `ffmpeg_kit_flutter_new`, a community-maintained fork with working binaries.

## Troubleshooting

### "No devices found"
```bash
flutter devices
# For iOS: open Xcode, Window → Devices and Simulators
# For Android: adb devices
```

### Platform channel not found
- Make sure native code is properly registered in AppDelegate/MainActivity
- Rebuild app completely: `flutter clean && flutter run`

### Speech/OCR not working
- Check permissions are granted
- Verify native code is calling correct APIs
- Check device language settings
- Ensure models are downloaded (iOS Vision, Android ML Kit)

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [iOS Speech Framework](https://developer.apple.com/documentation/speech)
- [iOS Vision Framework](https://developer.apple.com/documentation/vision)
- [Android Speech Recognition](https://developer.android.com/reference/android/speech/SpeechRecognizer)
- [ML Kit Text Recognition](https://developers.google.com/ml-kit/vision/text-recognition)
- [Original Python Project](https://github.com/timbroder/RecipeRipper)

## Sprint Plan

See PROJECT_PLAN.md for detailed sprint breakdown (Sprints 0-6, ~14-15 weeks to MVP)

**IMPORTANT**: When a sprint or phase is completed, you MUST update PROJECT_PLAN.md to reflect:
- Mark completed tasks with `[x]`
- Add a "What Was Built" section summarizing deliverables
- Update the status and version at the bottom of the file
- Note any deferred items or changes from the original plan

## CI/CD Notes

### When CI Fails
**IMPORTANT**: When tests or CI checks are failing, ALWAYS connect to the GitHub PR to get the actual error message. Use:
```bash
gh pr view <PR_NUMBER> --json statusCheckRollup
gh run view <RUN_ID> --log-failed
```
Do NOT guess at what might be wrong. Get the actual error first.

### Dart Formatting
- CI runs `dart format --output=none --set-exit-if-changed .`
- Different Dart/Flutter versions may format code differently
- The CI workflow uses `channel: 'stable'` without pinning a specific version
- Always run `dart format lib/ test/` locally before committing
- If format check fails in CI but passes locally, ensure you're using the same Flutter version

### Flutter Analyze
- CI runs `flutter analyze` which fails on ANY issue (including info-level)
- The `analysis_options.yaml` is kept minimal to avoid conflicts:
  - Extends `package:flutter_lints/flutter.yaml`
  - Ignores `deprecated_member_use` (Flutter API deprecations are common)
  - Disables `prefer_const_constructors` (causes false positives)
- Always run `flutter analyze` locally before pushing
- If analyze fails, check analysis_options.yaml isn't too strict

### Lessons Learned (Sprint 0)
1. Don't create overly strict analysis_options.yaml - it causes more problems than it solves
2. Dart formatter behavior varies between versions - don't pin old Flutter versions in CI
3. Run both `dart format` AND `flutter analyze` locally before pushing
4. When troubleshooting CI, always get the actual logs first

### Lessons Learned (Sprint 1)
1. **Dart syntax rules**: `typedef` declarations cannot be inside classes - must be at top level
2. **Widget constructors**: Always put `child` argument last in widget constructors
3. **Use `super.key`**: In constructors, prefer `super.key` over `Key? key` parameter syntax
4. **No `print()` in production**: Use `debugPrint()` instead of `print()` for debug output
5. **Check for unused code**: Remove unused fields and variables before committing
6. **Null safety**: Don't do unnecessary null checks - check if collections are empty first

### Lessons Learned (Sprint 2)
1. **Verify existing APIs before using**: Always READ existing model/class files to check actual property names (e.g., `localPath` vs `videoPath`)
2. **Match constructor signatures**: When navigating to a screen, verify its constructor parameters first (e.g., `RecipeDetailScreen` expects `recipe`, not `recipeId`)
3. **Remove unused state variables**: If a variable like `_processing` is set but never read, remove it
4. **Test code must compile**: Don't write test code calling methods that don't exist (e.g., `getClass()` is Java, not Dart)
5. **Clean imports**: Remove unused imports (e.g., `dart:io` if not used)
6. **No print in services**: In service classes, either use proper logging or remove debug output entirely

### Pre-Commit Checklist
Before committing ANY code changes, run these commands:
```bash
# 1. Format all Dart code
dart format lib/ test/

# 2. Run static analysis (must pass with 0 issues)
flutter analyze

# 3. Run tests
flutter test
```

**CRITICAL**: Do NOT commit if `flutter analyze` shows ANY errors. Warnings and info-level issues will also fail CI.

## Contributing

When working on this project:
1. Read the sprint plan to understand current phase
2. Follow Flutter style guide
3. Write tests for new features
4. Update this document if architecture changes
5. Test on both iOS and Android before committing
6. Keep native code minimal (prefer Dart when possible)
7. Run `dart format .` and `flutter analyze` before committing

## Questions?

Check the original Python implementation for parsing logic reference:
- `recipe_extractor.py` - Core parsing heuristics
- `tests/test_recipe_extractor.py` - Test cases showing expected behavior

---

**Last Updated**: 2026-01-19
**Current Phase**: Sprint 2 Complete - Ready for Sprint 3

## Sprint 1 Completion Summary

Sprint 1 focused on video input and preview functionality. All core features have been implemented:

### Features Implemented
1. **Video Input Methods**:
   - Share sheet integration (iOS and Android)
   - URL input dialog for direct entry
   - Local video file picker from camera roll

2. **Video Sources Supported**:
   - YouTube videos (via youtube_explode_dart)
   - Direct video URLs (via dio HTTP downloads)
   - Local video files (.mp4, .mov, .avi, .mkv, .m4v, .webm)

3. **Video Preview**:
   - Thumbnail generation from first frame
   - Metadata extraction (title, duration, resolution, file size)
   - Estimated processing time display
   - Download progress tracking
   - Error handling with retry functionality

4. **Platform Integration**:
   - iOS: URL schemes and Universal Links via AppDelegate
   - Android: Intent filters for ACTION_SEND (text/video)
   - Platform channels for native → Flutter communication

### Files Added/Modified
- `lib/services/video_service.dart` - Core video handling service
- `lib/services/share_handler_service.dart` - Platform channel for shared URLs
- `lib/screens/video_preview_screen.dart` - Video preview UI
- `lib/screens/home_screen.dart` - Updated with video input options
- `ios/Runner/AppDelegate.swift` - iOS share integration
- `ios/Runner/Info.plist` - URL schemes and permissions
- `android/app/src/main/kotlin/com/reciperipperapp/MainActivity.kt` - Android share integration
- `test/services/video_service_test.dart` - Comprehensive unit tests
- `pubspec.yaml` - Added video handling dependencies

### Next Steps
Sprint 3 will focus on recipe parsing and storage logic.

## Sprint 2 Completion Summary

Sprint 2 focused on implementing the on-device ML processing pipeline for extracting audio transcription and on-screen text from videos.

### Features Implemented

1. **Audio Extraction & Transcription**:
   - FFmpeg Kit integration for audio extraction from video files
   - WAV format extraction optimized for speech recognition (16kHz, mono)
   - iOS Speech framework bridge for on-device transcription
   - Android SpeechRecognizer API bridge
   - Multi-language support (13+ languages including EN, ES, FR, DE, IT, PT, JA, KO, ZH)
   - Real-time progress tracking

2. **Video Frame Extraction & OCR**:
   - FFmpeg-based frame extraction at configurable FPS (default: 1 frame per 0.6 seconds)
   - Max frame limit (180 frames) to prevent memory issues
   - iOS Vision framework bridge for OCR
   - Android ML Kit Text Recognition bridge
   - Batch processing for multiple frames
   - Text deduplication for video frames
   - OCR artifact cleaning

3. **Processing Pipeline**:
   - ProcessingService orchestrator coordinating all steps
   - Real-time progress tracking (0-100%)
   - Error handling and recovery
   - Automatic cleanup of temporary files
   - Platform detection (YouTube, Vimeo, Dailymotion, etc.)

4. **Notifications**:
   - Local notifications for processing status
   - Progress updates during processing
   - Completion and failure notifications
   - Platform-specific notification handling

5. **Background Processing (Android & iOS)**:
   - Android: WorkManager integration for background task scheduling
   - iOS: BGTaskScheduler integration for background processing
   - BackgroundProcessingService for unified Dart/native bridge
   - ProcessingNotificationHelper (Android) for foreground notifications
   - BackgroundTaskBridge (iOS) for BGTaskScheduler
   - Automatic transition to background when app is paused
   - Job status polling when app returns to foreground
   - "Continue in Background" button in ProcessingScreen

6. **UI Components**:
   - ProcessingScreen with real-time progress display
   - Circular progress indicator with percentage
   - Status icons for different processing stages
   - Background processing button and status indicator (Android)
   - Automatic navigation to recipe detail upon completion
   - Updated VideoPreviewScreen to launch processing

### Files Added/Modified

**Dart Services:**
- `lib/services/audio_extraction_service.dart` - FFmpeg audio extraction
- `lib/services/frame_extraction_service.dart` - FFmpeg frame extraction
- `lib/services/speech_transcription_service.dart` - Speech recognition platform channel
- `lib/services/ocr_service.dart` - OCR platform channel
- `lib/services/processing_service.dart` - Main processing orchestrator
- `lib/services/notification_service.dart` - Local notifications
- `lib/services/background_processing_service.dart` - WorkManager integration for background processing

**Native iOS Bridges:**
- `ios/Runner/SpeechRecognitionBridge.swift` - Speech framework integration
- `ios/Runner/VisionOcrBridge.swift` - Vision framework OCR
- `ios/Runner/BackgroundTaskBridge.swift` - BGTaskScheduler for background processing
- `ios/Runner/AppDelegate.swift` - Updated to register bridges and background tasks
- `ios/Runner/Info.plist` - Added background modes and task identifiers

**Native Android Bridges:**
- `android/app/src/main/kotlin/com/reciperipperapp/SpeechRecognitionBridge.kt` - SpeechRecognizer API
- `android/app/src/main/kotlin/com/reciperipperapp/MlKitOcrBridge.kt` - ML Kit Text Recognition
- `android/app/src/main/kotlin/com/reciperipperapp/ProcessingNotificationHelper.kt` - WorkManager foreground notifications
- `android/app/src/main/kotlin/com/reciperipperapp/MainActivity.kt` - Updated to register bridges and WorkManager channel
- `android/app/build.gradle` - Added ML Kit and WorkManager dependencies
- `android/app/src/main/AndroidManifest.xml` - Added background processing permissions

**UI Screens:**
- `lib/screens/processing_screen.dart` - Real-time processing progress
- `lib/screens/video_preview_screen.dart` - Updated to launch processing

**Tests:**
- `test/services/processing_service_test.dart` - Processing service unit tests

**Configuration:**
- `pubspec.yaml` - Added ffmpeg_kit_flutter, flutter_local_notifications, and workmanager
- `lib/main.dart` - Updated to initialize background processing on Android and iOS

### Deferred Items

- None - all Sprint 2 features are complete

### Technical Notes

- All processing is done on-device using native APIs (no cloud dependencies)
- Speech recognition uses offline models on both iOS and Android
- OCR uses Vision framework (iOS) and ML Kit (Android) for high accuracy
- Processing typically takes 20-40% of video duration
- Temporary files are automatically cleaned up after processing
- Recipe metadata (transcript + OCR text) is stored in the database for Sprint 3 parsing
- Background processing uses platform-native APIs:
  - Android: WorkManager with foreground service for reliable execution
  - iOS: BGTaskScheduler with processing task for background execution
- When the app is backgrounded, processing automatically switches to background mode
- Job status is polled when the app returns to foreground to update UI
