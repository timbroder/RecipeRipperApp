import 'dart:convert';

/// Prompt templates for LLM recipe extraction.
///
/// Prompts are split into instructions (system prompt) and user prompt
/// to support Foundation Models' separate instructions parameter and
/// maximize the usable context window.
///
/// Output uses flat ingredient strings ("2 tablespoons olive oil") instead of
/// structured objects to save tokens within the 4K context window.
class LlmPrompts {
  // ── Full extraction (transcript + OCR + description) ──

  /// System instructions for full recipe extraction.
  static String fullExtractionInstructions() {
    return 'You extract recipes from cooking video text into JSON. '
        'Output format: {"title":"NAME","ingredients":["AMOUNT ITEM","AMOUNT ITEM"],"directions":["STEP","STEP"]} '
        'IMPORTANT: Only include ingredients and directions actually mentioned in the text. '
        'Do NOT invent or add any ingredients not in the text. '
        'Include every ingredient mentioned, with quantity and unit when given. '
        'Directions should be imperative steps. '
        'Ignore greetings, promotions, and non-recipe content.';
  }

  /// User prompt for full extraction containing just the input text.
  static String fullExtractionUserPrompt(String text, {String? videoTitle}) {
    final titleHint =
        videoTitle != null ? 'Video title: "$videoTitle"\n\n' : '';
    return '${titleHint}Extract the recipe from this text:\n\n$text';
  }

  /// Combined prompt for services that don't support separate instructions.
  static String fullExtractionPrompt(String text, {String? videoTitle}) {
    return '${fullExtractionInstructions()}\n\n'
        '${fullExtractionUserPrompt(text, videoTitle: videoTitle)}';
  }

  // ── Description-only extraction (fast path) ──

  /// System instructions for description-only extraction.
  static String descriptionOnlyInstructions() {
    return 'You extract recipes from video descriptions into JSON. '
        'Output format: {"title":"NAME","ingredients":["AMOUNT ITEM","AMOUNT ITEM"],"directions":["STEP","STEP"]} '
        'IMPORTANT: Only include ingredients and directions actually in the text. '
        'Do NOT invent or add any ingredients not in the text. '
        'Include every ingredient mentioned, with quantity and unit when given. '
        'Directions should be imperative steps. '
        'If no recipe found: {"title":null,"ingredients":[],"directions":[]}';
  }

  /// User prompt for description-only extraction.
  static String descriptionOnlyUserPrompt(
    String description, {
    String? videoTitle,
  }) {
    final titleHint =
        videoTitle != null ? 'Video title: "$videoTitle"\n\n' : '';
    return '${titleHint}Video description:\n\n$description';
  }

  /// Combined prompt for services that don't support separate instructions.
  static String descriptionOnlyPrompt(
    String description, {
    String? videoTitle,
  }) {
    return '${descriptionOnlyInstructions()}\n\n'
        '${descriptionOnlyUserPrompt(description, videoTitle: videoTitle)}';
  }

  /// Parse a JSON response from the LLM, with fallback strategies.
  static Map<String, dynamic>? parseResponse(String response) {
    // Strategy 1: Direct parse
    try {
      final decoded = jsonDecode(response.trim());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // Strategy 2: Strip markdown code fences
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final fenceMatch = fencePattern.firstMatch(response);
    if (fenceMatch != null) {
      try {
        final decoded = jsonDecode(fenceMatch.group(1)!.trim());
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // Strategy 3: Find first { ... } block via regex
    final bracePattern = RegExp(r'\{[\s\S]*\}');
    final braceMatch = bracePattern.firstMatch(response);
    if (braceMatch != null) {
      try {
        final decoded = jsonDecode(braceMatch.group(0)!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }
}
