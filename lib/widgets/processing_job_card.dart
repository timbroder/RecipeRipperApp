import 'package:flutter/material.dart';
import '../models/processing_job.dart';

/// A card widget for displaying a processing job in progress.
class ProcessingJobCard extends StatelessWidget {
  final ProcessingJob job;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const ProcessingJobCard({
    super.key,
    required this.job,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator at top
            LinearProgressIndicator(
              value: job.progress / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getStatusColor(context),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status icon and title
                    Row(
                      children: [
                        _buildStatusIcon(context),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getTitle(),
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Progress info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            job.currentStep ?? _getStatusText(),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${job.progress.round()}%',
                          style: textTheme.labelMedium?.copyWith(
                            color: _getStatusColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (job.status == ProcessingStatus.failed &&
                        job.errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        job.errorMessage!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color color;

    switch (job.status) {
      case ProcessingStatus.queued:
        icon = Icons.hourglass_empty;
        color = colorScheme.onSurfaceVariant;
      case ProcessingStatus.downloading:
        icon = Icons.cloud_download;
        color = colorScheme.primary;
      case ProcessingStatus.transcribing:
        icon = Icons.mic;
        color = colorScheme.primary;
      case ProcessingStatus.extractingText:
        icon = Icons.document_scanner;
        color = colorScheme.primary;
      case ProcessingStatus.parsing:
        icon = Icons.auto_fix_high;
        color = colorScheme.primary;
      case ProcessingStatus.completed:
        icon = Icons.check_circle;
        color = colorScheme.primary;
      case ProcessingStatus.failed:
        icon = Icons.error;
        color = colorScheme.error;
      case ProcessingStatus.cancelled:
        icon = Icons.cancel;
        color = colorScheme.onSurfaceVariant;
    }

    if (job.isActive) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    return Icon(icon, size: 24, color: color);
  }

  Color _getStatusColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (job.status) {
      case ProcessingStatus.completed:
        return colorScheme.primary;
      case ProcessingStatus.failed:
        return colorScheme.error;
      case ProcessingStatus.queued:
      case ProcessingStatus.cancelled:
        return colorScheme.onSurfaceVariant;
      default:
        return colorScheme.primary;
    }
  }

  String _getTitle() {
    if (job.sourceUrl != null) {
      // Extract video title or URL hostname
      final uri = Uri.tryParse(job.sourceUrl!);
      if (uri != null) {
        return uri.host.isNotEmpty ? 'Video from ${uri.host}' : 'Processing Video';
      }
    }
    return 'Processing Video';
  }

  String _getStatusText() {
    switch (job.status) {
      case ProcessingStatus.queued:
        return 'Waiting to start...';
      case ProcessingStatus.downloading:
        return 'Downloading video...';
      case ProcessingStatus.transcribing:
        return 'Transcribing speech...';
      case ProcessingStatus.extractingText:
        return 'Reading on-screen text...';
      case ProcessingStatus.parsing:
        return 'Parsing recipe...';
      case ProcessingStatus.completed:
        return 'Complete!';
      case ProcessingStatus.failed:
        return 'Failed';
      case ProcessingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// A compact processing indicator for inline display.
class ProcessingIndicator extends StatelessWidget {
  final ProcessingJob job;

  const ProcessingIndicator({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: job.progress / 100,
              valueColor: AlwaysStoppedAnimation<Color>(
                colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${job.progress.round()}%',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
