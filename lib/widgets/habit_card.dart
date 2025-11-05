import 'package:flutter/material.dart';
import 'package:habit_forge_app/utils/color_extensions.dart';
import '../models/habit.dart';
import '../utils/icon_utils.dart';
import '../screens/stats_screen.dart';
import '../services/virtual_date_service.dart';
import '../services/haptic_feedback_service.dart';
import '../utils/week_utils.dart';
import '../repositories/settings_repository.dart';
import '../services/database_service.dart';
import 'segmented_progress_ring.dart';
import 'outlined_icon.dart';

/// Smart completion button that adapts its appearance and behavior
/// based on the habit's goal and current completion state.
///
/// This button provides a unified interface for habit completion that:
/// - Shows different icons based on completion state (add/check)
/// - Displays progress rings for multi-completion habits (goal > 1)
/// - Handles incremental completion and reset functionality
/// - Provides comprehensive accessibility support
/// - Adapts colors and transparency based on completion state
///
/// The button automatically determines its state and behavior:
/// - **Empty**: No completions today - shows add icon, calls onIncrement
/// - **In Progress**: Some completions but goal not met - shows add icon, calls onIncrement
/// - **Completed**: Goal achieved - shows check icon, calls onDecrement (reset)
class SmartCompletionButton extends StatefulWidget {
  // Constants for button dimensions and styling
  static const double _buttonSize = 50.0;
  static const double _completedIconSize = 24.0;
  static const double _defaultIconSize = 24.0;
  static const double _emptyAlpha = 0.1;
  static const double _completedAlpha = 1.0;

  // Progress ring constants
  static const double _progressRingSize = 48.0;
  static const double _progressStrokeWidth = 8.0;
  static const double _progressStartAngleOffset = 15.0;
  static const double _segmentAlpha = 1;
  static const double _emptySegmentAlpha = 0.4;
  static const int _maxSegmentedGoal = 12;

  // Dynamic gap size formula constants
  static const double _baseGapSize = 9.2;
  static const double _gapSizeReductionFactor = 0.6;

  /// The habit this button represents
  final Habit habit;

  /// Callback when completion count should be incremented
  final VoidCallback? onIncrement;

  /// Callback when completion count should be decremented (reset)
  final VoidCallback? onDecrement;

  /// Callback when custom completion modal should be opened (for allowExceedGoal habits)
  final VoidCallback? onCustomCompletion;

  const SmartCompletionButton({
    super.key,
    required this.habit,
    this.onIncrement,
    this.onDecrement,
    this.onCustomCompletion,
  });

  @override
  State<SmartCompletionButton> createState() => _SmartCompletionButtonState();
}

