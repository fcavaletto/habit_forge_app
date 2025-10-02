import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal widget for setting custom completion counts for habits with allowExceedGoal flag.
///
/// This widget provides a bottom sheet interface that allows users to:
/// - View the current goal for context
/// - Adjust completion count using +/- buttons or direct input
/// - Validate input (integer only, 0-100 range)
/// - Save or cancel the changes
///
/// The modal follows Material 3 design principles and provides
/// accessibility support for screen readers and keyboard navigation.
class CustomCompletionModal extends StatefulWidget {
  /// The habit name for display context
  final String habitName;
  
  /// The current completion count
  final int currentCount;
  
  /// The target goal for this habit
  final int targetGoal;
  
  /// Callback when the user saves the new completion count
  final void Function(int newCount) onSave;
  
  /// Callback when the user cancels the operation
  final VoidCallback onCancel;

  const CustomCompletionModal({
    super.key,
    required this.habitName,
    required this.currentCount,
    required this.targetGoal,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<CustomCompletionModal> createState() => _CustomCompletionModalState();
}

class _CustomCompletionModalState extends State<CustomCompletionModal> {
  late TextEditingController _textController;
  late int _currentValue;
  String? _errorText;
  
  // Constants for validation
  static const int _minValue = 0;
  static const int _maxValue = 100;

  @override
  void initState() {
    super.initState();
    // Initialize with current count
    _currentValue = widget.currentCount;
    _textController = TextEditingController(text: _currentValue.toString());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Validates the current input value
  void _validateInput() {
    final text = _textController.text.trim();
    
    if (text.isEmpty) {
      setState(() {
        _errorText = 'Please enter a number';
      });
      return;
    }
    
    final value = int.tryParse(text);
    if (value == null) {
      setState(() {
        _errorText = 'Please enter a valid number';
      });
      return;
    }
    
    if (value < _minValue) {
      setState(() {
        _errorText = 'Value must be at least $_minValue';
      });
      return;
    }
    
    if (value > _maxValue) {
      setState(() {
        _errorText = 'Value must be at most $_maxValue';
      });
      return;
    }
    
    setState(() {
      _errorText = null;
      _currentValue = value;
    });
  }

  /// Updates the value and text field
  void _updateValue(int newValue) {
    if (newValue < _minValue || newValue > _maxValue) return;
    
    setState(() {
      _currentValue = newValue;
      _textController.text = newValue.toString();
      _errorText = null;
    });
  }

  /// Handles the save action
  void _handleSave() {
    _validateInput();
    if (_errorText == null) {
      widget.onSave(_currentValue);
      Navigator.of(context).pop();
    }
  }

  /// Handles the cancel action
  void _handleCancel() {
    widget.onCancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with habit name and goal
              _buildHeader(theme),
              const SizedBox(height: 24),
              
              // Input controls
              _buildInputControls(theme),
              const SizedBox(height: 16),
              
              // Error message
              if (_errorText != null) ...[
                _buildErrorMessage(theme),
                const SizedBox(height: 16),
              ],
              
              // Action buttons
              _buildActionButtons(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the header section with habit name and goal
  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set Completion Count',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.habitName} • Goal: ${widget.targetGoal} completions',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Builds the input controls (minus, text field, plus)
  Widget _buildInputControls(ThemeData theme) {
    return Row(
      children: [
        // Minus button
        _buildControlButton(
          icon: Icons.remove,
          onPressed: _currentValue > _minValue 
              ? () => _updateValue(_currentValue - 1) 
              : null,
          theme: theme,
        ),
        const SizedBox(width: 16),
        
        // Text input field
        Expanded(
          child: _buildTextField(theme),
        ),
        const SizedBox(width: 16),
        
        // Plus button
        _buildControlButton(
          icon: Icons.add,
          onPressed: _currentValue < _maxValue 
              ? () => _updateValue(_currentValue + 1) 
              : null,
          theme: theme,
        ),
      ],
    );
  }

  /// Builds a control button (+ or -)
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ThemeData theme,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          icon,
          size: 20,
        ),
      ),
    );
  }

  /// Builds the text input field
  Widget _buildTextField(ThemeData theme) {
    return TextField(
      controller: _textController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3), // Max 3 digits (100)
      ],
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        errorText: _errorText,
        errorStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
      onChanged: (value) {
        // Clear error when user starts typing
        if (_errorText != null) {
          setState(() {
            _errorText = null;
          });
        }
      },
      onSubmitted: (value) {
        _validateInput();
      },
    );
  }

  /// Builds the error message
  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the action buttons (Cancel, Save)
  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        // Cancel button
        Expanded(
          child: OutlinedButton(
            onPressed: _handleCancel,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        
        // Save button
        Expanded(
          child: FilledButton(
            onPressed: _handleSave,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}

/// Shows the custom completion modal as a bottom sheet
///
/// This is a convenience function that wraps the CustomCompletionModal
/// in a showModalBottomSheet call with proper configuration.
Future<void> showCustomCompletionModal({
  required BuildContext context,
  required String habitName,
  required int currentCount,
  required int targetGoal,
  required void Function(int newCount) onSave,
  required VoidCallback onCancel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CustomCompletionModal(
      habitName: habitName,
      currentCount: currentCount,
      targetGoal: targetGoal,
      onSave: onSave,
      onCancel: onCancel,
    ),
  );
}
