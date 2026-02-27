/// Recipe extraction test harness.
///
/// Run on Mac to test the full prompt-building and post-processing pipeline
/// without needing an iOS device or Apple Foundation Models.
///
/// Usage:
///   # All tests (including YouTube fetch, requires network):
///   flutter test test/harness/recipe_extraction_harness_test.dart
///
///   # Offline tests only (no network):
///   flutter test --exclude-tags network test/harness/recipe_extraction_harness_test.dart
///
/// Workflow (canned data):
///   1. Add your test data (transcript, title, etc.) to a test case
///   2. Run the test — it prints the EXACT prompt sent to the LLM
///   3. Paste that prompt into any LLM (Claude, ChatGPT, etc.)
///   4. Copy the LLM's JSON response into the `llmJsonResponse` variable
///   5. Re-run — it shows the final recipe after all post-processing
///
/// Workflow (YouTube URL):
///   1. Set `youtubeUrl` in the YouTube URL Pipeline group
///   2. Run — the harness fetches title, description, and captions
///   3. It prints the exact prompt to paste into any LLM
///   4. Paste the LLM's JSON into `llmResponse` and re-run
///
/// The harness tests three layers:
///   - Prompt building (what the LLM sees)
///   - LLM response parsing (JSON → LlmExtractionResult)
///   - Post-processing (ingredient parsing, cross-reference, dedup)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_ripper/services/llm/llm_prompts.dart';
import 'package:recipe_ripper/services/llm/llm_service.dart';
import 'package:recipe_ripper/services/llm_recipe_extraction_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// ─────────────────────────────────────────────────────────────
// Mock LLM that returns a canned JSON response
// ─────────────────────────────────────────────────────────────

class HarnessLlmService extends LlmService {
  final String jsonResponse;
  String? capturedInstructions;
  String? capturedPrompt;

  HarnessLlmService(this.jsonResponse);

  @override
  String get name => 'Harness Mock';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<LlmExtractionResult> extractRecipe(
    String text, {
    String? videoTitle,
  }) async {
    capturedInstructions = LlmPrompts.fullExtractionInstructions();
    capturedPrompt =
        LlmPrompts.fullExtractionUserPrompt(text, videoTitle: videoTitle);

    final json = LlmPrompts.parseResponse(jsonResponse);
    if (json == null) return LlmExtractionResult.failed('Parse error');
    return LlmExtractionResult.fromJson(json);
  }

