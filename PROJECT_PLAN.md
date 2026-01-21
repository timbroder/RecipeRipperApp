# RecipeRipper Mobile - Project Plan

## Project Overview

Convert RecipeRipper from a Python CLI tool to a fully self-contained Flutter mobile app that extracts recipes from cooking videos using on-device ML processing.

---

## Technical Stack

- **Framework**: Flutter (Dart)
- **Platforms**: iOS 14+ and Android 8+
- **Speech Recognition**: 
  - iOS: Native Speech framework
  - Android: Speech Recognition API + ML Kit
- **OCR**: 
  - iOS: Vision framework
  - Android: ML Kit Text Recognition
- **Local Storage**: SQLite (sqflite package)
- **Cloud Storage**: 
  - iOS: CloudKit / iCloud Drive
  - Android: Google Drive API
- **Video Processing**: 
  - FFmpeg Kit Flutter
  - video_player package
- **Background Processing**: 
  - iOS: Background Tasks framework
  - Android: WorkManager

---

## Core Features

### Phase 1: MVP
1. Share sheet integration (receive video URLs)
2. Local video file picker
3. Video download with preview
4. On-device speech transcription
5. On-device OCR from video frames
6. Recipe parsing (ingredients + directions)
7. Local storage
8. Basic recipe viewing UI (card grid)
9. Recipe editing

### Phase 2: Enhanced
10. Background processing with notifications
11. Cloud sync (iCloud/Google Drive)
12. Export to JSON/Markdown
13. Search and filtering
14. Error handling and retry logic
15. Settings/preferences

---

## Sprint Breakdown

### Sprint 0: Project Setup & Foundation ✅ COMPLETE
**Duration**: 1 week
**Goal**: Set up development environment and project structure

#### Tasks
- [x] Install Flutter SDK and configure development environment
- [x] Create Flutter project with proper package structure
- [x] Set up iOS and Android native projects (scaffolded, builds commented out in CI until fully configured)
- [x] Configure CI/CD pipeline (GitHub Actions)
- [x] Set up linting and formatting rules
- [x] Create data models (Recipe, Ingredient, Direction, ProcessingJob)
- [x] Set up local database schema (SQLite)
- [x] Create basic app navigation structure (home, detail, edit, settings)
- [ ] Design app icon and splash screen (deferred - using placeholder)

#### Deliverables
- ✅ Runnable Flutter app skeleton
- ✅ Database schema defined (SQLite with full CRUD)
- ✅ CI/CD pipeline working (analyze, lint, test jobs)
- ✅ Project documentation (README, CONTRIBUTING, CLAUDE.md)

#### What Was Built
- **Data Models**: `Recipe`, `Ingredient`, `Direction`, `ProcessingJob` with full serialization
- **Database**: SQLite schema with recipes, ingredients, directions tables
- **Screens**: HomeScreen (recipe grid), RecipeDetailScreen, RecipeEditScreen, SettingsScreen
- **Services**: DatabaseService with full CRUD operations
- **Tests**: Unit tests for all data models
- **CI/CD**: GitHub Actions workflow with format checking, linting, and tests

#### Dependencies
- None

---

### Sprint 1: Video Input & Preview ✅ COMPLETE
**Duration**: 2 weeks
**Goal**: Users can share URLs or pick local videos and see previews

#### User Stories
- As a user, I can share a YouTube URL from Safari/Chrome to the app
- As a user, I can share URLs from other video platforms
- As a user, I can pick a video from my camera roll
- As a user, I can see a preview (thumbnail + metadata) before processing
- As a user, I can cancel if I selected the wrong video

#### Technical Tasks

**Share Sheet Integration**
- [x] Implement iOS Share Extension target
- [x] Implement Android Intent Filter for share actions
- [x] Handle URL schemes (http, https, youtube, etc.)
- [x] Parse received URLs and validate format
- [x] Create platform channel for native → Flutter communication

**Video Picker**
- [x] Integrate `file_picker` package
- [x] Handle camera roll permissions (iOS Privacy, Android Storage)
- [x] Support .mp4, .mov, .avi, .mkv formats
- [x] Copy video to app sandbox for processing

**Video Download**
- [x] Research yt-dlp alternatives for mobile
  - ✅ Chosen: youtube_explode_dart (pure Dart, YouTube only)
  - ✅ Also: dio for direct video URL downloads
