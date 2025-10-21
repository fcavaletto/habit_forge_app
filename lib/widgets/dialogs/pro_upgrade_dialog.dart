import 'package:flutter/material.dart';

/// Reusable dialog for PRO subscription upgrade prompts
///
/// This dialog can be used throughout the app to gate premium features
/// behind the PRO subscription. It provides a consistent UI for upgrade
/// prompts with customizable title and message.
class ProUpgradeDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onUpgrade;
  
  const ProUpgradeDialog({
    super.key,
    this.title = 'PRO Feature',
    required this.message,
    this.onUpgrade,
  });
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.workspace_premium, 
               color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onUpgrade?.call();
          },
          child: const Text('Upgrade to Pro'),
        ),
      ],
    );
  }
}