  @override
  Future<LlmExtractionResult> extractRecipeFromDescription(
    String description, {
    String? videoTitle,
  }) async {
    capturedInstructions = LlmPrompts.descriptionOnlyInstructions();
    capturedPrompt = LlmPrompts.descriptionOnlyUserPrompt(
      description,
      videoTitle: videoTitle,
    );

    final json = LlmPrompts.parseResponse(jsonResponse);
    if (json == null) return LlmExtractionResult.failed('Parse error');
    return LlmExtractionResult.fromJson(json);
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

void printRecipe(dynamic recipe) {
  // ignore: avoid_print
  print('\n${'=' * 60}');
  // ignore: avoid_print
  print('FINAL RECIPE');
  // ignore: avoid_print
  print('=' * 60);
  // ignore: avoid_print
  print('Title: ${recipe.title}');
  // ignore: avoid_print
  print('Source: ${recipe.sourceUrl ?? "n/a"}');
  // ignore: avoid_print
  print('\nIngredients (${recipe.ingredients.length}):');
  for (final ing in recipe.ingredients) {
    final qty = ing.quantity != null ? '${ing.quantity}' : '';
    final unit = ing.unit ?? '';
    final prefix = '$qty $unit'.trim();
    // ignore: avoid_print
    print('  - ${prefix.isNotEmpty ? "$prefix " : ""}${ing.item}'
        '${ing.notes != null ? " (${ing.notes})" : ""}');
  }
  // ignore: avoid_print
  print('\nDirections (${recipe.directions.length}):');
  for (final dir in recipe.directions) {
    // ignore: avoid_print
    print('  ${dir.stepNumber}. ${dir.text}');
  }
  // ignore: avoid_print
  print('\nMetadata warnings:');
  for (final w in recipe.metadata?.warnings ?? []) {
    // ignore: avoid_print
    print('  ! $w');
  }
  // ignore: avoid_print
  print('=' * 60);
}

void printPrompt(HarnessLlmService llm) {
  // ignore: avoid_print
  print('\n${'─' * 60}');
  // ignore: avoid_print
  print('SYSTEM INSTRUCTIONS:');
  // ignore: avoid_print
  print('─' * 60);
  // ignore: avoid_print
  print(llm.capturedInstructions);
  // ignore: avoid_print
  print('\n${'─' * 60}');
  // ignore: avoid_print
  print('USER PROMPT:');
  // ignore: avoid_print
  print('─' * 60);
  // ignore: avoid_print
  print(llm.capturedPrompt);
  // ignore: avoid_print
  print('─' * 60);
}

// ─────────────────────────────────────────────────────────────
// YouTube data fetching (for network-tagged tests)
// ─────────────────────────────────────────────────────────────

/// Data fetched from a YouTube video for testing.
class YouTubeVideoData {
  final String title;
  final String description;
  final Duration duration;
  final String? captionText;
  final String captionSource;

  YouTubeVideoData({
    required this.title,
    required this.description,
    required this.duration,
    this.captionText,
    required this.captionSource,
  });
}

/// Fetches YouTube video metadata and captions using youtube_explode_dart.
class YouTubeHelper {
  /// Normalize YouTube URLs (Shorts, live, embed) to standard watch?v= format.
  /// Duplicated from VideoService since that class has Flutter-native deps
  /// that can't be imported in pure Dart tests.
  static String normalizeUrl(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;

    // Handle youtube.com/shorts/VIDEO_ID
    if (pathSegments.length >= 2 && pathSegments[0] == 'shorts') {
      return 'https://www.youtube.com/watch?v=${pathSegments[1]}';
    }

    // Handle youtube.com/live/VIDEO_ID
    if (pathSegments.length >= 2 && pathSegments[0] == 'live') {
      return 'https://www.youtube.com/watch?v=${pathSegments[1]}';
    }

    // Handle youtube.com/embed/VIDEO_ID
    if (pathSegments.length >= 2 && pathSegments[0] == 'embed') {
      return 'https://www.youtube.com/watch?v=${pathSegments[1]}';
    }

    return url;
  }

  /// Fetch video metadata and closed captions from YouTube.
  static Future<YouTubeVideoData> fetch(String url) async {
    final normalizedUrl = normalizeUrl(url);
    final yt = YoutubeExplode();
    try {
      // Fetch video metadata
      final video = await yt.videos.get(normalizedUrl);

      // Fetch closed captions
      String? captionText;
      var captionSource = 'none';

      try {
        final manifest = await yt.videos.closedCaptions.getManifest(video.id);

        // Pick best English track: manual > auto-generated
        ClosedCaptionTrackInfo? bestTrack;

        final manualEn = manifest.getByLanguage('en');
        if (manualEn.isNotEmpty) {
          bestTrack = manualEn.first;
          captionSource = 'manual (en)';
        }

        if (bestTrack == null) {
          final autoEn = manifest.getByLanguage('en', autoGenerated: true);
          if (autoEn.isNotEmpty) {
            bestTrack = autoEn.first;
            captionSource = 'auto-generated (en)';
          }
        }

        // Fall back to any track if no English found
        if (bestTrack == null && manifest.tracks.isNotEmpty) {
          bestTrack = manifest.tracks.first;
          captionSource =
              '${bestTrack.isAutoGenerated ? "auto-generated" : "manual"}'
              ' (${bestTrack.language.code})';
        }

        if (bestTrack != null) {
          final track = await yt.videos.closedCaptions.get(bestTrack);
          captionText = track.captions.map((c) => c.text).join(' ');
        }
      } catch (e) {
        captionSource = 'error: $e';
      }

      return YouTubeVideoData(
        title: video.title,
        description: video.description,
        duration: video.duration ?? Duration.zero,
        captionText: captionText,
        captionSource: captionSource,
      );
    } finally {
      yt.close();
    }
  }
}

/// Build combined text in the same format as
/// LlmRecipeExtractionService._buildTruncatedInput().
String buildCombinedText({
  String? description,
  String? transcript,
}) {
  final sections = <String>[];
  if (description != null && description.isNotEmpty) {
    sections.add('DESCRIPTION:\n$description');
  }
  if (transcript != null && transcript.isNotEmpty) {
    sections.add('TRANSCRIPT:\n$transcript');
  }
  return sections.join('\n\n');
}

// ─────────────────────────────────────────────────────────────
// Test data: Cheesy Cream of Broccoli Pasta
// ─────────────────────────────────────────────────────────────
// Video: https://youtube.com/shorts/K6wEWWhJf7Q
// Golden recipe: https://gist.github.com/timbroder/1fa88e090ea2830fd3d1c41eeaef8c67

const broccoliPastaTitle = 'I Hope to Age This Gracefully';

// Approximate transcript from the video (speech-to-text)
const broccoliPastaTranscript =
    "One of the things I make that helps me feel and look as good as I do at "
    "54 is my cheesy cream of broccoli pasta. I start by sauteing an onion in "
    "a little bit of oil. Then I take a can of cream northern beans, I drain "
    "them and I add half a cup of cashews, a cup of broth, a quarter cup of "
    "nutritional yeast, and the juice of one lemon. I blend that up until it's "
    "super smooth. Then I take a head of broccoli and I steam it until it's "
    "tender. I cook up some edamame pasta because it's higher in protein. Then "
    "I mix everything together and it is so creamy and delicious. Salt and "
    "pepper to taste.";

// Golden reference ingredients for comparison
const broccoliPastaGolden = [
  '1 onion, sautéed',
  '1 can cream northern beans, drained',
  '0.5 cup cashews',
  '1 cup broth',
  '0.25 cup nutritional yeast',
  'Juice of 1 lemon',
  '1 head broccoli',
  'Pasta of choice',
  'Oil',
];

// ─────────────────────────────────────────────────────────────
// Simulated LLM responses — swap these to test different outputs
// ─────────────────────────────────────────────────────────────

/// A "good" LLM response that captures most ingredients with quantities.
const goodLlmResponse = '''
{
  "title": "Cheesy Cream of Broccoli Pasta",
  "ingredients": [
    "1 onion",
    "1 can cream northern beans, drained",
    "0.5 cup cashews",
    "1 cup broth",
    "0.25 cup nutritional yeast",
    "juice of 1 lemon",
    "1 head broccoli",
    "edamame pasta",
    "oil",
    "salt and pepper to taste"
  ],
  "directions": [
    "Sauté onion in oil until softened",
    "Blend drained beans, cashews, broth, nutritional yeast, and lemon juice until smooth",
    "Steam broccoli until tender",
    "Cook edamame pasta according to package directions",
    "Mix blended sauce with pasta and broccoli",
    "Season with salt and pepper to taste"
  ]
}
''';

/// A "poor" LLM response that drops quantities and misses beans.
/// This is closer to what Foundation Models has been producing.
const poorLlmResponse = '''
{
  "title": "Cheesy Cream of Broccoli Pasta",
  "ingredients": [
    "head of broccoli",
    "onion",
    "broth",
    "cashews",
    "edamame pasta",
    "nutritional yeast",
    "lemon",
    "salt",
    "pepper",
    "oil",
    "cream"
  ],
  "directions": [
    "Sauté the onion in oil until softened",
    "Add the drained broccoli to the blender with the sautéed onion, broth, cashews, nutritional yeast, lemon juice, salt, and pepper",
    "Blend until smooth",
    "Cook the edamame pasta according to package instructions",
    "Combine the blended broccoli mixture with the cooked pasta",
    "Serve hot and enjoy"
  ]
}
''';

// ─────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────

void main() {
  group('Recipe Extraction Harness', () {
    test('show prompt that would be sent to Foundation Models', () {
      final llm = HarnessLlmService(goodLlmResponse);

      // Build the exact same prompt the real pipeline builds
      final instructions = LlmPrompts.fullExtractionInstructions();
      final userPrompt = LlmPrompts.fullExtractionUserPrompt(
        'TRANSCRIPT:\n$broccoliPastaTranscript',
        videoTitle: broccoliPastaTitle,
      );

      // ignore: avoid_print
      print('\n${'─' * 60}');
      // ignore: avoid_print
      print('SYSTEM INSTRUCTIONS (${instructions.length} chars):');
      // ignore: avoid_print
      print('─' * 60);
      // ignore: avoid_print
      print(instructions);
      // ignore: avoid_print
      print('\n${'─' * 60}');
      // ignore: avoid_print
      print('USER PROMPT (${userPrompt.length} chars):');
      // ignore: avoid_print
      print('─' * 60);
      // ignore: avoid_print
      print(userPrompt);
      // ignore: avoid_print
      print('─' * 60);

      // Verify prompt is under token budget (~12800 chars for input)
      expect(instructions.length + userPrompt.length, lessThan(12800));
      expect(llm.name, 'Harness Mock'); // just to use the variable
    });

    test('full pipeline with GOOD LLM response', () async {
      final llm = HarnessLlmService(goodLlmResponse);

      final recipe = await LlmRecipeExtractionService.tryFullLlm(
        transcript: broccoliPastaTranscript,
        ocrText: null,
        description: null,
        llmService: llm,
        videoTitle: broccoliPastaTitle,
        sourceUrl: 'https://youtube.com/shorts/K6wEWWhJf7Q',
        sourcePlatform: 'youtube',
      );

      expect(recipe, isNotNull);
      printPrompt(llm);
      printRecipe(recipe!);

      // ── Compare against golden reference ──
      // ignore: avoid_print
      print('\nGOLDEN COMPARISON:');
      final recipeItems =
          recipe.ingredients.map((i) => i.item.toLowerCase()).toSet();
      for (final golden in broccoliPastaGolden) {
        final lower = golden.toLowerCase();
        final found = recipeItems
            .any((r) => lower.contains(r) || r.contains(lower.split(' ').last));
        // ignore: avoid_print
        print('  ${found ? "✓" : "✗"} $golden');
      }

      // Basic quality checks
      expect(recipe.ingredients.length, greaterThanOrEqualTo(8));
      expect(recipe.directions.length, greaterThanOrEqualTo(4));
    });

    test('full pipeline with POOR LLM response (missing quantities & beans)',
        () async {
      final llm = HarnessLlmService(poorLlmResponse);

      final recipe = await LlmRecipeExtractionService.tryFullLlm(
        transcript: broccoliPastaTranscript,
        ocrText: null,
        description: null,
        llmService: llm,
        videoTitle: broccoliPastaTitle,
        sourceUrl: 'https://youtube.com/shorts/K6wEWWhJf7Q',
        sourcePlatform: 'youtube',
      );

      expect(recipe, isNotNull);
      printPrompt(llm);
      printRecipe(recipe!);

      // Cross-reference checker should have caught beans from transcript
      final ingredientNames =
          recipe.ingredients.map((i) => i.item.toLowerCase()).toList();
      // ignore: avoid_print
      print('\nPOST-PROCESSING RECOVERY CHECK:');
      // ignore: avoid_print
      print(
          '  beans auto-added from transcript: ${ingredientNames.any((i) => i.contains("bean"))}');
      // ignore: avoid_print
      print(
          '  cashew present: ${ingredientNames.any((i) => i.contains("cashew"))}');
      // ignore: avoid_print
      print(
          '  broccoli present: ${ingredientNames.any((i) => i.contains("broccoli"))}');
    });

    test('JSON response parsing (paste LLM output here)', () {
      // ┌────────────────────────────────────────────────────┐
      // │ PASTE YOUR LLM RESPONSE BETWEEN THE TRIPLE QUOTES │
      // └────────────────────────────────────────────────────┘
      const llmOutput = '''
{
  "title": "Cheesy Cream of Broccoli Pasta",
  "ingredients": ["PASTE", "YOUR", "RESPONSE", "HERE"],
  "directions": ["PASTE YOUR RESPONSE HERE"]
}
''';

      final parsed = LlmPrompts.parseResponse(llmOutput);
      if (parsed == null) {
        // ignore: avoid_print
        print('ERROR: Could not parse JSON response');
        return;
      }

      final result = LlmExtractionResult.fromJson(parsed);
      // ignore: avoid_print
      print('\nParsed ${result.ingredients.length} ingredients, '
          '${result.directions.length} directions');
      // ignore: avoid_print
      print('Meets quality threshold: ${result.meetsMinimumQuality}');
      for (final ing in result.ingredients) {
        // ignore: avoid_print
        print('  - ${ing.item}');
      }
    });
  });

  // ─────────────────────────────────────────────────────────────
  // YouTube URL Pipeline (requires network)
  // ─────────────────────────────────────────────────────────────

  group('YouTube URL Pipeline', () {
    // ┌────────────────────────────────────────────────────┐
    // │ SET YOUR YOUTUBE URL HERE                          │
    // └────────────────────────────────────────────────────┘
    const youtubeUrl = 'https://youtube.com/shorts/K6wEWWhJf7Q';

    // ┌────────────────────────────────────────────────────┐
    // │ PASTE LLM JSON RESPONSE HERE (after running Step 1)│
    // └────────────────────────────────────────────────────┘
    const llmResponse = '';

    test('Step 1: fetch YouTube data and show prompt', tags: ['network'],
        () async {
      // ignore: avoid_print
      print('\nFetching YouTube data for: $youtubeUrl');

      final data = await YouTubeHelper.fetch(youtubeUrl);

      // ignore: avoid_print
      print('\n${'=' * 60}');
      // ignore: avoid_print
      print('YOUTUBE VIDEO DATA');
      // ignore: avoid_print
      print('=' * 60);
      // ignore: avoid_print
      print('Title: ${data.title}');
      // ignore: avoid_print
      print('Duration: ${data.duration}');
      // ignore: avoid_print
      print('Captions: ${data.captionSource}');
      // ignore: avoid_print
      print('Description (${data.description.length} chars): '
          '${data.description.substring(0, data.description.length.clamp(0, 200))}'
          '${data.description.length > 200 ? "..." : ""}');
      if (data.captionText != null) {
        // ignore: avoid_print
        print('Transcript (${data.captionText!.length} chars): '
            '${data.captionText!.substring(0, data.captionText!.length.clamp(0, 200))}'
            '${data.captionText!.length > 200 ? "..." : ""}');
      }
      // ignore: avoid_print
      print('=' * 60);

      // Build prompt based on available data
      late final String instructions;
      late final String userPrompt;

      if (data.captionText != null && data.captionText!.isNotEmpty) {
        // Full extraction path: description + transcript
        final combinedText = buildCombinedText(
          description: data.description.isNotEmpty ? data.description : null,
          transcript: data.captionText,
        );
        instructions = LlmPrompts.fullExtractionInstructions();
        userPrompt = LlmPrompts.fullExtractionUserPrompt(
          combinedText,
          videoTitle: data.title,
        );
      } else {
        // Description-only fallback
        instructions = LlmPrompts.descriptionOnlyInstructions();
        userPrompt = LlmPrompts.descriptionOnlyUserPrompt(
          data.description,
          videoTitle: data.title,
        );
      }

      // ignore: avoid_print
      print('\n${'─' * 60}');
      // ignore: avoid_print
      print('SYSTEM INSTRUCTIONS (${instructions.length} chars):');
      // ignore: avoid_print
      print('─' * 60);
      // ignore: avoid_print
      print(instructions);
      // ignore: avoid_print
      print('\n${'─' * 60}');
      // ignore: avoid_print
      print('USER PROMPT (${userPrompt.length} chars):');
      // ignore: avoid_print
      print('─' * 60);
      // ignore: avoid_print
      print(userPrompt);
      // ignore: avoid_print
      print('─' * 60);

      expect(data.title, isNotEmpty);
    });

    test('Step 2: full pipeline with LLM response', tags: ['network'],
        () async {
      if (llmResponse.trim().isEmpty) {
        // ignore: avoid_print
        print('\n'
            '┌────────────────────────────────────────────────────┐\n'
            '│ No LLM response provided.                         │\n'
            '│                                                    │\n'
            '│ 1. Run "Step 1" first to get the prompt            │\n'
            '│ 2. Paste the prompt into any LLM                   │\n'
            '│ 3. Copy the JSON response into llmResponse         │\n'
            '│ 4. Re-run this test                                │\n'
            '└────────────────────────────────────────────────────┘');
        return;
      }

      final data = await YouTubeHelper.fetch(youtubeUrl);
      final llm = HarnessLlmService(llmResponse);

      late final dynamic recipe;

      if (data.captionText != null && data.captionText!.isNotEmpty) {
        recipe = await LlmRecipeExtractionService.tryFullLlm(
          transcript: data.captionText,
          ocrText: null,
          description: data.description.isNotEmpty ? data.description : null,
          llmService: llm,
          videoTitle: data.title,
          sourceUrl: youtubeUrl,
          sourcePlatform: 'youtube',
        );
      } else {
        recipe = await LlmRecipeExtractionService.tryDescriptionOnly(
          description: data.description,
          llmService: llm,
          videoTitle: data.title,
          sourceUrl: youtubeUrl,
          sourcePlatform: 'youtube',
        );
      }

      expect(recipe, isNotNull);
      printPrompt(llm);
      printRecipe(recipe!);
    });

    test('description-only path', tags: ['network'], () async {
      final data = await YouTubeHelper.fetch(youtubeUrl);

      if (data.description.trim().isEmpty) {
        // ignore: avoid_print
        print('\nVideo has no description — nothing to test.');
        return;
      }

      final instructions = LlmPrompts.descriptionOnlyInstructions();
      final userPrompt = LlmPrompts.descriptionOnlyUserPrompt(
        data.description,
        videoTitle: data.title,
      );

      // ignore: avoid_print
      print('\n${'─' * 60}');
      // ignore: avoid_print
      print('DESCRIPTION-ONLY PROMPT');
      // ignore: avoid_print
      print('─' * 60);
      // ignore: avoid_print
      print('SYSTEM INSTRUCTIONS (${instructions.length} chars):');
      // ignore: avoid_print
      print('─' * 60);
      // ignore: avoid_print
      print(instructions);
      // ignore: avoid_print
      print('\n${'─' * 60}');
      // ignore: avoid_print
      print('USER PROMPT (${userPrompt.length} chars):');
      // ignore: avoid_print
      print('─' * 60);
      // ignore: avoid_print
      print(userPrompt);
      // ignore: avoid_print
      print('─' * 60);

      expect(data.description, isNotEmpty);
    });
  });
}