- [x] Implement download progress tracking
- [x] Generate video thumbnail from first frame
- [x] Extract video metadata (title, duration, resolution)

**Preview UI**
- [x] Create preview screen with thumbnail, title, duration
- [x] Add "Process Recipe" and "Cancel" buttons
- [x] Show estimated processing time
- [x] Handle network errors for URL downloads

#### Deliverables
- ✅ Share sheet working on iOS and Android
- ✅ Video picker working
- ✅ Video downloads with progress bar
- ✅ Preview screen with metadata

#### What Was Built
- **VideoService**: Comprehensive service for video input and processing
  - URL validation and type detection (YouTube, Vimeo, Dailymotion, direct links)
  - YouTube video downloading via `youtube_explode_dart`
  - Direct video URL downloading via `dio`
  - Local video file picker integration
  - Video metadata extraction (title, duration, resolution, file size)
  - Thumbnail generation from video frames
  - Progress tracking callbacks
  - Error handling with custom VideoException
- **VideoPreviewScreen**: Full-featured preview UI
  - Video thumbnail display
  - Metadata cards (duration, resolution, file size, source)
  - Estimated processing time
  - "Process Recipe" and "Cancel" actions
  - Download progress indicator
  - Error handling with retry functionality
- **Share Integration**:
  - iOS: AppDelegate with URL scheme and Universal Links support
  - Android: MainActivity with Intent Filter for text/video sharing
  - ShareHandlerService: Platform channel for native → Flutter communication
- **HomeScreen Updates**:
  - "Add Recipe" FAB with modal bottom sheet
  - "Enter Video URL" option with dialog
  - "Choose Local Video" option with file picker
  - Integrated share handler for incoming URLs
- **Unit Tests**: Comprehensive tests for VideoService
  - URL validation tests
  - URL type detection tests
  - VideoSource model tests
  - VideoMetadata serialization tests
  - VideoException tests

#### Dependencies
- Sprint 0 complete

#### Acceptance Criteria
- [x] Can share YouTube URL from Safari → app opens with preview
- [x] Can pick local video from Photos app
- [x] Preview shows accurate thumbnail and metadata
- [x] Download errors display user-friendly messages
- [x] Supports YouTube and direct video URLs (5+ platforms to be added later)

---

### Sprint 2: On-Device ML Processing Pipeline ✅ COMPLETE
**Duration**: 3 weeks
**Goal**: Extract audio transcription and on-screen text from videos

#### User Stories
- As a user, I can process a video entirely on my device (no internet after download)
- As a user, I see real-time progress during processing
- As a user, I receive a notification when processing completes
- As a user, processing continues even if I close the app

#### Technical Tasks

**Audio Extraction & Transcription**
- [x] Integrate FFmpeg Kit Flutter for audio extraction
- [x] Extract audio track from video as .wav or .m4a
- [x] Create iOS platform channel for Speech framework
  - [x] Write Swift code for SFSpeechRecognizer
  - [x] Handle offline speech recognition
  - [x] Support multiple languages (EN, ES, FR, etc.)
- [x] Create Android platform channel for Speech Recognition
  - [x] Write Kotlin code for SpeechRecognizer
  - [x] Handle ML Kit Speech-to-Text API
- [x] Implement progress callbacks (0-50% for transcription)
- [x] Handle transcription errors and retries

**Video Frame Extraction & OCR**
- [x] Extract frames at configurable FPS (default 0.6 seconds)
- [x] Limit max frames (default 180) to prevent memory issues
- [x] Create iOS platform channel for Vision framework
  - [x] Write Swift code for VNRecognizeTextRequest
  - [x] Process frames in batches to manage memory
- [x] Create Android platform channel for ML Kit
  - [x] Write Kotlin code for TextRecognition
- [x] Deduplicate extracted text (same text on multiple frames)
- [x] Implement progress callbacks (50-100% for OCR)

**Background Processing**
- [x] Create notification channel for progress updates
- [x] Send notifications on completion/failure
- [x] Handle app state transitions (foreground ↔ background)
- [x] Implement iOS Background Tasks
  - [x] Register background task identifier in Info.plist
  - [x] Create BackgroundTaskBridge for BGTaskScheduler
  - [x] Handle task expiration and cleanup
  - [x] Process video in background when app is backgrounded
  - [x] Show notification during background processing
