import 'package:flutter/material.dart';

/// Shows a styled error dialog with an optional "Retry" action.
///
/// Does not depend on `permission_handler` — works on all platforms.
Future<void> showErrorDialog(
  BuildContext context,
  String message, {
  VoidCallback? onRetry,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.error_outline_rounded,
        color: Theme.of(context).colorScheme.error,
        size: 40,
      ),
      title: const Text('Something went wrong'),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Dismiss'),
        ),
        if (onRetry != null)
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry();
            },
            child: const Text('Try Again'),
          ),
      ],
    ),
  );
}
