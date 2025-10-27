import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../utils/icon_utils.dart';
import '../widgets/safe_scrollable_wrapper.dart';
import '../widgets/stats/completion_chart.dart';
import '../widgets/stats/streak_display.dart';
import '../widgets/stats/last_7_days_overview.dart';
import '../widgets/stats/monthly_calendar.dart';
import '../widgets/stats/hourly_histogram.dart';
import '../widgets/stats/active_days_widget.dart';
import '../utils/constants.dart';
import '../providers/app_state_provider.dart';
import '../services/virtual_date_service.dart';
import '../services/atomic_data_service.dart';
import '../providers/stats_calendar_provider.dart';

/// Stats Screen - Displays analytics and charts for habit tracking
///
/// Shows comprehensive statistics including:
/// - Completion streaks with motivational messages
/// - 30-day completion rate chart with interactive tooltips
/// - Weekly overview with visual completion indicators
/// - Monthly calendar with horizontal scrolling navigation
/// - Today highlighting and completion status visualization
class StatsScreen extends StatefulWidget {
  final Habit habit;
  final Map<DateTime, CompletionRecord>? last30DaysCompletions;

  const StatsScreen({
    super.key,
    required this.habit,
    this.last30DaysCompletions,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _selectedTimeRange = 'Last 30 Days';
  String _selectedCompletionTimeRange = AppConstants.defaultCompletionTimeRange;
  HourlyHistogramData? _hourlyData;
  bool _isLoadingHourlyData = false;
  String? _hourlyDataError;
  
  // Load full habit data from database for stats
  Habit? _fullHabitData;
  bool _isLoadingFullData = false;
  
  // Background loading for extended data ranges
  Map<DateTime, CompletionRecord>? _last365DaysCompletions;
  HourlyHistogramData? _totalHourlyData;
  bool _isLoading365Days = false;
  bool _isLoadingTotalHourly = false;

  // Sliding prefetch controller
  StatsCalendarController? _calendarController;
  Timer? _calendarUpdateDebounce;
  void _onCalendarDataUpdated() {
    if (!mounted) return;
    _calendarUpdateDebounce?.cancel();
    _calendarUpdateDebounce = Timer(AppConstants.quickAnimation, () {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    
    // Only load fresh data if we don't have cached last 30 days data
    if (widget.last30DaysCompletions?.isEmpty != false) {
      _loadLast30DaysData(); // Fast initial load
    }
    
    _loadHourlyData();
    
    // Start background loading for extended data ranges
    _startBackgroundLoading();

    // Initialize sliding prefetch after first frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      _calendarController = StatsCalendarController(
        dataAccessService: appState.habitProvider.dataAccessService,
        habitId: widget.habit.id,
      );
      _calendarController!.addListener(_onCalendarDataUpdated);
      final currentMonth = DateTime(VirtualDateService().currentDate.year, VirtualDateService().currentDate.month, 1);
      _calendarController!.prefetchAroundMonth(center: currentMonth, radius: 2);
      _calendarController!.ensureMonthLoaded(month: currentMonth);
    });
  }

  @override
  void didUpdateWidget(StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.habit.id != widget.habit.id) {
      // Only load fresh data if we don't have cached last 30 days data
      if (widget.last30DaysCompletions?.isEmpty != false) {
        _loadLast30DaysData(); // Fast initial load
      }
      _loadHourlyData();

      // Update prefetch controller to new habit
      final appState = Provider.of<AppState>(context, listen: false);
      _calendarController ??= StatsCalendarController(
        dataAccessService: appState.habitProvider.dataAccessService,
        habitId: widget.habit.id,
      );
      // Ensure listener is attached in case controller was just created
      _calendarController!.removeListener(_onCalendarDataUpdated);
      _calendarController!.addListener(_onCalendarDataUpdated);
      _calendarController!.updateHabit(widget.habit.id);
      final currentMonth = DateTime(VirtualDateService().currentDate.year, VirtualDateService().currentDate.month, 1);
      _calendarController!.prefetchAroundMonth(center: currentMonth, radius: 2);
      _calendarController!.ensureMonthLoaded(month: currentMonth);
    }
  }

  @override
  void dispose() {
    // Clean up cached data when leaving stats screen
    _last365DaysCompletions = null;
    _totalHourlyData = null;
    debugPrint('🗑️ Stats screen disposed - cached data cleared');
    _calendarController?.removeListener(_onCalendarDataUpdated);
    _calendarController?.dispose();
    super.dispose();
  }