- [x] Implement Android WorkManager
  - [x] Create Worker class for processing
  - [x] Create BackgroundProcessingService for Dart integration
  - [x] Handle constraints (battery, network, storage)
  - [x] Process video in background when app is backgrounded
  - [x] Show notification during background processing

**Data Pipeline**
- [x] Create ProcessingService to orchestrate steps
- [x] Implement job queue (multiple videos can be queued)
- [x] Store intermediate results (transcript, OCR text) in DB
- [x] Handle processing cancellation
- [x] Cleanup temporary files after processing

#### Deliverables
- ✅ Speech-to-text working on iOS and Android
- ✅ OCR working on iOS and Android
- ✅ Foreground processing with notifications
- ✅ Processing progress UI
- ✅ Job queue system

#### Dependencies
- Sprint 1 complete

#### Acceptance Criteria
- [x] 10-minute video processes in 2-5 minutes on modern device
- [x] Transcription accuracy >85% for clear English audio
- [x] OCR captures on-screen text with >80% accuracy
- [x] Notification appears when processing completes
- [x] Battery usage is reasonable (<20% for 10-min video)
- [x] Works completely offline after video download
- [x] Processing continues when app is backgrounded (Android via WorkManager; iOS via BGTaskScheduler)

#### What Was Built

**Services Implemented:**
- **AudioExtractionService**: FFmpeg-based audio extraction from video files
  - Extracts audio as WAV format (16kHz, mono) optimized for speech recognition
  - Configurable audio quality and format
  - Duration calculation and cleanup utilities
- **FrameExtractionService**: FFmpeg-based frame extraction from videos
  - Configurable FPS (default: 1 frame per 0.6 seconds)
  - Max frame limit (default: 180 frames) to prevent memory issues
  - Single frame extraction for thumbnails
  - Automatic cleanup of extracted frames
- **SpeechTranscriptionService**: Platform channel for on-device speech recognition
  - iOS: Speech framework integration
  - Android: SpeechRecognizer API integration
  - Multi-language support (13+ languages)
  - Progress tracking and error handling
- **OcrService**: Platform channel for on-device OCR
  - iOS: Vision framework integration
  - Android: ML Kit Text Recognition
  - Batch processing for multiple frames
  - Text deduplication for video frames
  - OCR artifact cleaning
- **ProcessingService**: Main orchestrator for video processing pipeline
  - Coordinates audio extraction, transcription, frame extraction, and OCR
  - Progress tracking with real-time updates
  - Error handling and recovery
  - Automatic cleanup of temporary files
  - Platform detection (YouTube, Vimeo, etc.)
- **NotificationService**: Local notifications for processing status
  - Processing started, progress updates, completion, and failure notifications
  - Platform-specific notification handling (iOS/Android)
  - Custom notification channels
- **BackgroundProcessingService**: Background processing for both platforms
  - Android: WorkManager integration via platform channels
  - iOS: BGTaskScheduler integration via platform channels
  - Schedule background processing jobs
  - Job status tracking (enqueued, running, succeeded, failed)
  - Cancel individual or all background jobs
  - Automatic transition to background when app is paused

**Native Platform Bridges:**
- **iOS (Swift)**:
  - `SpeechRecognitionBridge.swift`: Speech framework integration
  - `VisionOcrBridge.swift`: Vision framework for OCR
  - `BackgroundTaskBridge.swift`: BGTaskScheduler for background processing
  - Updated `AppDelegate.swift` to register bridges and background tasks
  - Updated `Info.plist` with background modes and task identifiers
- **Android (Kotlin)**:
  - `SpeechRecognitionBridge.kt`: SpeechRecognizer API integration
  - `MlKitOcrBridge.kt`: ML Kit Text Recognition
  - `ProcessingNotificationHelper.kt`: Helper for WorkManager foreground notifications
  - Updated `MainActivity.kt` to register bridges and WorkManager method channel
  - Updated `build.gradle` to include ML Kit and WorkManager dependencies
  - Updated `AndroidManifest.xml` with background processing permissions

**UI Components:**
- **ProcessingScreen**: Real-time processing progress display
  - Circular progress indicator with percentage
  - Current step description
  - Status icons for different processing stages
  - Informational messages about background processing
  - "Continue in Background" button (Android only)
  - Automatic transition to background processing when app is paused
  - Polling for job status updates when returning from background
  - Automatic navigation to recipe detail upon completion

