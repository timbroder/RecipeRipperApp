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

### Pipeline Harness

Runs the app's real URL → recipe pipeline on a URL, with no UI, so you can iterate on extraction without tapping through the app. It runs on an iOS simulator or a plugged-in iPhone, so every stage is the code the app ships:

1. Download the video and read its title and description (`VideoService.prepareFromUrl`)
2. Description fast path: Foundation Models on the description alone
3. FFmpeg audio extraction → Speech transcription, and frame extraction → Vision OCR
4. Foundation Models extraction from description + transcript + OCR, then post-processing

```bash
# First booted iOS simulator:
tool/harness.sh https://www.youtube.com/shorts/-xQJKP3mne8

# A specific simulator or a plugged-in iPhone (ids from `flutter devices`):
tool/harness.sh <url> <device-id>

# Re-print a saved run (the latest if no path is given):
dart run tool/harness_report.dart harness_runs/<video-id>/<timestamp>.json
```

The report shows each stage in order with timings: the metadata, whether the description fast path fired and what the model returned, the transcript, the OCR text, the exact prompt and raw Foundation Models response, what post-processing added, and the final recipe. Each run is saved as JSON under `harness_runs/<video-id>/` (gitignored).

**Comparing with the desktop version:** save a [RecipeRipper](https://github.com/timbroder/RecipeRipper) CLI run (its Markdown output) as `integration_test/references/<video-id>.md`. The report then lists which reference ingredients the app found, missed or added.

**How it works:** `integration_test/pipeline_harness_test.dart` calls the same functions as the video preview and processing screens, in the same order, and contains no recipe logic of its own. The pipeline records what each stage saw into a `PipelineTrace` (`lib/services/pipeline_trace.dart`), which does nothing in the app because only the harness installs one. `test_driver/integration_test.dart` receives the trace on the Mac, prints it and saves it.

**Simulator limits:**
- The simulator has no on-device speech model, and the app requires on-device recognition, so transcription fails there with "Failed to initialize recognizer". Run on an iPhone to test the transcript path.
- Foundation Models works in the simulator, but the first request after install can fail with a `SensitiveContentAnalysisML` error; the next run works.
- A run that reaches transcription stops at the speech recognition permission prompt until you tap Allow. On the simulator the prompt can come back after a rebuild (and transcription then fails anyway); on an iPhone you allow it once.

### Post-processing tests with canned LLM responses

`test/harness/recipe_extraction_harness_test.dart` runs on the Mac with no device. It feeds fixed LLM responses through the app's prompt building, response parsing and post-processing, which is handy for working on post-processing in isolation:

```bash
flutter test test/harness/recipe_extraction_harness_test.dart
```

It ships with sample data for [Cheesy Cream of Broccoli Pasta](https://youtube.com/shorts/K6wEWWhJf7Q): a transcript, [golden ingredients](https://gist.github.com/timbroder/1fa88e090ea2830fd3d1c41eeaef8c67), and two simulated LLM responses (a good one, and a poor one that drops quantities and misses the beans, to check the cross-reference checker recovers them). To try another model, run "show prompt", paste the prompt into any LLM, paste its JSON into `llmOutput` in "JSON response parsing", and re-run.

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