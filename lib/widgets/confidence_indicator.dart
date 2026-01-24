import 'package:flutter/material.dart';
import '../models/confidence_score.dart';

/// Widget that displays a recipe confidence score with visual indicators
class ConfidenceIndicator extends StatelessWidget {
  final ConfidenceScore confidenceScore;
  final bool showExplanation;
  final bool compact;

  const ConfidenceIndicator({
    super.key,
    required this.confidenceScore,
    this.showExplanation = true,
    this.compact = false,
  });

  /// Get the color for the confidence level
  Color _getColor(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.veryHigh:
        return const Color(0xFF2E7D32); // Dark green
      case ConfidenceLevel.high:
        return const Color(0xFF66BB6A); // Light green
      case ConfidenceLevel.medium:
        return const Color(0xFFFFA726); // Orange
      case ConfidenceLevel.low:
        return const Color(0xFFE53935); // Red
    }
  }

  /// Get the background color for the confidence level
  Color _getBackgroundColor(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.veryHigh:
        return const Color(0xFFE8F5E9); // Light green bg
      case ConfidenceLevel.high:
        return const Color(0xFFF1F8E9); // Lighter green bg
      case ConfidenceLevel.medium:
        return const Color(0xFFFFF3E0); // Light orange bg
      case ConfidenceLevel.low:
        return const Color(0xFFFFEBEE); // Light red bg
    }
  }

  /// Get the icon for the confidence level
  IconData _getIcon(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.veryHigh:
        return Icons.verified;
      case ConfidenceLevel.high:
        return Icons.check_circle;
      case ConfidenceLevel.medium:
        return Icons.info;
      case ConfidenceLevel.low:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final color = _getColor(confidenceScore.level);
    final icon = _getIcon(confidenceScore.level);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          confidenceScore.level.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFull(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final level = confidenceScore.level;
    final color = _getColor(level);
    final bgColor = _getBackgroundColor(level);
    final icon = _getIcon(level);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${level.label} Confidence',
                        style: textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(confidenceScore.overall * 100).round()}% confident in extraction',
                        style: textTheme.bodySmall?.copyWith(
                          color: color.withAlpha(179),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showExplanation && confidenceScore.explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                confidenceScore.explanation,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildProgressBars(context, color),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBars(BuildContext context, Color accentColor) {
    return Column(
      children: [
        _buildProgressRow(
          context,
          'Ingredients',
          confidenceScore.ingredientScore,
          accentColor,
        ),
        const SizedBox(height: 8),
        _buildProgressRow(
          context,
          'Directions',
          confidenceScore.directionScore,
          accentColor,
        ),
        const SizedBox(height: 8),
        _buildProgressRow(
          context,
          'Data Quality',
          confidenceScore.dataQualityScore,
          accentColor,
        ),
      ],
    );
  }

  Widget _buildProgressRow(
    BuildContext context,
    String label,
    double value,
    Color accentColor,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getColorForScore(value),
              ),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 35,
          child: Text(
            '${(value * 100).round()}%',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Color _getColorForScore(double score) {
    if (score >= 0.85) return const Color(0xFF2E7D32);
    if (score >= 0.65) return const Color(0xFF66BB6A);
    if (score >= 0.40) return const Color(0xFFFFA726);
    return const Color(0xFFE53935);
  }
}

/// A small badge showing confidence level (for recipe cards)
class ConfidenceBadge extends StatelessWidget {
  final ConfidenceLevel level;

  const ConfidenceBadge({super.key, required this.level});

  Color _getColor() {
    switch (level) {
      case ConfidenceLevel.veryHigh:
        return const Color(0xFF2E7D32);
      case ConfidenceLevel.high:
        return const Color(0xFF66BB6A);
      case ConfidenceLevel.medium:
        return const Color(0xFFFFA726);
      case ConfidenceLevel.low:
        return const Color(0xFFE53935);
    }
  }

  Color _getBackgroundColor() {
    switch (level) {
      case ConfidenceLevel.veryHigh:
        return const Color(0xFFE8F5E9);
      case ConfidenceLevel.high:
        return const Color(0xFFF1F8E9);
      case ConfidenceLevel.medium:
        return const Color(0xFFFFF3E0);
      case ConfidenceLevel.low:
        return const Color(0xFFFFEBEE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor().withAlpha(77)),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          color: _getColor(),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