  /// Load last 30 days of data for fast initial rendering
  /// 
  /// This method is now only called when cached data is not available.
  /// In most cases, the dashboard will have already loaded this data.
  Future<void> _loadLast30DaysData() async {
    if (!mounted) return;
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final today = VirtualDateService().currentDate;
      final last30Days = today.subtract(const Duration(days: 30));
      
      // Get habit metadata first
      final metadataResult = await appState.habitProvider.dataAccessService.atomicDataService.getHabitMetadata(
        habitIds: [widget.habit.id],
        context: DataAccessContext(
          component: 'StatsScreen',
          operation: 'loadLast30DaysMetadata',
          parameters: {'habitId': widget.habit.id},
        ),
      );
      
      if (metadataResult.success && metadataResult.data != null && metadataResult.data!.isNotEmpty) {
        final metadata = metadataResult.data!.first;
        
        // Get completion data for last 30 days
        final completionResult = await appState.habitProvider.dataAccessService.atomicDataService.getCompletions(
          startDate: last30Days,
          endDate: today,
          habitIds: [widget.habit.id],
          context: DataAccessContext(
            component: 'StatsScreen',
            operation: 'loadLast30DaysCompletions',
            parameters: {'habitId': widget.habit.id},
          ),
        );
        
        if (completionResult.success && completionResult.data != null) {
          final completions = completionResult.data![widget.habit.id] ?? {};
          
          // Create habit with metadata and completion data
          final habit = Habit(
            id: metadata.id,
            name: metadata.name,
            description: metadata.description,
            lightColorValue: metadata.lightColorValue,
            darkColorValue: metadata.darkColorValue,
            createdAt: metadata.createdAt,
            completions: completions,
            iconName: metadata.iconName,
            reminderTime: metadata.reminderTime,
            enableReminders: metadata.enableReminders,
            isArchived: metadata.isArchived,
            orderValue: metadata.orderValue,
            frequencyDays: metadata.frequencyDays,
            targetGoal: metadata.targetGoal,
            allowExceedGoal: metadata.allowExceedGoal,
          );
          
          if (mounted) {
            setState(() {
              _fullHabitData = habit;
            });
          }
          
          // Start background loading of full data
          _loadFullDataInBackground();
        }
      } else {
        if (mounted) {
          setState(() {
            _fullHabitData = widget.habit; // Fallback to original habit
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fullHabitData = widget.habit; // Fallback to original habit
        });
      }
    }
  }