class _SmartCompletionButtonState extends State<SmartCompletionButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _burstController;
  late Animation<double> _burstScaleAnimation;
  late Animation<double> _burstOpacityAnimation;
  bool _wasCompleted = false;
  bool _isBursting = false;
  bool _wasTappedByUser = false; // New flag to track user tap

  // Store completed state for overlay
  int? _burstOverlayCount;
  Color? _burstOverlayColor;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Create three-phase animation
    _pulseAnimation = TweenSequence<double>([
      // Phase 1: Grow to 1.1x
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      // Phase 2: Hold at 1.1x
      TweenSequenceItem(tween: ConstantTween<double>(1.08), weight: 10.0),
      // Phase 3: Shrink to 1.0x
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40.0,
      ),
    ]).animate(_pulseController);

    // New burst animation
    _burstController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _burstScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _burstController, curve: Curves.easeOut));

    _burstOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0,
    ).animate(CurvedAnimation(parent: _burstController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  /// Get the habit color based on current theme brightness
  Color _getHabitColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? Color(widget.habit.lightColorValue)
        : Color(widget.habit.darkColorValue);
  }

  /// Builds the button container with the specified parameters
  Widget _buildButtonContainer({
    required Color habitColor,
    required ButtonState buttonState,
    required int todayCount,
    required bool isCompleted,
    required BuildContext context,
  }) {
    return Container(
      width: SmartCompletionButton._buttonSize,
      height: SmartCompletionButton._buttonSize,
      decoration: BoxDecoration(
        shape: (isCompleted || widget.habit.targetGoal == 1)
            ? BoxShape.rectangle
            : BoxShape.circle,
        borderRadius: (isCompleted || widget.habit.targetGoal == 1)
            ? BorderRadius.circular(8.0)
            : null,
        color: _getButtonColor(habitColor, buttonState),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.habit.targetGoal > 1 &&
              buttonState != ButtonState.completed) ...[
            SizedBox.expand(
              child: _buildProgressIndicator(todayCount, habitColor, context),
            ),
          ],
          (() {
            final iconData = _getButtonIcon(buttonState);
            final iconSize = _getIconSize(buttonState);
            final isLight = Theme.of(context).brightness == Brightness.light;
            if (iconData == Icons.check && isCompleted) {
              return OutlinedIcon(
                iconData,
                size: iconSize,
                fillColor: Colors.white,
              );
            }
            return Icon(
              iconData,
              color: isLight
                  ? isCompleted
                      ? Colors.white
                      : habitColor.darken(0.1)
                  : Colors.white.withValues(alpha: 0.8),
              size: iconSize,
            );
          })(),
        ],
      ),
    );
  }

  /// Builds the normal button with pulse animation (current behavior)
  Widget _buildNormalButton(
    BuildContext context,
    Color habitColor,
    int todayCount,
    bool isCompleted,
    ButtonState buttonState,
  ) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _pulseAnimation.value, child: child);
      },
      child: _buildButtonContainer(
        habitColor: habitColor,
        buttonState: buttonState,
        todayCount: todayCount,
        isCompleted: isCompleted,
        context: context,
      ),
    );
  }

  /// Builds the incomplete button + bursting completed overlay
  Widget _buildBurstingWithOverlay(
    BuildContext context,
    Color habitColor,
    int todayCount,
    bool isCompleted,
    ButtonState buttonState,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Incomplete button (current actual state)
        _buildButtonContainer(
          habitColor: habitColor,
          buttonState: buttonState,
          todayCount: todayCount,
          isCompleted: isCompleted,
          context: context,
        ),

        // 2. Bursting completed button overlay (stored state)
        if (_burstOverlayColor != null && _burstOverlayCount != null)
          AnimatedBuilder(
            animation: Listenable.merge([
              _burstScaleAnimation,
              _burstOpacityAnimation,
            ]),
            builder: (context, child) {
              return Opacity(
                opacity: _burstOpacityAnimation.value,
                child: Transform.scale(
                  scale: _burstScaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: _buildButtonContainer(
              habitColor: _burstOverlayColor!,
              buttonState: ButtonState.completed,
              todayCount: _burstOverlayCount!,
              isCompleted: true,
              context: context,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current completion state
    final todayCount = widget.habit.getCompletionCount(
      VirtualDateService().currentDate,
    );
    final isCompleted = widget.habit.isGoalAchieved(
      VirtualDateService().currentDate,
    );
    final habitColor = _getHabitColor(context);

    // Determine button state based on completion
    final buttonState = _getButtonState(todayCount, isCompleted);

    // Trigger pulse animation when goal is reached (only if not bursting and user tapped)
    if (isCompleted && !_wasCompleted && _wasTappedByUser) {
      _pulseController.forward(from: 0.0);
      _wasCompleted = true;
      // Reset the tap flag after triggering
      setState(() {
        _wasTappedByUser = false;
      });
    } else if (!isCompleted) {
      _wasCompleted = false;
    }

    // Disable interaction for preview mode (when all callbacks are null)
    final isPreview =
        widget.onIncrement == null &&
        widget.onDecrement == null &&
        widget.onCustomCompletion == null;

    return Semantics(
      label: _getAccessibilityLabel(todayCount, isCompleted),
      hint: _getAccessibilityHint(todayCount, isCompleted),
      button: !isPreview, // Disable button semantics in preview
      child: isPreview
          ? IgnorePointer(
              child: _isBursting
                  ? _buildBurstingWithOverlay(
                      context,
                      habitColor,
                      todayCount,
                      isCompleted,
                      buttonState,
                    )
                  : _buildNormalButton(
                      context,
                      habitColor,
                      todayCount,
                      isCompleted,
                      buttonState,
                    ),
            )
          : GestureDetector(
              onTap: () => _handleButtonPress(),
              child: _isBursting
                  ? _buildBurstingWithOverlay(
                      context,
                      habitColor,
                      todayCount,
                      isCompleted,
                      buttonState,
                    )
                  : _buildNormalButton(
                      context,
                      habitColor,
                      todayCount,
                      isCompleted,
                      buttonState,
                    ),
            ),
    );
  }

  /// Determines the current button state based on completion count and goal achievement.
  ///
  /// Returns:
  /// - [ButtonState.empty] when no completions today
  /// - [ButtonState.completed] when goal is fully achieved
  /// - [ButtonState.inProgress] when partially completed
  ButtonState _getButtonState(int todayCount, bool isCompleted) {
    if (todayCount == 0) return ButtonState.empty;
    if (isCompleted) return ButtonState.completed;
    return ButtonState.inProgress;
  }

  /// Returns the button background color with appropriate transparency.
  ///
  /// Completed buttons are fully opaque, while empty/in-progress buttons
  /// are semi-transparent to indicate they're interactive.
  /// For habits with goal = 1, use lighter hue when not completed, full color when completed.
  Color _getButtonColor(Color habitColor, ButtonState state) {
    // Special case: when goal is 1, use lighter hue if not completed, full color if completed
    if (widget.habit.targetGoal == 1) {
      final alpha = (state == ButtonState.completed)
          ? SmartCompletionButton._completedAlpha
          : SmartCompletionButton._emptyAlpha;
      return habitColor.withValues(alpha: alpha);
    }

    // Original logic for goals > 1
    final alpha =
        (state == ButtonState.empty || state == ButtonState.inProgress)
        ? SmartCompletionButton._emptyAlpha
        : SmartCompletionButton._completedAlpha;
    return habitColor.withValues(alpha: alpha);
  }

  /// Returns the appropriate icon for the current button state.
  ///
  /// - For habits with goal = 1: Always shows check icon (tick)
  /// - For habits with goal > 1:
  ///   - Empty/In Progress: Add icon (Icons.add)
  ///   - Completed: Check icon (Icons.check)
  IconData _getButtonIcon(ButtonState state) {
    // Special case: when goal is 1, always show check icon (tick)
    if (widget.habit.targetGoal == 1) {
      return Icons.check;
    }

    // Original logic for goals > 1
    switch (state) {
      case ButtonState.empty:
      case ButtonState.inProgress:
        return Icons.add;
      case ButtonState.completed:
        return Icons.check;
    }
  }

  /// Returns the appropriate icon size for the current button state.
  ///
  /// Completed buttons use a larger icon to emphasize the achievement.
  double _getIconSize(ButtonState state) {
    return state == ButtonState.completed
        ? SmartCompletionButton._completedIconSize
        : SmartCompletionButton._defaultIconSize;
  }

  /// Generates an accessibility label describing the current completion state.
  ///
  /// Provides screen readers with context about:
  /// - The habit name
  /// - Current completion count vs goal
  /// - Available action (add, reset, or custom completion)
  String _getAccessibilityLabel(int todayCount, bool isCompleted) {
    if (widget.habit.allowExceedGoal) {
      return '${widget.habit.name}: $todayCount completions - tap to set custom count';
    }

    if (todayCount == 0) {
      return 'Add first completion for ${widget.habit.name}';
    }
    if (isCompleted) {
      return 'Completed ${widget.habit.name} - tap to reset';
    }
    return '${widget.habit.name}: $todayCount of ${widget.habit.targetGoal} completions - tap to add';
  }

  /// Generates an accessibility hint explaining what will happen when tapped.
  ///
  /// Provides additional context for screen readers about the button's action.
  String _getAccessibilityHint(int todayCount, bool isCompleted) {
    if (widget.habit.allowExceedGoal) {
      return 'Tap to open custom completion dialog';
    }

    if (todayCount == 0) {
      return 'Tap to add your first completion today';
    }
    if (isCompleted) {
      return 'Tap to remove all completions and start over';
    }
    return 'Tap to add another completion';
  }

  /// Handles button press based on current state
  ///
  /// Behavior:
  /// - Empty state: Calls [onIncrement] to mark first completion
  /// - Completed state: Calls [onDecrement] to reset (burst animation)
  /// - In progress state: Calls [onIncrement] to add another completion
  ///
  /// Reads fresh state from widget.habit to avoid stale state issues.
  void _handleButtonPress() {
    // Read fresh state from widget.habit to avoid stale parameters
    // This ensures we always have the latest completion state
    final today = VirtualDateService().currentDate;
    final todayCount = widget.habit.getCompletionCount(today);
    final isCompleted = widget.habit.isGoalAchieved(today);

    setState(() {
      _wasTappedByUser = true; // Set flag on user tap
    });

    if (widget.habit.allowExceedGoal) {
      HapticFeedbackService.selection();
      widget.onCustomCompletion?.call();
    } else {
      if (todayCount == 0) {
        HapticFeedbackService.selection();
        widget.onIncrement?.call();
      } else if (isCompleted) {
        // Store completed state for overlay
        final habitColor = _getHabitColor(context);

        setState(() {
          _burstOverlayCount = todayCount;
          _burstOverlayColor = habitColor;
          _isBursting = true;
        });

        // Immediately change the data state
        HapticFeedbackService.selection();
        widget.onDecrement?.call();

        // Start burst overlay animation
        _burstController.forward(from: 0.0).then((_) {
          setState(() {
            _isBursting = false;
            _burstOverlayCount = null;
            _burstOverlayColor = null;
          });
          _burstController.reset();
        });
      } else {
        final willReachGoal = (todayCount + 1) >= widget.habit.targetGoal;
        if (willReachGoal) {
          HapticFeedbackService.heavy();
        } else {
          HapticFeedbackService.selection(); // Intensified
        }
        widget.onIncrement?.call();
      }
    }

    // Reset the tap flag after processing
    // Use addPostFrameCallback to ensure it resets after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _wasTappedByUser = false;
        });
      }
    });
  }

  /// Calculates the dynamic gap size based on the habit's goal.
  ///
  /// Uses the formula: GapSize = 9.2 - 0.6 * HabitGoal
  /// This ensures that:
  /// - Habits with smaller goals have larger gaps (more visual separation)
  /// - Habits with larger goals have smaller gaps (more segments visible)
  /// - The gap size scales appropriately with the number of segments
  double _calculateDynamicGapSize() {
    return SmartCompletionButton._baseGapSize -
        (SmartCompletionButton._gapSizeReductionFactor *
            widget.habit.targetGoal);
  }

  /// Builds the appropriate progress indicator based on goal size.
  ///
  /// For goals ≤ 12: Uses [SegmentedProgressRing] with individual segments
  /// For goals > 12: Uses [CircularProgressIndicator] for smooth progress
  ///
  /// The segmented ring provides clear visual feedback for smaller goals,
  /// while the smooth indicator is more appropriate for larger goals where
  /// individual segments would be too small to be meaningful.
  Widget _buildProgressIndicator(
    int todayCount,
    Color habitColor,
    BuildContext context,
  ) {
    // Clamp completed count to goal for display purposes
    // This handles cases where:
    // 1. Goal is reduced in edit mode and completion count exceeds new goal
    // 2. allowExceedGoal is true but SegmentedProgressRing can only display up to goal
    // Even if allowExceedGoal is true, we clamp for visual display since the ring can't show more than goal
    final displayCount = todayCount.clamp(0, widget.habit.targetGoal);

    // Ensure targetGoal is valid to prevent invalid SegmentedProgressRing
    final validGoal = widget.habit.targetGoal > 0 ? widget.habit.targetGoal : 1;

    if (validGoal <= SmartCompletionButton._maxSegmentedGoal) {
      return SegmentedProgressRing(
        completed: displayCount,
        goal: validGoal,
        segmentColor: habitColor.withValues(
          alpha: SmartCompletionButton._segmentAlpha,
        ),
        emptyColor: habitColor.withValues(
          alpha: SmartCompletionButton._emptySegmentAlpha,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        strokeWidth: SmartCompletionButton._progressStrokeWidth,
        size: SmartCompletionButton._progressRingSize,
        gapSize: _calculateDynamicGapSize(),
        startAngleOffset: SmartCompletionButton._progressStartAngleOffset,
      );
    } else {
      // Fall back to smooth circular progress indicator for higher goals
      // Ensure targetGoal is valid to prevent division by zero or invalid calculations
      final validGoal = widget.habit.targetGoal > 0
          ? widget.habit.targetGoal
          : 1;

      // Calculate progress value - clamp completed count to goal for display
      // CircularProgressIndicator expects 0.0-1.0, but we calculate from displayCount
      // which is already clamped to goal
      final progressValue = (displayCount / validGoal).clamp(0.0, 1.0);

      return CircularProgressIndicator(
        value: progressValue, // Already clamped to 0.0-1.0
        strokeWidth: 4,
        valueColor: AlwaysStoppedAnimation(habitColor.withValues(alpha: 0.8)),
        backgroundColor: habitColor.withValues(alpha: 0.2),
      );
    }
  }
}