**Database Updates:**
- Recipe metadata table already supports transcript and OCR text storage
- Processing job tracking with status, progress, and error handling

**Tests:**
- Unit tests for ProcessingJob model
- Unit tests for RecipeMetadata serialization
- Processing job state machine tests

**Deferred Items:**
- None - all Sprint 2 features are complete

---

### Sprint 3: Recipe Parsing & Storage
**Duration**: 2 weeks  
**Goal**: Convert raw transcription + OCR text into structured recipes

#### User Stories
- As a user, I see ingredients and directions clearly separated
- As a user, I see quantities and units properly formatted
- As a user, I can view the source text that was parsed
- As a user, recipes are saved automatically after processing

#### Technical Tasks

**Port Python Parsing Logic to Dart**
- [ ] Port `split_into_sections()` - separate ingredients from directions
- [ ] Port `parse_ingredient()` - extract quantity, unit, item, notes
- [ ] Port `classify_as_ingredient()` - detect ingredient patterns
- [ ] Port `classify_as_direction()` - detect direction patterns
- [ ] Port `normalize_units()` - convert abbreviations (tbsp, tsp, cup, etc.)
- [ ] Port `deduplicate_ingredients()` - merge duplicates
- [ ] Port `deduplicate_directions()` - remove redundant steps
- [ ] Port regex patterns and heuristics

**Data Models**
- [ ] Create `Recipe` model (title, url, source, created_at, updated_at)
- [ ] Create `Ingredient` model (quantity, unit, item, notes, order)
- [ ] Create `Direction` model (step_number, text)
- [ ] Create `ProcessingMetadata` model (transcript, ocr_text, processing_time)
- [ ] Implement JSON serialization/deserialization
- [ ] Add validation logic (Pydantic → Dart validation)

**Database Layer**
- [ ] Create SQLite tables (recipes, ingredients, directions)
- [ ] Implement CRUD operations for recipes
- [ ] Create database migrations system
- [ ] Add indexes for search performance
- [ ] Implement cascade delete (recipe → ingredients/directions)

**Recipe Service**
- [ ] Create RecipeService to orchestrate parsing
- [ ] Merge transcript + OCR text + video metadata
- [ ] Apply parsing heuristics
- [ ] Apply cleanup/normalization (optional toggle)
- [ ] Save to database
- [ ] Generate thumbnail from video frame

#### Deliverables
- Parsing logic fully ported to Dart
- Recipe data models and database schema
- RecipeService working end-to-end
- Unit tests for parsing functions (>90% coverage)

#### Dependencies
- Sprint 2 complete

#### Acceptance Criteria
- [ ] Parsing accuracy matches Python version (compare outputs)
- [ ] Ingredients show quantity, unit, item correctly
- [ ] Directions are numbered and clear
- [ ] Recipe saves to database successfully
- [ ] Parsing handles edge cases (no ingredients, very long videos, etc.)
- [ ] Unit tests achieve >90% coverage on parsing logic

---

### Sprint 4: Recipe Viewing & Editing UI
**Duration**: 2 weeks  
**Goal**: Beautiful, intuitive UI for browsing and editing recipes

#### User Stories
- As a user, I see all my recipes in a visual card grid
- As a user, I can tap a recipe to view full details
- As a user, I can edit recipe title, ingredients, and directions
- As a user, I can delete recipes I don't want
- As a user, I see which recipes are currently processing

#### Technical Tasks

**Home Screen - Recipe Grid**
- [ ] Create card widget with thumbnail, title, source
- [ ] Implement grid layout (2 columns on phone, 3+ on tablet)
- [ ] Add pull-to-refresh
- [ ] Show empty state when no recipes
- [ ] Show processing jobs with progress indicators
- [ ] Add floating action button for "Add Recipe"
- [ ] Implement smooth animations and transitions

**Recipe Detail Screen**
- [ ] Create beautiful recipe display layout
  - [ ] Header with thumbnail and title
  - [ ] Ingredients section with checkboxes (for cooking mode)
  - [ ] Directions section with numbered steps
  - [ ] Metadata footer (source, date, processing time)
- [ ] Add "Edit" and "Delete" buttons
- [ ] Add "Share" button (export recipe)
- [ ] Implement swipe gestures (back navigation)

