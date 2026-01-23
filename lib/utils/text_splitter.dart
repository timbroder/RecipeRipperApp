import 'parsing_utils.dart';
import 'ingredient_classifier.dart';
import 'direction_classifier.dart';

/// Splits raw text (transcript + OCR) into structured sections
class TextSplitter {
  /// Split combined text into potential ingredient and direction lines
  /// Returns a map with 'ingredients' and 'directions' lists
  static Map<String, List<String>> splitIntoSections(String text) {
    final lines = ParsingUtils.splitIntoLines(text);

    final ingredientLines = <String>[];
    final directionLines = <String>[];
    final uncertainLines = <String>[];

    // Classify each line
    for (final line in lines) {
      if (line.length < 2) continue; // Skip very short lines

      final ingredientScore = IngredientClassifier.classifyAsIngredient(line);
      final directionScore = DirectionClassifier.classifyAsDirection(line);

      // Threshold for classification (can be tuned)
      const threshold = 0.3;

      if (ingredientScore > directionScore && ingredientScore >= threshold) {
        ingredientLines.add(line);
      } else if (directionScore > ingredientScore &&
          directionScore >= threshold) {
        directionLines.add(line);
      } else {
        // Store uncertain lines for later processing
        uncertainLines.add(line);
      }
    }

    // Process uncertain lines - use section context
    // If we have more ingredients than directions so far, bias towards ingredients
    // and vice versa
    for (final line in uncertainLines) {
      final ingredientScore = IngredientClassifier.classifyAsIngredient(line);
      final directionScore = DirectionClassifier.classifyAsDirection(line);

      if (ingredientLines.length > directionLines.length * 2) {
        // Bias towards ingredients
        if (ingredientScore > 0.2) {
          ingredientLines.add(line);
        } else if (directionScore > 0.2) {
          directionLines.add(line);
        }
      } else if (directionLines.length > ingredientLines.length * 2) {
        // Bias towards directions
        if (directionScore > 0.2) {
          directionLines.add(line);
        } else if (ingredientScore > 0.2) {
          ingredientLines.add(line);
        }
      } else {
        // No strong bias - use strict threshold
        if (ingredientScore > directionScore && ingredientScore > 0.25) {
          ingredientLines.add(line);
        } else if (directionScore > ingredientScore && directionScore > 0.25) {
          directionLines.add(line);
        }
        // Otherwise, discard the line
      }
    }

    return {
      'ingredients': ingredientLines,
      'directions': directionLines,
    };
  }

  /// Extract title from text (usually the first substantial line or most prominent text)
  static String? extractTitle(String text, {String? videoTitle}) {
    if (videoTitle != null && videoTitle.isNotEmpty) {
      // Clean up video title
      String cleaned = videoTitle;

      // Remove common video title patterns
      cleaned = cleaned.replaceAll(
          RegExp(r'\s*\|\s*.*$'), ''); // Remove "| Channel Name"
      cleaned = cleaned.replaceAll(
        RegExp(r'\s*[-–—]\s*.*$'),
        '',
      ); // Remove "- description"
      cleaned = cleaned.replaceAll(
        RegExp(r'\(.*?\)', caseSensitive: false),
        '',
      ); // Remove (tags)
      cleaned = cleaned.replaceAll(
        RegExp(r'\[.*?\]', caseSensitive: false),
        '',
      ); // Remove [tags]

      // Remove common suffixes
      final suffixes = [
        'recipe',
        'how to make',
        'easy',
        'quick',
        'best',
        'homemade',
        'simple',
        'delicious',
        'perfect',
      ];
      for (final suffix in suffixes) {
        cleaned = cleaned.replaceAll(
          RegExp('\\b$suffix\\b', caseSensitive: false),
          '',
        );
      }

      cleaned = ParsingUtils.cleanText(cleaned);
      if (cleaned.isNotEmpty && cleaned.length >= 3) {
        return cleaned;
      }
    }

    // Try to extract from OCR/transcript text
    final lines = ParsingUtils.splitIntoLines(text);
    if (lines.isEmpty) return null;

    // Look for a title-like line (short, no numbers, not ingredient/direction-like)
    for (final line in lines.take(5)) {
      // Check first 5 lines
      if (line.length >= 5 && line.length <= 60) {
        final ingredientScore = IngredientClassifier.classifyAsIngredient(line);
        final directionScore = DirectionClassifier.classifyAsDirection(line);

        // If it doesn't look like ingredient or direction, it might be a title
        if (ingredientScore < 0.3 && directionScore < 0.3) {
          return ParsingUtils.cleanText(line);
        }
      }
    }

    // Fallback to first line if nothing better found
    return lines.isNotEmpty ? ParsingUtils.cleanText(lines.first) : null;
  }
}