/// Represents the different states of the completion button.
///
/// These states determine the button's appearance, behavior, and accessibility labels.
enum ButtonState {
  /// No completions today - shows add icon, semi-transparent background
  empty,

  /// Some completions but goal not achieved - shows add icon, semi-transparent background
  inProgress,

  /// Goal fully achieved - shows check icon, fully opaque background
  completed,
}

/// Interactive card widget displaying a habit with progress visualization
///
/// This is the primary UI component for displaying habits in the main dashboard.
/// Each card shows the habit's name, description, progress grid,
/// and provides interactive controls for completion and detailed viewing.
///
/// Key Features:
/// - Material 3 card design with theme-aware styling
/// - 7-day progress grid showing recent completion status
/// - Quick completion toggle button
/// - Tap-to-view detailed habit information
/// - Responsive design for various screen sizes
///
/// The card uses the habit's assigned color from the theme palette
/// and provides visual feedback for all user interactions.
class HabitCard extends StatefulWidget {
  /// The habit data to display in this card
  final Habit habit;

  /// Callback when the card is tapped (typically opens detailed view)
  final VoidCallback? onTap;

  /// Optional long-press callback (e.g., open reorder mode)
  final VoidCallback? onLongPress;

  /// Callback when the completion button is pressed
  final VoidCallback? onComplete;