**Recipe Edit Screen**
- [ ] Create form for editing recipe title
- [ ] Create editable list for ingredients
  - [ ] Add/remove ingredient rows
  - [ ] Inline editing for quantity, unit, item
  - [ ] Reorder ingredients (drag handles)
- [ ] Create editable list for directions
  - [ ] Add/remove direction steps
  - [ ] Inline editing for step text
  - [ ] Auto-renumber steps
- [ ] Add "Save" and "Cancel" buttons
- [ ] Show unsaved changes warning

**Shared Widgets**
- [ ] Create reusable ingredient card widget
- [ ] Create reusable direction card widget
- [ ] Create loading skeleton screens
- [ ] Create error state widgets
- [ ] Implement consistent theming (colors, fonts, spacing)

**State Management**
- [ ] Choose state management solution (Provider, Riverpod, or Bloc)
- [ ] Implement RecipeProvider / RecipeBloc
- [ ] Handle loading, success, error states
- [ ] Implement optimistic updates for editing

#### Deliverables
- Polished home screen with recipe grid
- Recipe detail screen with all info
- Recipe edit screen with full functionality
- Smooth animations and transitions
- Consistent design system

#### Dependencies
- Sprint 3 complete

#### Acceptance Criteria
- [ ] UI matches modern mobile design standards
- [ ] Smooth 60fps scrolling on recipe grid
- [ ] Editing is intuitive (no accidental deletions)
- [ ] Works well on various screen sizes (small phones to tablets)
- [ ] Dark mode support (optional but recommended)
- [ ] Accessibility features (VoiceOver/TalkBack support)

---

### Sprint 5: Cloud Sync & Export
**Duration**: 2 weeks  
**Goal**: Recipes sync across devices and can be exported

#### User Stories
- As a user, my recipes sync across my iPhone and iPad
- As a user, my recipes sync across my Android devices
- As a user, I can export recipes as JSON or Markdown
- As a user, I can share recipes with friends
- As a user, I don't lose recipes if I delete the app

#### Technical Tasks

**Cloud Sync - iOS**
- [ ] Set up iCloud entitlements in Xcode
- [ ] Choose sync method:
  - Option A: CloudKit (structured data, more complex)
  - Option B: iCloud Drive (file-based, simpler)
- [ ] Implement sync logic (upload new/modified recipes)
- [ ] Implement conflict resolution (last-write-wins or manual)
- [ ] Handle iCloud account changes
- [ ] Add sync status indicator in UI

**Cloud Sync - Android**
- [ ] Set up Google Drive API credentials
- [ ] Implement OAuth authentication flow
- [ ] Create Drive folder for app data
- [ ] Implement sync logic (upload/download recipes)
- [ ] Implement conflict resolution
- [ ] Handle account changes
- [ ] Add sync status indicator in UI

**Export Functionality**
- [ ] Implement JSON export (structured data)
- [ ] Implement Markdown export (human-readable)
- [ ] Add "Export Recipe" button to detail screen
- [ ] Integrate with iOS Share Sheet
- [ ] Integrate with Android Share Intent
- [ ] Support "Export All" from settings

**Import Functionality** (Bonus)
- [ ] Support importing JSON files
- [ ] Support importing Markdown files (best-effort parsing)
- [ ] Validate imported data
- [ ] Merge with existing recipes (avoid duplicates)

**Settings Screen**
- [ ] Create settings UI
- [ ] Add cloud sync toggle (enable/disable)
- [ ] Add account management (sign in/out)
- [ ] Add sync status and last sync time
- [ ] Add "Export All Recipes" button
- [ ] Add storage usage indicator
- [ ] Add app version and credits

#### Deliverables
- iCloud sync working on iOS
- Google Drive sync working on Android
- JSON/Markdown export working
- Settings screen with sync controls
- Import functionality (optional)

#### Dependencies
- Sprint 4 complete

#### Acceptance Criteria
- [ ] Recipe created on iPhone appears on iPad within 30 seconds
- [ ] Recipe created on Android phone appears on tablet
- [ ] Exported JSON can be re-imported without data loss
- [ ] Exported Markdown is readable in standard editors
- [ ] Sync works reliably with conflicts
- [ ] User can disable sync if desired
- [ ] No data loss during sync failures

---

### Sprint 6: Polish, Testing & Launch Prep
**Duration**: 2-3 weeks  
**Goal**: Production-ready app with excellent UX and stability

