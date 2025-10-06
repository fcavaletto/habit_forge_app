import 'package:flutter/material.dart';

/// Custom progress dialog for tracking sample data import progress
class ImportProgressDialog extends StatefulWidget {
  final bool clearExisting;
  final Future<int> Function(Function(String, double) onProgress) importFunction;

  const ImportProgressDialog({
    super.key,
    required this.clearExisting,
    required this.importFunction,
  });

  @override
  State<ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<ImportProgressDialog> {
  final Map<String, double> _progressData = {
    'Learn Spanish': 0.0,
    'Journal Writing': 0.0,
    'Read Pages': 0.0,
  };

  bool _isCompleted = false;
  int _importedCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    try {
      final importedCount = await widget.importFunction((habitName, progress) {
        if (mounted) {
          setState(() {
            _progressData[habitName] = progress;
          });
        }
      });

      if (mounted) {
        setState(() {
          _isCompleted = true;
          _importedCount = importedCount;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.clearExisting 
          ? 'Replacing All Habits'
          : 'Adding Sample Habits',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Import Failed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else if (_isCompleted) ...[
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Import Successful!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.clearExisting
                ? 'Successfully replaced all habits with $_importedCount sample habits containing 2 years of data.'
                : 'Successfully added $_importedCount sample habits with 2 years of data.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              widget.clearExisting 
                ? 'Generating 3 sample habits with 2 years of data...'
                : 'Adding 3 sample habits with 2 years of data...',
            ),
            const SizedBox(height: 24),
            
            // Progress bars for each habit
            ..._progressData.entries.map((entry) {
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '${(entry.value * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: entry.value,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ],
        ],
      ),
      actions: [
        if (_isCompleted || _error != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
      ],
    );
  }
}
