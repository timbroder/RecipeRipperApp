/// Parsing utilities for recipe extraction
/// Includes unit normalization, fraction parsing, and text cleaning
class ParsingUtils {
  // Unit abbreviation mappings
  static const Map<String, String> unitAbbreviations = {
    // Volume
    'tbsp': 'tablespoon',
    'tbs': 'tablespoon',
    'T': 'tablespoon',
    'tsp': 'teaspoon',
    'ts': 'teaspoon',
    't': 'teaspoon',
    'c': 'cup',
    'C': 'cup',
    'oz': 'ounce',
    'fl oz': 'fluid ounce',
    'pt': 'pint',
    'qt': 'quart',
    'gal': 'gallon',
    'ml': 'milliliter',
    'mL': 'milliliter',
    'l': 'liter',
    'L': 'liter',
    // Weight
    'lb': 'pound',
    'lbs': 'pound',
    'oz': 'ounce',
    'g': 'gram',
    'kg': 'kilogram',
    'mg': 'milligram',
    // Length
    'in': 'inch',
    'cm': 'centimeter',
    'mm': 'millimeter',
    // Other
    'pkg': 'package',
    'can': 'can',
    'jar': 'jar',
    'box': 'box',
    'bag': 'bag',
  };

  // Common cooking units (for validation)
  static const Set<String> cookingUnits = {
    'tablespoon',
    'tablespoons',
    'teaspoon',
    'teaspoons',
    'cup',
    'cups',
    'ounce',
    'ounces',
    'fluid ounce',
    'fluid ounces',
    'pint',
    'pints',
    'quart',
    'quarts',
    'gallon',
    'gallons',
    'milliliter',
    'milliliters',
    'liter',
    'liters',
    'pound',
    'pounds',
    'gram',
    'grams',
    'kilogram',
    'kilograms',
    'milligram',
    'milligrams',
    'inch',
    'inches',
    'centimeter',
    'centimeters',
    'millimeter',
    'millimeters',
    'package',
    'packages',
    'can',
    'cans',
    'jar',
    'jars',
    'box',
    'boxes',
    'bag',
    'bags',
    'pinch',
    'dash',
    'handful',
    'slice',
    'slices',
    'piece',
    'pieces',
    'clove',
    'cloves',
    'stick',
    'sticks',
  };

  // Unicode fraction mappings
  static const Map<String, double> unicodeFractions = {
    '¼': 0.25,
    '½': 0.5,
    '¾': 0.75,
    '⅐': 0.142857,
    '⅑': 0.111111,
    '⅒': 0.1,
    '⅓': 0.333333,
    '⅔': 0.666667,
    '⅕': 0.2,
    '⅖': 0.4,
    '⅗': 0.6,
    '⅘': 0.8,
    '⅙': 0.166667,
    '⅚': 0.833333,
    '⅛': 0.125,
    '⅜': 0.375,
    '⅝': 0.625,
    '⅞': 0.875,
  };

  /// Normalize unit abbreviations to full words
  static String normalizeUnit(String unit) {
    final normalized = unit.trim().toLowerCase();
    return unitAbbreviations[normalized] ?? normalized;
  }