#### User Stories
- As a user, the app never crashes
- As a user, error messages are clear and actionable
- As a user, the app feels fast and responsive
- As a user, I can get help if something goes wrong

#### Technical Tasks

**Error Handling & Resilience**
- [ ] Add try-catch blocks around all risky operations
- [ ] Implement error logging (Sentry, Firebase Crashlytics)
- [ ] Create user-friendly error messages
- [ ] Add retry logic for network operations
- [ ] Handle edge cases:
  - [ ] Video URL is invalid
  - [ ] Video download fails midway
  - [ ] Speech/OCR models unavailable
  - [ ] Disk space full
  - [ ] Permissions denied
  - [ ] Background task killed by OS

**Performance Optimization**
- [ ] Profile app with Flutter DevTools
- [ ] Optimize image loading (thumbnails)
- [ ] Implement pagination for recipe grid (lazy loading)
- [ ] Reduce app size (remove unused assets)
- [ ] Optimize database queries (add indexes)
- [ ] Reduce memory usage during video processing
- [ ] Test on low-end devices (iPhone 8, budget Android)

**Comprehensive Testing**
- [ ] Write unit tests for all parsing functions (>90% coverage)
- [ ] Write widget tests for all screens
- [ ] Write integration tests for critical flows
  - [ ] Share URL → Process → View recipe
  - [ ] Pick local video → Process → Edit recipe
  - [ ] Export recipe → Re-import
- [ ] Manual testing on real devices (iOS and Android)
- [ ] Test edge cases and error scenarios
- [ ] Test different video formats and lengths
- [ ] Test on various screen sizes and OS versions

**Onboarding & Help**
- [ ] Create first-launch tutorial (show how to share videos)
- [ ] Add empty state with instructions
- [ ] Create FAQ / Help screen
- [ ] Add tooltips for complex features
- [ ] Create demo video showing app usage

**Accessibility**
- [ ] Test with VoiceOver (iOS) and TalkBack (Android)
- [ ] Ensure all interactive elements have labels
- [ ] Verify color contrast ratios (WCAG AA)
- [ ] Support dynamic text sizes
- [ ] Test with Switch Control / Switch Access

**App Store Prep**
- [ ] Create App Store screenshots (5.5", 6.5" iPhone + iPad)
- [ ] Create Google Play screenshots (phone + tablet)
- [ ] Write compelling app description
- [ ] Create privacy policy (especially for speech/OCR data)
- [ ] Set up App Store Connect / Google Play Console
- [ ] Configure in-app purchase (if applicable)
- [ ] Submit for review

**Documentation**
- [ ] Update README with app info and screenshots
- [ ] Create CHANGELOG
- [ ] Document architecture decisions
- [ ] Create contributor guide
- [ ] Add inline code documentation

#### Deliverables
- Production-ready app binary
- App Store and Google Play listings
- Test coverage >80%
- Documentation complete
- Launch plan

#### Dependencies
- Sprints 0-5 complete

#### Acceptance Criteria
- [ ] Zero crashes in 100 test runs
- [ ] App launches in <2 seconds on average device
- [ ] Processing time <5 min for 10-min video
- [ ] App size <100MB (iOS and Android)
- [ ] Test coverage >80%
- [ ] Passes Apple App Review guidelines
- [ ] Passes Google Play policies
- [ ] All accessibility checks pass
- [ ] 5 beta testers report no critical issues

---

## Post-Launch: Future Enhancements

### Phase 3: Nice-to-Have Features
- [ ] Recipe search with filters (by source, date, ingredients)
- [ ] Recipe collections/folders
- [ ] Favorites/bookmarks
- [ ] Shopping list generation from ingredients
- [ ] Cooking mode (hands-free with voice control)
- [ ] Unit conversion (metric ↔ imperial)
- [ ] Scaling recipes (2x, 3x, 0.5x servings)
- [ ] Notes and ratings per recipe
- [ ] Recipe sharing with other app users
- [ ] Widget for quick access to recent recipes
- [ ] Apple Watch companion app
- [ ] Support for more languages
- [ ] Integration with grocery delivery apps
- [ ] Nutritional information extraction (if in video)
- [ ] Whisper.cpp integration for better transcription

---

## Risk Management

### Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| YouTube TOS violation | High | Focus on local videos; YouTube as secondary feature |
| App Store rejection | High | Review guidelines early; have fallback for YouTube |
| Battery drain during processing | Medium | Optimize algorithms; recommend charging during processing |
| Large app size (>200MB) | Medium | Make models optional downloads; use system APIs |
| Parsing accuracy too low | High | Extensive testing; allow manual editing; improve heuristics |
| Cloud sync conflicts | Medium | Implement robust conflict resolution; test thoroughly |
| Background processing unreliable | Medium | Fallback to foreground; clear user communication |

### User Experience Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Processing takes too long | High | Show accurate progress; allow cancellation |
| Confusing UI | Medium | User testing; clear onboarding |
| Recipes have errors | High | Easy editing; show source text for debugging |
| Lost recipes (no backup) | High | Implement cloud sync; export reminders |

---

## Success Metrics

### MVP Success Criteria
- [ ] App successfully processes 80% of test videos
- [ ] Ingredient parsing accuracy >75%
- [ ] Direction parsing accuracy >70%
- [ ] Processing time <5 min for 10-min video
- [ ] Zero crashes in 50 test runs
- [ ] 10 beta testers successfully extract recipes

### Launch Success Criteria
- [ ] App Store approval on first submission
- [ ] <5% crash rate in first month
- [ ] 100+ downloads in first week
- [ ] Average rating >4.0 stars
- [ ] <10% negative reviews about core functionality

### Long-term Success Criteria
- [ ] 1000+ active users
- [ ] 10,000+ recipes processed
- [ ] Average session time >5 minutes
- [ ] 30-day retention >40%
- [ ] Word-of-mouth growth (organic downloads)

---

## Timeline Summary

| Sprint | Duration | Goal |
|--------|----------|------|
| Sprint 0 | 1 week | Project setup |
| Sprint 1 | 2 weeks | Video input & preview |
| Sprint 2 | 3 weeks | ML processing pipeline |
| Sprint 3 | 2 weeks | Recipe parsing & storage |
| Sprint 4 | 2 weeks | Recipe UI |
| Sprint 5 | 2 weeks | Cloud sync & export |
| Sprint 6 | 2-3 weeks | Polish & launch prep |
| **Total** | **14-15 weeks** | **MVP to launch** |

---

## Development Resources

### Required Skills
- **Flutter/Dart** - Primary app development
- **iOS (Swift)** - Native Speech/Vision integration
- **Android (Kotlin)** - Native Speech/ML Kit integration
- **UI/UX Design** - App interface and user flows
- **Testing** - Unit, widget, integration tests
- **DevOps** - CI/CD, app store deployment

### Team Recommendation
- 1 Flutter Developer (full-time)
- 1 iOS Developer (part-time, Sprints 2-3)
- 1 Android Developer (part-time, Sprints 2-3)
- 1 UI/UX Designer (part-time, Sprint 4)
- 1 QA Engineer (part-time, Sprint 6)

*Alternatively: 1 full-stack mobile developer can handle all roles if experienced*

---

## Appendix: Technical Decisions

### Why Flutter over React Native?
- Better performance for CPU-intensive video/ML processing
- Excellent ML Kit and Vision framework integration
- Smaller app size with ahead-of-time compilation
- Strong community support for video/media apps
- Hot reload for faster development

### Why On-Device ML over Cloud APIs?
- No recurring API costs
- Works fully offline
- Better privacy (no data leaves device)
- Faster (no network latency)
- No rate limits

### Why SQLite over NoSQL?
- Strong relational structure (recipes → ingredients/directions)
- ACID compliance for data integrity
- Excellent Flutter support (sqflite package)
- Lightweight and fast for mobile
- Easy migration from Python version

### Why Delete Videos After Processing?
- Mobile storage is precious
- Most users only need the recipe, not the video
- Reduces app storage footprint
- Users can always re-download from original source
- Simplifies data management

---

## Notes

- This plan assumes a single developer working full-time
- Sprint durations are estimates; adjust based on actual velocity
- Prioritize iOS or Android first, then port to second platform
- Consider soft-launching on TestFlight/Internal Testing first
- Budget 20% time buffer for unexpected issues
- Update this plan as requirements evolve

---

**Version**: 1.3
**Last Updated**: 2026-01-19
**Status**: Sprint 2 Complete - Ready for Sprint 3
