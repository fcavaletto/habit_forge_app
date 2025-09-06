import 'package:flutter/material.dart';

/// Error Boundary Widget
///
/// Catches and handles errors that occur in the widget tree below this widget.
/// Provides a user-friendly error message and recovery options.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, FlutterErrorDetails error)? errorBuilder;
  final Function(FlutterErrorDetails error)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _error;

  @override
  void initState() {
    super.initState();
    // Set up error handling for this subtree
    ErrorWidget.builder = (FlutterErrorDetails error) {
      _handleError(error);
      return _buildErrorWidget(error);
    };
  }

  void _handleError(FlutterErrorDetails error) {
    setState(() => _error = error);
    widget.onError?.call(error);

    // Log error for debugging
    debugPrint('Error caught by ErrorBoundary: ${error.exception}');
    debugPrint('Stack trace: ${error.stack}');
  }

  Widget _buildErrorWidget(FlutterErrorDetails error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }

    return Material(
      child: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The app encountered an unexpected error. You can try restarting the app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() => _error = null);
                // Try to rebuild the child
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorWidget(_error!);
    }

    return widget.child;
  }
}

/// Global Error Handler
///
/// Sets up global error handling for the entire app
class GlobalErrorHandler {
  static void setup() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');

      // In production, you might want to send this to a crash reporting service
      // For now, just log it
    };

    // Handle platform errors (Android/iOS)
    // This would require platform-specific implementations
  }
}
