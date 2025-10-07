import 'dart:async';
import 'package:flutter/material.dart';

/// A self-contained clock widget that updates every minute
/// 
/// This widget manages its own timer and only rebuilds its own subtree,
/// preventing unnecessary rebuilds of parent widgets. It automatically
/// pauses when time override is active or when the widget is disposed.
class CurrentTimeClock extends StatefulWidget {
  /// Whether time override is currently active
  final bool isTimeOverridden;
  
  /// Text style for the time display
  final TextStyle? style;
  
  /// Format function for the time (defaults to 24-hour format)
  final String Function(TimeOfDay) formatter;

  const CurrentTimeClock({
    super.key,
    required this.isTimeOverridden,
    this.style,
    this.formatter = _defaultFormatter,
  });

  @override
  State<CurrentTimeClock> createState() => _CurrentTimeClockState();

  static String _defaultFormatter(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _CurrentTimeClockState extends State<CurrentTimeClock> {
  Timer? _timer;
  TimeOfDay _currentTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(CurrentTimeClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Restart timer if override state changed
    if (oldWidget.isTimeOverridden != widget.isTimeOverridden) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Start the timer with minute-based updates
  void _startTimer() {
    _timer?.cancel();
    
    // Don't start timer if time is overridden
    if (widget.isTimeOverridden) {
      return;
    }

    // Calculate delay until next minute boundary
    final now = DateTime.now();
    final secondsUntilNextMinute = 60 - now.second;
    final millisecondsUntilNextMinute = secondsUntilNextMinute * 1000 - now.millisecond;
    
    // Start with one-shot timer to align with minute boundary
    Timer(Duration(milliseconds: millisecondsUntilNextMinute), () {
      if (!mounted) return;
      
      // Update time and start periodic timer
      _updateTime();
      _startPeriodicTimer();
    });
  }

  /// Start periodic timer for subsequent minute updates
  void _startPeriodicTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted || widget.isTimeOverridden) {
        timer.cancel();
        return;
      }
      _updateTime();
    });
  }

  /// Restart timer based on current state
  void _restartTimer() {
    _startTimer();
  }

  /// Update the current time and trigger rebuild
  void _updateTime() {
    if (!mounted) return;
    
    final newTime = TimeOfDay.now();
    if (newTime != _currentTime) {
      setState(() {
        _currentTime = newTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.formatter(_currentTime),
      style: widget.style,
    );
  }
}
