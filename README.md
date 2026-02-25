# Recipe Ripper Mobile

> Extract structured recipes from cooking videos using on-device ML

[![CI](https://github.com/timbroder/RecipeRipperApp/workflows/CI/badge.svg)](https://github.com/timbroder/RecipeRipperApp/actions)

## Overview

Recipe Ripper Mobile is a Flutter application that converts cooking videos into structured, editable recipes. Using on-device speech recognition and OCR, it extracts ingredients and cooking directions without sending any data to external servers.

**Original Project**: [RecipeRipper](https://github.com/timbroder/RecipeRipper) (Python CLI)

## Features

### Current (Sprint 0 - MVP Foundation)
- ✅ Local SQLite database for recipe storage
- ✅ Recipe viewing with ingredients and directions
- ✅ Recipe editing capabilities
- ✅ Clean, Material 3 UI with dark mode support

### Coming Soon
- **Sprint 1**: Video URL sharing & local video picker
- **Sprint 2**: On-device speech transcription & OCR
- **Sprint 3**: Intelligent recipe parsing
- **Sprint 4**: Enhanced UI/UX
- **Sprint 5**: Cloud sync & export (JSON/Markdown)
- **Sprint 6**: Polish, testing, and App Store launch

## Tech Stack

- **Framework**: Flutter 3.16+ (Dart 3.0+)
- **Platforms**: iOS 14+ and Android 8.0+
- **Database**: SQLite (sqflite)
- **Speech Recognition**:
  - iOS: Native Speech framework
  - Android: Speech Recognition API
- **OCR**:
  - iOS: Vision framework
  - Android: ML Kit Text Recognition
- **Video Processing**: FFmpeg Kit Flutter

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.16 or higher
- Xcode 15+ (for iOS development)
- Android Studio with SDK 26+ (for Android development)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/timbroder/RecipeRipperApp.git
cd RecipeRipperApp
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

### Development

```bash
# Format code
dart format .

# Analyze code
flutter analyze

# Run tests
flutter test

# Run tests with coverage
flutter test --coverage

# Build for release
flutter build ios --release
flutter build apk --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── recipe.dart
│   ├── ingredient.dart
│   ├── direction.dart
│   └── processing_job.dart
├── services/                 # Business logic
│   ├── database_service.dart
│   ├── video_service.dart    # Coming in Sprint 1
│   ├── speech_service.dart   # Coming in Sprint 2
│   └── ocr_service.dart      # Coming in Sprint 2
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── recipe_detail_screen.dart
│   ├── recipe_edit_screen.dart
│   └── settings_screen.dart
└── widgets/                  # Reusable components

ios/                          # iOS native code
android/                      # Android native code
test/                         # Unit and widget tests
```

## Architecture

Recipe Ripper uses a simple Provider-based state management architecture:

- **Models**: Pure Dart classes with JSON serialization
- **Services**: Business logic and data access (database, ML processing)
- **Screens**: UI layouts and user interactions
- **Widgets**: Reusable UI components

Database schema:
- `recipes` - Core recipe information
- `ingredients` - Recipe ingredients with quantities
- `directions` - Numbered cooking steps
- `recipe_metadata` - Processing info (transcript, OCR text)
- `processing_jobs` - Background job tracking

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Quick Start for Contributors

1. Check the [PROJECT_PLAN.md](PROJECT_PLAN.md) for current sprint and tasks
2. Pick an issue or create one for discussion
3. Fork the repository
4. Create a feature branch (`git checkout -b feature/amazing-feature`)
5. Make your changes following our style guide
6. Write tests for your changes
7. Run `flutter analyze` and `flutter test`
8. Commit with clear messages (`git commit -m 'Add amazing feature'`)
9. Push to your fork (`git push origin feature/amazing-feature`)
10. Open a Pull Request

## Testing

```bash
# Unit tests
flutter test

# Widget tests
flutter test test/widgets

# Integration tests
flutter test integration_test/

# Coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Recipe Extraction Test Harness

A Mac-based harness for testing the LLM recipe extraction pipeline (prompt building, response parsing, and post-processing) without needing an iOS device or Apple Foundation Models.

```bash
flutter test test/harness/recipe_extraction_harness_test.dart
```

**What it tests:**
- Prompt construction (system instructions + user prompt)
- JSON response parsing (LLM output → structured data)
- Post-processing (ingredient parsing, cross-reference checking, deduplication)

**What it does NOT test:**
- Video downloading
- Audio extraction or speech-to-text transcription
- OCR / frame extraction
- Apple Foundation Models inference

These steps require a real device. The harness picks up where transcription leaves off.

#### Workflow

1. **Get a transcript.** Either:
   - Run the app on an iOS device and copy the transcript from logs
   - Use any transcription tool on the video's audio
   - Manually transcribe the video yourself

2. **Add your test data** to the harness file — set the transcript text, video title, and (optionally) a golden reference ingredient list.

3. **Run the harness** — it prints the exact prompt that would be sent to Foundation Models:
   ```
   flutter test test/harness/recipe_extraction_harness_test.dart --name "show prompt"
   ```

4. **Paste that prompt into any LLM** (Claude, ChatGPT, Gemini, etc.) and copy the JSON response.

5. **Paste the LLM's JSON into the harness** (the `llmOutput` variable in the "JSON response parsing" test) and re-run to see the final recipe after all post-processing.

#### Built-in test data

The harness ships with sample data for [Cheesy Cream of Broccoli Pasta](https://youtube.com/shorts/K6wEWWhJf7Q) including:
- Transcript text
- Golden reference ingredients ([source](https://gist.github.com/timbroder/1fa88e090ea2830fd3d1c41eeaef8c67))
- Two simulated LLM responses:
  - **Good response** — captures all ingredients with quantities
  - **Poor response** — drops quantities and misses beans (simulates Foundation Models quality)

The "poor response" test verifies that the cross-reference checker recovers missing ingredients from the transcript.

## Roadmap

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for detailed sprint breakdown (Sprints 0-6, ~14-15 weeks to MVP).

Current status: **Sprint 0 Complete** ✅

## Privacy

Recipe Ripper processes all video data **on-device**. No video content, audio, or recipe data is sent to external servers (except optional cloud sync in Sprint 5, which uses your personal iCloud/Google Drive).

## Acknowledgments

- Original Python CLI: [RecipeRipper](https://github.com/timbroder/RecipeRipper)
- Inspired by the need for a mobile-first recipe extraction tool
- Built with ❤️ using Flutter

## Support

- 📖 [Documentation](CLAUDE.md)
- 🐛 [Report a Bug](https://github.com/timbroder/RecipeRipperApp/issues)
- 💡 [Request a Feature](https://github.com/timbroder/RecipeRipperApp/issues)
- 💬 [Discussions](https://github.com/timbroder/RecipeRipperApp/discussions)

---

**Current Version**: 0.1.0 (Sprint 0 - Foundation Complete)
**Last Updated**: 2026-01-16