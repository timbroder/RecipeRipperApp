import '../models/ingredient.dart';
import '../models/direction.dart';
import 'parsing_utils.dart';

/// Deduplication utilities for ingredients and directions
class Deduplicator {
  /// Deduplicate ingredients based on similarity
  /// Merges similar ingredients and sums quantities if units match
  static List<Ingredient> deduplicateIngredients(List<Ingredient> ingredients) {
    if (ingredients.isEmpty) return [];

    final deduplicated = <Ingredient>[];
    final seen = <int>{};

    for (int i = 0; i < ingredients.length; i++) {
      if (seen.contains(i)) continue;

      final current = ingredients[i];
      double totalQuantity = current.quantity ?? 0.0;
      final duplicateIndices = <int>[];

      // Look for duplicates
      for (int j = i + 1; j < ingredients.length; j++) {
        if (seen.contains(j)) continue;

        final other = ingredients[j];

        // Check if items are similar
        final similarity = ParsingUtils.stringSimilarity(
          current.item,
          other.item,
        );

        // High similarity threshold (0.7) for merging
        if (similarity >= 0.7) {
          // If units match, sum quantities
          if (current.unit == other.unit && other.quantity != null) {
            totalQuantity += other.quantity!;
            duplicateIndices.add(j);
          } else if (current.unit == other.unit ||
              (current.unit == null && other.unit == null)) {
            // Same unit or both null - mark as duplicate but don't sum
            duplicateIndices.add(j);
          }
        }
      }

      // Mark duplicates as seen
      for (final idx in duplicateIndices) {
        seen.add(idx);
      }

      // Add deduplicated ingredient
      if (totalQuantity > 0 && totalQuantity != (current.quantity ?? 0.0)) {
        deduplicated.add(
          current.copyWith(quantity: totalQuantity),
        );
      } else {
        deduplicated.add(current);
      }
    }

    return deduplicated;
  }

  /// Deduplicate directions based on text similarity
  /// Removes duplicate steps with similar text
  static List<Direction> deduplicateDirections(List<Direction> directions) {
    if (directions.isEmpty) return [];

    final deduplicated = <Direction>[];
    final seen = <int>{};

    for (int i = 0; i < directions.length; i++) {
      if (seen.contains(i)) continue;

      final current = directions[i];

      // Look for near-duplicates
      for (int j = i + 1; j < directions.length; j++) {
        if (seen.contains(j)) continue;

        final other = directions[j];

        // Check text similarity
        final similarity = ParsingUtils.stringSimilarity(
          current.text,
          other.text,
        );

        // High similarity threshold (0.8) for directions
        if (similarity >= 0.8) {
          seen.add(j);
        }
      }

      deduplicated.add(current);
    }

    // Renumber steps sequentially
    final renumbered = <Direction>[];
    for (int i = 0; i < deduplicated.length; i++) {
      renumbered.add(
        deduplicated[i].copyWith(stepNumber: i + 1),
      );
    }

    return renumbered;
  }

  /// Deduplicate raw text lines based on exact or near-exact matches
  /// Useful for removing duplicate lines from OCR/transcript
  static List<String> deduplicateTextLines(List<String> lines) {
    if (lines.isEmpty) return [];

    final deduplicated = <String>[];
    final seen = <String>{};

    for (final line in lines) {
      final normalized = ParsingUtils.normalizeForComparison(line);

      // Skip if we've seen this exact text before
      if (seen.contains(normalized)) continue;

      // Check for high similarity with existing lines
      bool isDuplicate = false;
      for (final existing in deduplicated) {
        final similarity = ParsingUtils.stringSimilarity(line, existing);
        if (similarity >= 0.9) {
          // Very high similarity = duplicate
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        deduplicated.add(line);
        seen.add(normalized);
      }
    }

    return deduplicated;
  }

  /// Merge duplicate ingredients by item name
  /// Groups ingredients with the same item name and sums quantities
  static List<Ingredient> mergeByItemName(List<Ingredient> ingredients) {
    if (ingredients.isEmpty) return [];

    final grouped = <String, List<Ingredient>>{};

    // Group by normalized item name
    for (final ingredient in ingredients) {
      final key = ParsingUtils.normalizeForComparison(ingredient.item);
      grouped.putIfAbsent(key, () => []).add(ingredient);
    }

    final merged = <Ingredient>[];

    // Merge each group
    for (final group in grouped.values) {
      if (group.length == 1) {
        merged.add(group.first);
        continue;
      }

      // Multiple ingredients with same item - merge if units match
      final byUnit = <String?, List<Ingredient>>{};
      for (final ingredient in group) {
        final unitKey = ingredient.unit?.toLowerCase();
        byUnit.putIfAbsent(unitKey, () => []).add(ingredient);
      }

      for (final unitGroup in byUnit.values) {
        if (unitGroup.length == 1) {
          merged.add(unitGroup.first);
        } else {
          // Sum quantities for same unit
          double totalQuantity = 0.0;
          final first = unitGroup.first;

          for (final ingredient in unitGroup) {
            totalQuantity += ingredient.quantity ?? 0.0;
          }

          merged.add(
            first.copyWith(
              quantity: totalQuantity > 0 ? totalQuantity : null,
            ),
          );
        }
      }
    }

    return merged;
  }
}
