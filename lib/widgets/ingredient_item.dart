import 'package:flutter/material.dart';
import '../models/ingredient.dart';

/// A widget for displaying a single ingredient.
/// Supports cooking mode with checkboxes and optional editing.
class IngredientItem extends StatelessWidget {
  final Ingredient ingredient;
  final bool isChecked;
  final bool showCheckbox;
  final ValueChanged<bool?>? onCheckChanged;
  final VoidCallback? onTap;

  const IngredientItem({
    super.key,
    required this.ingredient,
    this.isChecked = false,
    this.showCheckbox = false,
    this.onCheckChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCheckbox) ...[
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isChecked,
              onChanged: onCheckChanged,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
        ] else ...[
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
        Expanded(
          child: _buildIngredientText(context),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: content,
    );
  }

  Widget _buildIngredientText(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final baseStyle = textTheme.bodyLarge?.copyWith(
      decoration: isChecked ? TextDecoration.lineThrough : null,
      color: isChecked
          ? colorScheme.onSurface.withAlpha(128)
          : colorScheme.onSurface,
    );

    // Build rich text with quantity and unit styled differently
    final spans = <InlineSpan>[];

    if (ingredient.quantity != null) {
      String quantityStr;
      if (ingredient.quantity! % 1 == 0) {
        quantityStr = ingredient.quantity!.toInt().toString();
      } else {
        quantityStr = _formatQuantity(ingredient.quantity!);
      }
      spans.add(TextSpan(
        text: quantityStr,
        style: baseStyle?.copyWith(fontWeight: FontWeight.w600),
      ));
      spans.add(const TextSpan(text: ' '));
    }

    if (ingredient.unit != null && ingredient.unit!.isNotEmpty) {
      spans.add(TextSpan(
        text: ingredient.unit,
        style: baseStyle?.copyWith(
          color: isChecked
              ? colorScheme.onSurface.withAlpha(102)
              : colorScheme.primary,
        ),
      ));
      spans.add(const TextSpan(text: ' '));
    }

    spans.add(TextSpan(
      text: ingredient.item,
      style: baseStyle,
    ));

    if (ingredient.notes != null && ingredient.notes!.isNotEmpty) {
      spans.add(TextSpan(
        text: ' (${ingredient.notes})',
        style: baseStyle?.copyWith(
          fontStyle: FontStyle.italic,
          color: isChecked
              ? colorScheme.onSurface.withAlpha(77)
              : colorScheme.onSurfaceVariant,
        ),
      ));
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
    );
  }

  String _formatQuantity(double quantity) {
    // Handle common fractions
    final fractionMap = {
      0.25: '1/4',
      0.33: '1/3',
      0.5: '1/2',
      0.67: '2/3',
      0.75: '3/4',
      0.125: '1/8',
      0.375: '3/8',
      0.625: '5/8',
      0.875: '7/8',
    };

    final wholePart = quantity.truncate();
    final fractionalPart = quantity - wholePart;

    // Check if fractional part matches a common fraction
    for (final entry in fractionMap.entries) {
      if ((fractionalPart - entry.key).abs() < 0.01) {
        if (wholePart > 0) {
          return '$wholePart ${entry.value}';
        }
        return entry.value;
      }
    }

    // Default to decimal format
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}

/// A compact ingredient chip for display in summaries.
class IngredientChip extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback? onTap;

  const IngredientChip({
    super.key,
    required this.ingredient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(
        Icons.check_circle_outline,
        size: 18,
        color: colorScheme.primary,
      ),
      label: Text(ingredient.item),
      onPressed: onTap,
    );
  }
}
