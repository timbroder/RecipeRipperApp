import 'dart:convert';

/// Prompt templates for LLM recipe extraction.
class LlmPrompts {
  /// Prompt for full extraction from transcript + OCR + description text.
  static String fullExtractionPrompt(String text, {String? videoTitle}) {
    final titleHint =
        videoTitle != null ? '\nThe video title is: "$videoTitle"\n' : '';

    return '''You are a recipe extraction assistant. Extract a structured recipe from the following text, which comes from a cooking video's transcript, on-screen text (OCR), and description.
$titleHint
Return ONLY valid JSON in this exact format (no markdown, no explanation):
{"title":"Recipe Name","ingredients":[{"quantity":"1","unit":"cup","item":"flour","notes":"sifted"}],"directions":["Preheat oven to 350F.","Mix dry ingredients."]}

Rules:
- Extract ALL ingredients with quantities, units, and item names when possible
- Extract ALL cooking directions as clear, imperative steps
- If quantity is a fraction, write it as a string like "1/2" or "1 1/2"
- If no unit applies, set unit to null
- If no notes apply, set notes to null
- Ignore non-recipe content (greetings, promotions, commentary)
- If the text contains multiple recipes, extract only the main one
- Generate a descriptive title if none is obvious

Text to extract from:
$text''';
  }

  /// Prompt for extraction from just the video description (fast path).
  static String descriptionOnlyPrompt(
    String description, {
    String? videoTitle,
  }) {
    final titleHint =
        videoTitle != null ? '\nThe video title is: "$videoTitle"\n' : '';

    return '''You are a recipe extraction assistant. Extract a structured recipe from the following video description. Video descriptions often contain a full recipe with ingredients and directions.
$titleHint
Return ONLY valid JSON in this exact format (no markdown, no explanation):
{"title":"Recipe Name","ingredients":[{"quantity":"1","unit":"cup","item":"flour","notes":"sifted"}],"directions":["Preheat oven to 350F.","Mix dry ingredients."]}

Rules:
- Extract ALL ingredients with quantities, units, and item names
- Extract ALL cooking directions as clear, imperative steps
- If quantity is a fraction, write it as a string like "1/2" or "1 1/2"
- If no unit applies, set unit to null
- If no notes apply, set notes to null
- Only extract if there is a clear recipe present
- If no recipe is found, return: {"title":null,"ingredients":[],"directions":[]}

Video description:
$description''';
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