  /// Callback when completion count should be incremented
  final VoidCallback? onIncrement;

  /// Callback when completion count should be decremented
  final VoidCallback? onDecrement;

  /// Callback when custom completion modal should be opened (for allowExceedGoal habits)
  final VoidCallback? onCustomCompletion;

  /// Callback for settings/accessibility actions (currently unused)
  final VoidCallback? onSettings;

  /// Callback when the habit should be archived
  final VoidCallback? onArchive;

  /// Callback when the habit should be deleted
  final VoidCallback? onDelete;

  /// Callback when the habit should be edited
  final VoidCallback? onEdit;

  /// Callback when stats should be viewed
  final VoidCallback? onStats;

  /// Whether to show the collapse/expand button
  /// When false (default), collapse button is shown and state is persisted
  /// When true, card is always collapsed and button is hidden (for preview/edit mode)
  final bool hideCollapseButton;

  /// Whether the week starts on Monday (true) or Sunday (false)
  final bool weekStartsOnMonday;

  /// The current date to use for week calculations
  final DateTime currentDate;

  /// Optional callback to open Reorder screen from context menu
  final VoidCallback? onReorder;

  const HabitCard({
    super.key,
    required this.habit,
    this.onTap,
    this.onLongPress,
    this.onComplete,
    this.onIncrement,
    this.onDecrement,
    this.onCustomCompletion,
    this.onSettings,
    this.onArchive,
    this.onDelete,
    this.onEdit,
    this.onStats,
    this.hideCollapseButton = false,
    required this.weekStartsOnMonday,
    required this.currentDate,
    this.onReorder,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  bool _isCollapsed = true; // Default to collapsed
  bool _isCollapseStateLoaded = false;
  late SettingsRepository _settingsRepository;
  
  // Memoization for weeks data to avoid recalculating on every rebuild
  List<List<DateTime>>? _cachedWeeksData;
  bool? _cachedWeekStartsOnMonday;
  DateTime? _cachedCurrentDate;
  Habit? _cachedHabitReference;

  @override
  void initState() {
    super.initState();
    // If collapse button is hidden (preview/edit mode), always collapsed
    if (widget.hideCollapseButton) {
      _isCollapsed = true;
      _isCollapseStateLoaded = true;
    } else {
      _settingsRepository = SettingsRepository(DatabaseService());
      _loadCollapseState();
    }
  }

  Future<void> _loadCollapseState() async {
    // Don't load state if button is hidden
    if (widget.hideCollapseButton) return;

    try {
      final isCollapsed = await _settingsRepository.getHabitCardCollapsed(
        widget.habit.id,
      );
      if (mounted) {
        setState(() {
          _isCollapsed = isCollapsed;
          _isCollapseStateLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading collapse state: $e');
      if (mounted) {
        setState(() {
          _isCollapsed = true; // Default to collapsed on error
          _isCollapseStateLoaded = true;
        });
      }
    }
  }

  Future<void> _toggleCollapse() async {
    // Don't allow toggling if button is hidden
    if (widget.hideCollapseButton) return;

    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    try {
      await _settingsRepository.saveHabitCardCollapsed(
        widget.habit.id,
        _isCollapsed,
      );
    } catch (e) {
      debugPrint('❌ Error saving collapse state: $e');
    }
  }

  /// Get the habit color based on current theme brightness
  Color _getHabitColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? Color(widget.habit.lightColorValue)
        : Color(widget.habit.darkColorValue);
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors and habit-specific color
    final colorScheme = Theme.of(context).colorScheme;
    final habitColor = _getHabitColor(context);

    // Create accessibility labels - memoized for performance
    final todayCount = widget.habit.getCompletionCount(
      VirtualDateService().currentDate,
    );
    final completionStatus = todayCount > 0
        ? '$todayCount completion${todayCount != 1 ? 's' : ''}'
        : 'not completed';
    final accessibilityLabel =
        '${widget.habit.name}. ${widget.habit.description}. Today: $completionStatus.';

    // Theme-based border width
    final borderWidth = Theme.of(context).brightness == Brightness.light
        ? 1.0 // Light theme: more prominent borders
        : 0.5; // Dark theme: subtle borders

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.outline.withValues(alpha: 0.5),
            colorScheme.outline.withValues(alpha: 1), // Darker bottom
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth), // Theme-based border width
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Semantics(
          label: accessibilityLabel,
          hint: 'Tap for options, long press to drag and reorder',
          button: true,
          child: InkWell(
            // Short tap shows context menu, long press handled by ReorderableListView
            // Only make tappable if callback is provided (for preview mode)
            onTap: widget.onTap != null
                ? () => _showContextMenu(context)
                : null,
            onLongPress: widget.onLongPress,
            // Rounded corners for modern Material 3 design
            borderRadius: BorderRadius.circular(11.0),
            focusColor: habitColor.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Icon and action buttons
                  Row(
                    children: [
                      // Habit icon with themed background
                      Semantics(
                        label: 'Habit icon',
                        excludeSemantics: true,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: habitColor.withValues(alpha: 0),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: habitColor, width: 1),
                          ),
                          child: Icon(
                            widget.habit.iconName.toIconData,
                            color: habitColor,
                            size: 25,
                          ),
                        ),
                      ),

                      const Spacer(), // Push buttons to the right
                      // Action buttons row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Stats button
                          Semantics(
                            label: 'View ${widget.habit.name} statistics',
                            hint: 'Opens detailed statistics for this habit',
                            button:
                                widget.onStats !=
                                null, // Disable semantics in preview
                            child: InkWell(
                              // Disable interaction in preview mode
                              onTap: widget.onStats != null
                                  ? (widget.onStats ??
                                        () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => StatsScreen(
                                                habit: widget.habit,
                                              ),
                                            ),
                                          );
                                        })
                                  : null,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.bar_chart,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Smart completion button
                          SmartCompletionButton(
                            habit: widget.habit,
                            onIncrement: widget.onIncrement,
                            onDecrement: widget.onDecrement,
                            onCustomCompletion: widget.onCustomCompletion,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Habit details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Habit text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Habit name
                            Text(
                              widget.habit.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // Only show description and spacing if description is not empty
                            if (widget.habit.description.isNotEmpty) ...[
                              const SizedBox(height: 2),

                              // Habit description
                              Text(
                                widget.habit.description,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 4-week progress grid with day labels and collapse functionality
                  Builder(
                    builder: (context) {
                      // Memoize weeks data - only recalculate if parameters changed
                      if (_cachedWeeksData == null ||
                          _cachedWeekStartsOnMonday != widget.weekStartsOnMonday ||
                          _cachedCurrentDate != widget.currentDate ||
                          _cachedHabitReference != widget.habit) {
                        _cachedWeeksData = WeekUtils.getWeeksData(
                          widget.currentDate,
                          widget.weekStartsOnMonday,
                          numberOfWeeks: 4,
                        );
                        _cachedWeekStartsOnMonday = widget.weekStartsOnMonday;
                        _cachedCurrentDate = widget.currentDate;
                        _cachedHabitReference = widget.habit;
                      }
                      
                      final weeksData = _cachedWeeksData!;
                      final dayLabels = WeekUtils.getDayLabels(
                        widget.weekStartsOnMonday,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Day labels row
                          Row(
                            children: dayLabels.map((label) {
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    label,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 4),
                          // 4-week grid
                          Column(
                            children: List.generate(_isCollapsed ? 1 : 4, (
                              weekIndex,
                            ) {
                              final weekDates = weeksData[weekIndex];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: weekIndex < (_isCollapsed ? 0 : 4)
                                      ? 4
                                      : 0,
                                ),
                                child: Row(
                                  children: List.generate(7, (dayIndex) {
                                    final date = weekDates[dayIndex];
                                    final count = widget.habit
                                        .getCompletionCount(date);
                                    // Use goal at completion for that date, not current goal
                                    // This ensures "Keep Past" option preserves original color intensity
                                    final goalAtCompletion = widget.habit
                                        .getGoalAtCompletion(date);
                                    final intensity = count > 0
                                        ? (count / goalAtCompletion).clamp(
                                            0.0,
                                            1.0,
                                          )
                                        : 0.0;

                                    return Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1.5,
                                        ),
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: count > 0
                                              ? habitColor.withValues(
                                                  alpha: intensity,
                                                )
                                              : habitColor.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            0,
                                          ),
                                        ),
                                        // Display completion status in progress grid boxes
                                        // Visual hierarchy:
                                        // 1. Goal achieved: Show checkmark icon (size: 10) in white
                                        // 2. Partially completed: Show completion count number (fontSize: 8)
                                        // 3. Not completed: Show empty box with low opacity
                                        child: widget.habit.isGoalAchieved(date)
                                            ? Center(
                                                child: OutlinedIcon(
                                                  Icons.check,
                                                  size: 10, // Completion mark size for achieved goals
                                                  fillColor: Colors.white,
                                                ),
                                              )
                                            : count > 0
                                            ? Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    count.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 8, // Completion count text size
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                    );
                                  }),
                                ),
                              );
                            }),
                          ),
                          // Collapse/expand button (hidden in preview/edit mode)
                          if (_isCollapseStateLoaded &&
                              !widget.hideCollapseButton)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Center(
                                child: InkWell(
                                  onTap: _toggleCollapse,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 0,
                                    ),
                                    child: Icon(
                                      _isCollapsed
                                          ? Icons.keyboard_arrow_down
                                          : Icons.keyboard_arrow_up,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show context menu for habit management actions
  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getHabitColor(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.habit.iconName.toIconData,
                        color: _getHabitColor(context),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.habit.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (widget.habit.description.isNotEmpty)
                            Text(
                              widget.habit.description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Menu items
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Habit'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onEdit?.call();
                },
              ),
              
              // Insert Reorder option after Edit and before Archive
              ListTile(
                leading: const Icon(Icons.swap_vert),
                title: const Text('Reorder Habits'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onReorder?.call();
                },
              ),
              
              ListTile(
                leading: const Icon(Icons.archive),
                title: const Text('Archive Habit'),
                subtitle: const Text('Hide from main view'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onArchive?.call();
                },
              ),
              
              ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete Habit',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text('Permanently remove'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onDelete?.call();
                },
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
