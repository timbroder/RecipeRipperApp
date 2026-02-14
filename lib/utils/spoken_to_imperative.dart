/// Converts spoken/conversational recipe directions to imperative form.
/// Ports conversion patterns from the Python CLI.
class SpokenToImperative {
  static final _patterns = <RegExp>[
    // "I'm gonna add X" → "Add X"
    RegExp(r"^i'?m\s+(gonna|going\s+to)\s+", caseSensitive: false),
    // "you're gonna wanna stir" → "Stir"
    RegExp(r"^you'?re\s+(gonna|going\s+to)\s+(wanna|want\s+to)\s+",
        caseSensitive: false),
    // "you want to / you wanna" → ""
    RegExp(r"^you\s+(want\s+to|wanna)\s+", caseSensitive: false),
    // "we're going to cook this" → "Cook this"
    RegExp(r"^we'?re\s+(gonna|going\s+to)\s+", caseSensitive: false),
    // "we want to / we wanna" → ""
    RegExp(r"^we\s+(want\s+to|wanna)\s+", caseSensitive: false),
    // "go ahead and mix" → "Mix"
    RegExp(r'^go\s+ahead\s+and\s+', caseSensitive: false),
    // "make sure you/to preheat" → "Preheat"
    RegExp(r'^make\s+sure\s+(you\s+|to\s+)', caseSensitive: false),
    // "what you do is blend" → "Blend"
    RegExp(r'^what\s+(you|we)\s+(do|want)\s+is\s+', caseSensitive: false),
    // "so now we add" → "Add"
    RegExp(r'^so\s+(now\s+)?(we|you|i)\s+', caseSensitive: false),
    // "now we / now you / now I" → ""
    RegExp(r'^now\s+(we|you|i)\s+', caseSensitive: false),
    // "then we / then you / then I" → ""
    RegExp(r'^(and\s+)?then\s+(we|you|i)\s+', caseSensitive: false),
    // "I like to let it sit" → "Let it sit"
    RegExp(r'^i\s+(like|want|need)\s+to\s+', caseSensitive: false),
    // "you just / just" at start of cooking instruction
    RegExp(r'^(you\s+)?just\s+', caseSensitive: false),
    // "what I do is" / "what I like to do is"
    RegExp(r'^what\s+i\s+(like\s+to\s+)?do\s+is\s+', caseSensitive: false),
    // "you're going to want to" → ""
    RegExp(r"^you'?re\s+going\s+to\s+want\s+to\s+", caseSensitive: false),
  ];

  // Trailing filler patterns
  static final _trailingPatterns = [
    RegExp(r'\s+and\s+then\.{0,3}$', caseSensitive: false),
    RegExp(r'\s+you\s+know\.{0,3}$', caseSensitive: false),
    RegExp(r'\s+right\.{0,3}$', caseSensitive: false),
    RegExp(r'\s+okay\.{0,3}$', caseSensitive: false),
    RegExp(r'\s+so\s+yeah\.{0,3}$', caseSensitive: false),
  ];

  /// Convert a single spoken direction to imperative form.
  static String convert(String text) {
    var result = text.trim();
    if (result.isEmpty) return result;

    // Apply spoken-to-imperative patterns
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(result);
      if (match != null) {
        result = result.replaceFirst(pattern, '').trim();
        break; // Only apply one prefix pattern
      }
    }

    // Strip trailing filler
    for (final pattern in _trailingPatterns) {
      result = result.replaceFirst(pattern, '').trim();
    }

    // Capitalize first letter
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }

    // Clean multiple spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Convert a list of spoken directions to imperative form.
  static List<String> convertAll(List<String> texts) {
    return texts.map(convert).where((t) => t.isNotEmpty).toList();
  }
}
