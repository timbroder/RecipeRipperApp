/// Filters noise from transcript and OCR text before recipe parsing.
/// Ports 30+ patterns from the Python CLI's noise filtering.
class NoiseFilter {
  // YouTube UI patterns
  static final _youtubeUiPatterns = [
    RegExp(r'^@\w+', caseSensitive: false), // @username
    RegExp(r'^\d+[\d.,]*[KkMm]?\s*(views|subscribers|likes|comments)',
        caseSensitive: false),
    RegExp(r'^\d+:\d+(:\d+)?$'), // timestamps like 1:23 or 1:23:45
    RegExp(r'^#\w+'), // hashtags
  ];

  // Subscribe/like/share phrases
  static final _engagementPatterns = [
    RegExp(r'\b(subscribe|like|share|comment|notification bell)\b',
        caseSensitive: false),
    RegExp(r'\bhit\s+(the\s+)?(like|subscribe|bell|notification)\b',
        caseSensitive: false),
    RegExp(r'\bdon.t\s+forget\s+to\s+(like|subscribe|share)\b',
        caseSensitive: false),
    RegExp(r'\bsmash\s+that\s+(like|subscribe)\b', caseSensitive: false),
    RegExp(r'\bturn\s+on\s+(post\s+)?notifications?\b', caseSensitive: false),
  ];

  // Promotional patterns
  static final _promotionalPatterns = [
    RegExp(r'\b(discount\s+code|promo\s+code|coupon\s+code)\b',
        caseSensitive: false),
    RegExp(r'\b(affiliate\s+link|sponsored)\b', caseSensitive: false),
    RegExp(r'\b(shop\s+now|buy\s+now|order\s+now|link\s+in\s+(the\s+)?bio)\b',
        caseSensitive: false),
    RegExp(r'\buse\s+(my\s+)?code\b', caseSensitive: false),
    RegExp(r'https?://\S+', caseSensitive: false), // URLs
  ];

  // Commentary/filler patterns
  static final _commentaryPatterns = [
    RegExp(r'^(hey|hi|hello|what.s up|yo)\s+(guys|everyone|everybody|friends)',
        caseSensitive: false),
    RegExp(r'\bwelcome\s+(back\s+)?to\s+(my|the|our)\s+(channel|kitchen)\b',
        caseSensitive: false),
    RegExp(r'\bthanks?\s+(so\s+much\s+)?for\s+(watching|viewing|tuning\s+in)\b',
        caseSensitive: false),
    RegExp(r'\blet\s+me\s+know\s+in\s+the\s+comments?\b', caseSensitive: false),
    RegExp(r'\bsee\s+you\s+(in\s+the\s+)?next\s+(video|one|episode)\b',
        caseSensitive: false),
    RegExp(r'\bbefore\s+we\s+(get\s+)?start(ed)?\b', caseSensitive: false),
    RegExp(r'\bwithout\s+further\s+ado\b', caseSensitive: false),
    RegExp(r'\bif\s+you\s+(like|enjoy|love)(d)?\s+this\s+(video|recipe)\b',
        caseSensitive: false),
  ];

  // Nutrition label patterns
  static final _nutritionPatterns = [
    RegExp(r'\b(calories|cal|kcal)\s*[:\-]?\s*\d+', caseSensitive: false),
    RegExp(
        r'\b(total\s+)?(fat|carbs?|carbohydrates?|protein|sodium|fiber)\s*[:\-]?\s*\d+\s*(g|mg|%)',
        caseSensitive: false),
    RegExp(r'\bserving\s+size\b', caseSensitive: false),
    RegExp(r'\bdaily\s+value\b', caseSensitive: false),
    RegExp(r'\bnutrition\s+(facts?|info|information)\b', caseSensitive: false),
  ];

  // OCR artifact patterns
  static final _ocrArtifactPattern = RegExp(r'^[^a-zA-Z]*$');
  static final _allCapsShortPattern = RegExp(r'^[A-Z\s]{2,20}$');

  // Food words that are OK even in ALL CAPS
  static const _foodWordsAllCaps = {
    'FLOUR', 'SUGAR', 'SALT', 'PEPPER', 'BUTTER', 'OIL', 'WATER', 'MILK',
    'EGG', 'EGGS', 'CREAM', 'CHEESE', 'GARLIC', 'ONION', 'CHICKEN', 'BEEF',
    'PORK', 'FISH', 'RICE', 'PASTA', 'BREAD', 'VANILLA', 'CHOCOLATE',
    'HONEY', 'LEMON', 'LIME', 'GINGER', 'CINNAMON', // common in OCR
  };

  // Empty section headers
  static final _sectionHeaderPattern = RegExp(
    r'^(ingredients?|directions?|instructions?|steps?|method|preparation|recipe)\s*:?\s*$',
    caseSensitive: false,
  );

  // Single common words that are OCR fragments
  static const _fragmentWords = {
    'and',
    'the',
    'a',
    'an',
    'or',
    'of',
    'to',
    'in',
    'on',
    'it',
    'is',
    'for',
    'by',
    'at',
    'be',
    'as',
    'so',
    'if',
    'no',
    'do',
    'up',
    'my',
  };

  /// Filter a single line. Returns null to remove the line entirely,
  /// or a cleaned version of the line.
  static String? filterLine(String line) {
    final trimmed = line.trim();

    // Remove empty lines
    if (trimmed.isEmpty) return null;

    // Remove very short lines (1-2 chars) that are likely artifacts
    if (trimmed.length <= 2) return null;

    // Remove lines that are just symbols/numbers (OCR artifacts)
    if (_ocrArtifactPattern.hasMatch(trimmed)) return null;

    // Remove single common words (OCR fragments)
    if (_fragmentWords.contains(trimmed.toLowerCase())) return null;

    // Remove empty section headers
    if (_sectionHeaderPattern.hasMatch(trimmed)) return null;

    // Remove short ALL CAPS phrases (OCR artifacts) unless they're food words
    if (_allCapsShortPattern.hasMatch(trimmed)) {
      final upper = trimmed.toUpperCase();
      if (!_foodWordsAllCaps.contains(upper)) {
        return null;
      }
    }

    // Remove YouTube UI patterns
    for (final pattern in _youtubeUiPatterns) {
      if (pattern.hasMatch(trimmed)) return null;
    }

    // Remove engagement patterns (these contaminate the whole line)
    for (final pattern in _engagementPatterns) {
      if (pattern.hasMatch(trimmed)) return null;
    }

    // Remove promotional patterns
    for (final pattern in _promotionalPatterns) {
      if (pattern.hasMatch(trimmed)) return null;
    }

    // Remove commentary/filler patterns
    for (final pattern in _commentaryPatterns) {
      if (pattern.hasMatch(trimmed)) return null;
    }

    // Remove nutrition label patterns
    for (final pattern in _nutritionPatterns) {
      if (pattern.hasMatch(trimmed)) return null;
    }

    // Remove long words without spaces (likely OCR artifact)
    if (!trimmed.contains(' ') && trimmed.length > 25) return null;

    return trimmed;
  }

  /// Filter all lines in a text block.
  /// Returns cleaned text with noise lines removed.
  static String filterText(String text) {
    final lines = text.split('\n');
    final filtered = <String>[];

    for (final line in lines) {
      final result = filterLine(line);
      if (result != null) {
        filtered.add(result);
      }
    }

    return filtered.join('\n');
  }
}