  /// Parse a fraction string to a double
  /// Handles unicode fractions (½, ¼), slash fractions (1/2), and mixed numbers (1 1/2)
  static double? parseFraction(String text) {
    text = text.trim();

    // Check for unicode fractions
    for (final entry in unicodeFractions.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    // Handle slash fractions (e.g., "1/2", "3/4")
    final slashMatch = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(text);
    if (slashMatch != null) {
      final numerator = int.parse(slashMatch.group(1)!);
      final denominator = int.parse(slashMatch.group(2)!);
      if (denominator != 0) {
        return numerator / denominator;
      }
    }

    // Handle mixed numbers (e.g., "1 1/2", "2½")
    final mixedMatch =
        RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)$').firstMatch(text);
    if (mixedMatch != null) {
      final whole = int.parse(mixedMatch.group(1)!);
      final numerator = int.parse(mixedMatch.group(2)!);
      final denominator = int.parse(mixedMatch.group(3)!);
      if (denominator != 0) {
        return whole + (numerator / denominator);
      }
    }

    // Check for unicode fraction with whole number (e.g., "1½")
    for (final entry in unicodeFractions.entries) {
      final pattern = RegExp(r'^(\d+)\s*' + RegExp.escape(entry.key) + r'$');
      final match = pattern.firstMatch(text);
      if (match != null) {
        final whole = int.parse(match.group(1)!);
        return whole + entry.value;
      }
    }

    // Try to parse as a simple decimal
    final decimal = double.tryParse(text);
    if (decimal != null) {
      return decimal;
    }

    return null;
  }

  /// Parse quantity from text (handles ranges like "1-2 cups", fractions, etc.)
  /// Returns the numeric value, or null if no quantity found
  static double? parseQuantity(String text) {
    text = text.trim();

    // Handle ranges (e.g., "1-2", "1 to 2") - take the average
    final rangeMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*(?:-|to)\s*(\d+(?:\.\d+)?)')
        .firstMatch(text);
    if (rangeMatch != null) {
      final low = double.parse(rangeMatch.group(1)!);
      final high = double.parse(rangeMatch.group(2)!);
      return (low + high) / 2;
    }

    // Try parsing as fraction
    final fraction = parseFraction(text);
    if (fraction != null) {
      return fraction;
    }

    // Try parsing as decimal
    return double.tryParse(text);
  }

  /// Clean OCR artifacts and normalize whitespace
  static String cleanText(String text) {
    // Remove excessive whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove common OCR artifacts
    text = text.replaceAll(RegExp(r'[|•●○◉◎]'), '');

    // Normalize quotes
    text = text.replaceAll(RegExp(r'[""]'), '"');
    text = text.replaceAll(RegExp(r"['']"), "'");

    // Normalize dashes
    text = text.replaceAll(RegExp(r'[—–]'), '-');

    // Remove zero-width characters
    text = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

    return text.trim();
  }

  /// Normalize text for comparison (lowercase, remove punctuation, etc.)
  static String normalizeForComparison(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Calculate similarity between two strings (simple Jaccard similarity)
  /// Returns a value between 0 and 1 (1 = identical, 0 = completely different)
  static double stringSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final wordsA = normalizeForComparison(a).split(' ').toSet();
    final wordsB = normalizeForComparison(b).split(' ').toSet();

    if (wordsA.isEmpty && wordsB.isEmpty) return 1.0;
    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;

    return intersection / union;
  }

  /// Extract temperature from text (e.g., "350°F", "180°C", "350 degrees")
  static RegExpMatch? findTemperature(String text) {
    return RegExp(
      r'(\d+)\s*°?\s*([FCfc]|degrees?\s*[FCfc]?)',
      caseSensitive: false,
    ).firstMatch(text);
  }

  /// Extract time duration from text (e.g., "10 minutes", "2 hours", "1hr 30min")
  static RegExpMatch? findTimeDuration(String text) {
    return RegExp(
      r'(\d+)\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)',
      caseSensitive: false,
    ).firstMatch(text);
  }

  /// Split text into lines, removing empty lines and cleaning each line
  static List<String> splitIntoLines(String text) {
    return text
        .split('\n')
        .map((line) => cleanText(line))
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Check if text contains a number
  static bool containsNumber(String text) {
    return RegExp(r'\d').hasMatch(text);
  }

  /// Check if a unit string is a valid cooking unit
  static bool isValidCookingUnit(String unit) {
    final normalized = normalizeUnit(unit.toLowerCase());
    return cookingUnits.contains(normalized) ||
        cookingUnits.contains('${normalized}s') ||
        cookingUnits.contains(normalized.replaceAll(RegExp(r's$'), ''));
  }
}
