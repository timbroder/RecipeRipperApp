import 'package:flutter/material.dart';
import '../models/direction.dart';

/// A widget for displaying a single direction step.
/// Supports cooking mode with checkboxes and step number highlighting.
class DirectionStep extends StatelessWidget {
  final Direction direction;
  final bool isChecked;
  final bool showCheckbox;
  final bool isActive;
  final ValueChanged<bool?>? onCheckChanged;
  final VoidCallback? onTap;

  const DirectionStep({
    super.key,
    required this.direction,
    this.isChecked = false,
    this.showCheckbox = false,
    this.isActive = false,
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
        // Step number or checkbox
        if (showCheckbox)
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: isChecked,
              onChanged: onCheckChanged,
              shape: const CircleBorder(),
            ),
          )
        else
          _buildStepNumber(context),
        const SizedBox(width: 12),
        // Direction text
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              direction.text,
              style: textTheme.bodyLarge?.copyWith(
                decoration: isChecked ? TextDecoration.lineThrough : null,
                color: isChecked
                    ? colorScheme.onSurface.withAlpha(128)
                    : colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );

    final container = Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      decoration: isActive
          ? BoxDecoration(
              color: colorScheme.primaryContainer.withAlpha(77),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withAlpha(128),
                width: 1,
              ),
            )
          : null,
      child: content,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: container,
      );
    }

    return container;
  }

  Widget _buildStepNumber(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primary
            : isChecked
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${direction.stepNumber}',
          style: textTheme.labelLarge?.copyWith(
            color: isActive
                ? colorScheme.onPrimary
                : isChecked
                    ? colorScheme.onSurface.withAlpha(128)
                    : colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// A compact direction card for summary views.
class DirectionCard extends StatelessWidget {
  final Direction direction;
  final bool isCompleted;
  final VoidCallback? onTap;

  const DirectionCard({
    super.key,
    required this.direction,
    this.isCompleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isCompleted
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? colorScheme.primary
                      : colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: colorScheme.onPrimary,
                        )
                      : Text(
                          '${direction.stepNumber}',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  direction.text,
                  style: textTheme.bodyMedium?.copyWith(
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted
                        ? colorScheme.onSurface.withAlpha(128)
                        : colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
