import 'package:flutter/material.dart';

/// A reusable error state widget with customizable message and retry action.
class ErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.retryLabel,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// Creates an error state for network errors.
  factory ErrorState.network({VoidCallback? onRetry}) {
    return ErrorState(
      title: 'Connection Error',
      message: 'Please check your internet connection and try again',
      icon: Icons.wifi_off,
      retryLabel: 'Retry',
      onRetry: onRetry,
    );
  }

  /// Creates an error state for loading failures.
  factory ErrorState.loadFailed({String? itemType, VoidCallback? onRetry}) {
    return ErrorState(
      title: 'Failed to Load',
      message: itemType != null
          ? 'We couldn\'t load the $itemType. Please try again.'
          : 'We couldn\'t load this content. Please try again.',
      icon: Icons.cloud_off,
      retryLabel: 'Try Again',
      onRetry: onRetry,
    );
  }

  /// Creates an error state for processing failures.
  factory ErrorState.processingFailed(
      {String? details, VoidCallback? onRetry}) {
    return ErrorState(
      title: 'Processing Failed',
      message: details ?? 'There was an error processing the video',
      icon: Icons.warning_amber_rounded,
      retryLabel: onRetry != null ? 'Try Again' : null,
      onRetry: onRetry,
    );
  }

  /// Creates an error state for permission denied.
  factory ErrorState.permissionDenied(
      {String? permission, VoidCallback? onRetry}) {
    return ErrorState(
      title: 'Permission Required',
      message: permission != null
          ? 'Please grant $permission permission to continue'
          : 'Please grant the required permissions to continue',
      icon: Icons.lock_outline,
      retryLabel: 'Open Settings',
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withAlpha(77),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withAlpha(153),
                ),
              ),
            ],
            if (retryLabel != null && onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact inline error message.
class InlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const InlineError({
    super.key,
    required this.message,
    this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: colorScheme.onErrorContainer,
                size: 20,
              ),
              onPressed: onRetry,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.close,
                color: colorScheme.onErrorContainer,
                size: 20,
              ),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