  /// Load full historical data in background for "Total" range
  Future<void> _loadFullDataInBackground() async {
    if (_isLoadingFullData) return; // Prevent multiple simultaneous loads
    
    _isLoadingFullData = true;
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      
      // Get habit metadata first
      final metadataResult = await appState.habitProvider.dataAccessService.atomicDataService.getHabitMetadata(
        habitIds: [widget.habit.id],
        context: DataAccessContext(
          component: 'StatsScreen',
          operation: 'loadFullDataMetadata',
          parameters: {'habitId': widget.habit.id},
        ),
      );
      
      if (metadataResult.success && metadataResult.data != null && metadataResult.data!.isNotEmpty) {
        final metadata = metadataResult.data!.first;
        
        // Get full completion data
        final completionResult = await appState.habitProvider.dataAccessService.atomicDataService.getCompletions(
          startDate: DateTime(2020), // Full history
          endDate: VirtualDateService().currentDate,
          habitIds: [widget.habit.id],
          context: DataAccessContext(
            component: 'StatsScreen',
            operation: 'loadFullDataCompletions',
            parameters: {'habitId': widget.habit.id},
          ),
        );
        
        if (completionResult.success && completionResult.data != null && mounted) {
          final completions = completionResult.data![widget.habit.id] ?? {};
          
          // Create habit with metadata and completion data
          final habit = Habit(
            id: metadata.id,
            name: metadata.name,
            description: metadata.description,
            lightColorValue: metadata.lightColorValue,
            darkColorValue: metadata.darkColorValue,
            createdAt: metadata.createdAt,
            completions: completions,
            iconName: metadata.iconName,
            reminderTime: metadata.reminderTime,
            enableReminders: metadata.enableReminders,
            isArchived: metadata.isArchived,
            orderValue: metadata.orderValue,
            frequencyDays: metadata.frequencyDays,
            targetGoal: metadata.targetGoal,
            allowExceedGoal: metadata.allowExceedGoal,
          );
          
          setState(() {
            _fullHabitData = habit;
          });
          debugPrint('✅ Stats screen: Full historical data loaded in background');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Stats screen: Background full data loading failed: $e');
    } finally {
      _isLoadingFullData = false;
    }
  }

  Future<void> _loadHourlyData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingHourlyData = true;
      _hourlyDataError = null;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final currentDate = VirtualDateService().currentDate;
      
      final data = await appState.habitProvider.loadHourlyData(
        widget.habit.id,
        _selectedTimeRange,
        currentDate,
      );
      
      if (mounted) {
        setState(() {
          _hourlyData = data;
          _isLoadingHourlyData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hourlyDataError = e.toString();
          _isLoadingHourlyData = false;
        });
      }
    }
  }

  /// Start background loading for extended data ranges
  /// 
  /// Loads 365 days completion data and total hourly data in background
  /// so they're ready when user selects those options.
  void _startBackgroundLoading() {
    _loadLast365DaysInBackground();
    _loadTotalHourlyInBackground();
  }

  /// Load last 365 days completion data in background
  Future<void> _loadLast365DaysInBackground() async {
    if (_isLoading365Days || _last365DaysCompletions != null) return;
    
    _isLoading365Days = true;
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final today = VirtualDateService().currentDate;
      final last365Days = today.subtract(const Duration(days: 364));
      
      // Get completion data for last 365 days
      final completionResult = await appState.habitProvider.dataAccessService.atomicDataService.getCompletions(
        startDate: last365Days,
        endDate: today,
        habitIds: [widget.habit.id],
        context: DataAccessContext(
          component: 'StatsScreen',
          operation: 'loadLast365DaysCompletions',
          parameters: {'habitId': widget.habit.id},
        ),
      );
      
      if (completionResult.success && completionResult.data != null && mounted) {
        final completions = completionResult.data![widget.habit.id] ?? {};
        setState(() {
          _last365DaysCompletions = completions;
        });
        debugPrint('✅ Background loaded 365 days completion data');
      }
    } catch (e) {
      debugPrint('❌ Background loading 365 days failed: $e');
    } finally {
      _isLoading365Days = false;
    }
  }

  /// Load total hourly data in background
  Future<void> _loadTotalHourlyInBackground() async {
    if (_isLoadingTotalHourly || _totalHourlyData != null) return;
    
    _isLoadingTotalHourly = true;
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final currentDate = VirtualDateService().currentDate;
      
      final data = await appState.habitProvider.loadHourlyData(
        widget.habit.id,
        'Total',
        currentDate,
      );
      
      if (mounted) {
        setState(() {
          _totalHourlyData = data;
        });
        debugPrint('✅ Background loaded total hourly data');
      }
    } catch (e) {
      debugPrint('❌ Background loading total hourly failed: $e');
    } finally {
      _isLoadingTotalHourly = false;
    }
  }

  void _onTimeRangeChanged(String newRange) {
    if (newRange != _selectedTimeRange) {
      setState(() {
        _selectedTimeRange = newRange;
      });
      
      // If switching to "Total" and we don't have full data yet, load it
      if (newRange == 'Total' && _isLoadingFullData == false) {
        _loadFullDataInBackground();
      }
      
      _loadHourlyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use full habit data if available, otherwise fallback to widget habit
    final habitToUse = _fullHabitData ?? widget.habit;
    
    // Use cached last 30 days data if available, otherwise fallback to habit completions
    final completions = widget.last30DaysCompletions?.isNotEmpty == true
        ? widget.last30DaysCompletions!
        : habitToUse.completions;
    
    return Consumer<AppState>(
        builder: (context, appState, child) {
          final currentDate = VirtualDateService().currentDate;
        
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
          body: SafeScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Habit Header (now includes Active Days)
                  _buildHabitHeader(context, habitToUse),
                    const SizedBox(height: 24),

                    // Current Streak
                  Builder(
                    builder: (context) {
                      final longestStreakData = _calculateLongestStreakWithRange(completions, habitToUse.frequencyDays, appState.isActiveDaysStreakEnabled);
                      return StreakDisplay(
                        currentStreak: _calculateCurrentStreak(completions, currentDate, habitToUse.frequencyDays, appState.isActiveDaysStreakEnabled),
                        longestStreak: longestStreakData['streak'] as int,
                        streakCalculationMode: appState.streakCalculationMode,
                        longestStreakStartDate: longestStreakData['startDate'] as DateTime?,
                        longestStreakEndDate: longestStreakData['endDate'] as DateTime?,
                      );
                    },
                    ),
                    const SizedBox(height: 24),

                    // Completion Rate Chart
                  CompletionChart(
                    completionData: _getCompletionDataForRange(
                      _selectedCompletionTimeRange,
                      completions,
                      currentDate,
                    ),
                    currentDate: currentDate,
                    timeRange: _selectedCompletionTimeRange,
                    onTimeRangeChanged: (newRange) {
                      setState(() {
                        _selectedCompletionTimeRange = newRange;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // PRO Features Section (Last 7 Days onward)
                  _buildProFeaturesSection(context, appState, completions, currentDate),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the PRO features section with dimmed overlay when PRO is inactive
  Widget _buildProFeaturesSection(BuildContext context, AppState appState, Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final isProActive = appState.isProSubscriptionActive;
    
    return Stack(
      children: [
        // Content
        Column(
          children: [
            // Last 7 Days Overview
            Last7DaysOverview(
              weeklyData: _getLast7DaysData(completions, currentDate),
              currentDate: currentDate,
              completions: completions,
              habitId: widget.habit.id,
              dataAccessService: appState.habitProvider.dataAccessService,
            ),
                    const SizedBox(height: 24),

            // Hourly Completion Histogram
            _buildHourlyHistogram(),
                    const SizedBox(height: 24),

                    // Monthly Calendar
            MonthlyCalendar(
              completions: _calendarController?.mergeWithMonthData(completions) ?? completions,
              currentDate: currentDate,
              habitId: widget.habit.id,
              dataAccessService: appState.habitProvider.dataAccessService,
              onVisibleMonthChanged: (visibleMonth) {
                _calendarController?.ensureMonthLoaded(month: visibleMonth);
                _calendarController?.prefetchAroundMonth(center: visibleMonth, radius: 2);
              },
            ),
          ],
        ),
        
        // Dimmed overlay when PRO is inactive
        if (!isProActive)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // PRO badge in top-right corner
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PRO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Positioned message (higher up)
                  Positioned(
                    top: 80,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Advanced Analytics',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upgrade to PRO to access detailed statistics,\ncompletion patterns, and insights',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              // Navigate to settings to enable PRO
                              Navigator.of(context).pushNamed('/settings');
                            },
                            icon: const Icon(Icons.upgrade),
                            label: const Text('Upgrade to PRO'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Get the habit color based on current theme brightness
  Color _getHabitColor(BuildContext context, Habit habit) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light 
        ? Color(habit.lightColorValue) 
        : Color(habit.darkColorValue);
  }

  /// Builds the habit header card with icon and basic information
  Widget _buildHabitHeader(BuildContext context, Habit habit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          children: [
            Container(
              width: AppConstants.iconSizeLarge,
              height: AppConstants.iconSizeLarge,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
              ),
              child: Icon(
                habit.iconName.toIconData,
                color: _getHabitColor(context, habit),
                size: 36.0,
              ),
            ),
            const SizedBox(width: AppConstants.defaultPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (habit.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      habit.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: 'Goal: ',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: '${habit.targetGoal}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active Days:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ActiveDaysWidget(
                    frequencyDays: habit.frequencyDays,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculates completion rate data points for the last 7 days
  ///
  /// Returns a list of double values representing daily completion rates.
  /// Each value represents the completion percentage for that day (0.0 to 1.0).
  List<double> _getLast7DaysCompletionData(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final data = <double>[];

    for (int i = 6; i >= 0; i--) {
      final date = currentDate.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      // Find completion record for this date (handle both date-only and full DateTime keys)
      CompletionRecord? record;
      for (final entry in completions.entries) {
        final entryDate = entry.key;
        if (entryDate.year == dateOnly.year && 
            entryDate.month == dateOnly.month && 
            entryDate.day == dateOnly.day) {
          record = entry.value;
          break;
        }
      }
      
      final rate = record != null 
          ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0)
          : 0.0;
      data.add(rate);
    }

    return data;
  }

  /// Calculates completion rate data points for the last 30 days
  ///
  /// Returns a list of double values representing daily completion rates.
  /// Each value represents the completion percentage for that day (0.0 to 1.0).
  List<double> _getLast30DaysCompletionData(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final data = <double>[];

    for (int i = 29; i >= 0; i--) {
      final date = currentDate.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      // Find completion record for this date (handle both date-only and full DateTime keys)
      CompletionRecord? record;
      for (final entry in completions.entries) {
        final entryDate = entry.key;
        if (entryDate.year == dateOnly.year && 
            entryDate.month == dateOnly.month && 
            entryDate.day == dateOnly.day) {
          record = entry.value;
          break;
        }
      }
      
      final rate = record != null 
          ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0)
          : 0.0;
      data.add(rate);
    }

    return data;
  }

  /// Calculates completion rate data points for the last 365 days
  ///
  /// Returns a list of double values representing daily completion rates.
  /// Each value represents the completion percentage for that day (0.0 to 1.0).
  /// Missing days are set to 0.0.
  List<double> _getLast365DaysCompletionData(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final data = <double>[];

    for (int i = 364; i >= 0; i--) {
      final date = currentDate.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      // Find completion record for this date (handle both date-only and full DateTime keys)
      CompletionRecord? record;
      for (final entry in completions.entries) {
        final entryDate = entry.key;
        if (entryDate.year == dateOnly.year && 
            entryDate.month == dateOnly.month && 
            entryDate.day == dateOnly.day) {
          record = entry.value;
          break;
        }
      }
      
      final rate = record != null 
          ? (record.count / record.goalAtCompletion).clamp(0.0, 1.0)
          : 0.0;
      data.add(rate);
    }

    return data;
  }

  /// Gets completion data for the selected time range
  ///
  /// Returns completion rate data based on the currently selected time range.
  /// Uses background-loaded data when available for better performance.
  List<double> _getCompletionDataForRange(
    String timeRange,
    Map<DateTime, CompletionRecord> completions,
    DateTime currentDate,
  ) {
    switch (timeRange) {
      case 'Last 7 Days':
        return _getLast7DaysCompletionData(completions, currentDate);
      case 'Last 30 Days':
        return _getLast30DaysCompletionData(completions, currentDate);
      case 'Last 365 Days':
        // Use background-loaded 365 days data if available, otherwise fallback to current completions
        final dataToUse = _last365DaysCompletions ?? completions;
        return _getLast365DaysCompletionData(dataToUse, currentDate);
      default:
        return _getLast30DaysCompletionData(completions, currentDate);
    }
  }

  /// Calculates last 7 days completion data
  ///
  /// Returns a list of CompletionRecord objects representing completion status
  /// for each of the last 7 days (including today).
  List<CompletionRecord?> _getLast7DaysData(Map<DateTime, CompletionRecord> completions, DateTime currentDate) {
    final data = <CompletionRecord?>[];

    for (int i = 6; i >= 0; i--) {
      final date = currentDate.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      // Find completion record for this date (handle both date-only and full DateTime keys)
      CompletionRecord? record;
      for (final entry in completions.entries) {
        final entryDate = entry.key;
        if (entryDate.year == dateOnly.year && 
            entryDate.month == dateOnly.month && 
            entryDate.day == dateOnly.day) {
          record = entry.value;
          break;
        }
      }
      
      data.add(record);
    }

    return data;
  }

  /// Calculates the current streak of consecutive goal-achieved days
  ///
  /// Supports two calculation modes:
  /// - All Days: Count consecutive days regardless of active days
  /// - Active Days Only: Count consecutive active days only
  ///
  /// A streak continues as long as the habit achieves its goal each day.
  /// The streak breaks when a day's goal is not met, but can resume the next day.
  int _calculateCurrentStreak(Map<DateTime, CompletionRecord> completions, DateTime currentDate, Map<String, int> frequencyDays, bool isActiveDaysOnly) {
    int streak = 0;
    DateTime checkDate = currentDate;

    // Edge case: No active days in active days mode
    if (isActiveDaysOnly && !_hasActiveDays(frequencyDays)) {
      return 0;
    }

    // Count consecutive goal-achieved days backward from current date
    while (true) {
      final dayKey = DateTime(checkDate.year, checkDate.month, checkDate.day);
      final weekday = _getWeekdayKey(checkDate.weekday);
      
      // Check if this day is active (only relevant for active days mode)
      final isActiveDay = frequencyDays[weekday] == 1;
      
      if (isActiveDaysOnly && !isActiveDay) {
        // Skip inactive days in active days mode
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }
      
      final record = _findCompletionRecord(completions, dayKey);
      
      if (record != null && record.isGoalAchieved) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (checkDate.year == currentDate.year && 
                 checkDate.month == currentDate.month && 
                 checkDate.day == currentDate.day) {
        // Don't break streak for today if goal not achieved yet
        break;
      } else {
        break;
      }
    }

    return streak;
  }


  /// Calculates the longest streak with its date range
  ///
  /// Returns a map containing both the streak count and the date range.
  /// Used for displaying detailed information in tooltips.
  Map<String, dynamic> _calculateLongestStreakWithRange(Map<DateTime, CompletionRecord> completions, Map<String, int> frequencyDays, bool isActiveDaysOnly) {
    int longestStreak = 0;
    int currentStreak = 0;
    DateTime? longestStreakStart;
    DateTime? longestStreakEnd;
    DateTime? currentStreakStart;

    // Edge case: No active days in active days mode
    if (isActiveDaysOnly && !_hasActiveDays(frequencyDays)) {
      return {
        'streak': 0,
        'startDate': null,
        'endDate': null,
      };
    }

    // Get the date range to check (from earliest completion to latest)
    if (completions.isEmpty) {
      return {
        'streak': 0,
        'startDate': null,
        'endDate': null,
      };
    }

    final dates = completions.keys.toList()..sort();
    final startDate = dates.first;
    final endDate = dates.last;

    // Check consecutive days from start to end
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate.add(const Duration(days: 1)))) {
      final weekday = _getWeekdayKey(currentDate.weekday);
      final isActiveDay = frequencyDays[weekday] == 1;
      
      // Skip inactive days in active days mode
      if (isActiveDaysOnly && !isActiveDay) {
        currentStreak = 0; // Reset streak when encountering inactive day
        currentStreakStart = null;
        currentDate = currentDate.add(const Duration(days: 1));
        continue;
      }
      
      final record = _findCompletionRecord(completions, currentDate);
      if (record != null && record.isGoalAchieved) {
        if (currentStreak == 0) {
          currentStreakStart = currentDate; // Start of new streak
        }
        currentStreak++;
        
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
          longestStreakStart = currentStreakStart;
          longestStreakEnd = currentDate;
        }
      } else {
        currentStreak = 0;
        currentStreakStart = null;
      }
      
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return {
      'streak': longestStreak,
      'startDate': longestStreakStart,
      'endDate': longestStreakEnd,
    };
  }

  /// Helper method to check if habit has any active days
  bool _hasActiveDays(Map<String, int> frequencyDays) {
    return frequencyDays.values.any((value) => value == 1);
  }

  /// Helper method to get weekday key from DateTime weekday
  String _getWeekdayKey(int weekday) {
    const weekdays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    return weekdays[weekday % 7];
  }

  /// Builds loading state for histogram
  Widget _buildHistogramLoadingState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Text(
              'Completions throughout the day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds error state for histogram
  Widget _buildHistogramErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Text(
              'Completions throughout the day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load data',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _loadHourlyData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds empty state for histogram
  Widget _buildHistogramEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          children: [
            Text(
              'Completions throughout the day',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No completion data available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete your habit to see hourly patterns',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build hourly histogram with smart data selection
  /// 
  /// Uses background-loaded total data when user selects "Total" range,
  /// otherwise uses the regular hourly data.
  Widget _buildHourlyHistogram() {
    // Use background-loaded total data if user selected "Total" and data is available
    if (_selectedTimeRange == 'Total' && _totalHourlyData != null) {
      return HourlyHistogram(
        data: _totalHourlyData!,
        onTimeRangeChanged: _onTimeRangeChanged,
      );
    }
    // Use regular hourly data if available
    else if (_hourlyData != null) {
      return HourlyHistogram(
        data: _hourlyData!,
        onTimeRangeChanged: _onTimeRangeChanged,
      );
    }
    // Show loading state if currently loading
    else if (_isLoadingHourlyData) {
      return _buildHistogramLoadingState();
    }
    // Show error state if there was an error
    else if (_hourlyDataError != null) {
      return _buildHistogramErrorState();
    }
    // Show empty state if no data
    else {
      return _buildHistogramEmptyState();
    }
  }

  /// Find completion record for a specific date
  /// Handles both date-only and full DateTime keys in the completions map
  CompletionRecord? _findCompletionRecord(Map<DateTime, CompletionRecord> completions, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    // First try direct lookup (for date-only keys)
    final directRecord = completions[dateOnly];
    if (directRecord != null) {
      return directRecord;
    }
    
    // If not found, search for any completion on this date (handles full DateTime keys)
    for (final entry in completions.entries) {
      final entryDate = entry.key;
      if (entryDate.year == dateOnly.year && 
          entryDate.month == dateOnly.month && 
          entryDate.day == dateOnly.day) {
        return entry.value;
      }
    }
    
    return null;
  }

}