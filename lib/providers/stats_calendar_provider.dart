import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../services/data_access_service.dart';
import '../services/atomic_data_service.dart';
import '../utils/performance_monitor.dart';

/// Load status for a single month's data
class MonthLoadState {
  final String status; // 'idle' | 'loading' | 'ready' | 'error'
  final Map<DateTime, CompletionRecord> data;
  final String? errorMessage;

  const MonthLoadState._(this.status, this.data, this.errorMessage);

  factory MonthLoadState.idle() => const MonthLoadState._('idle', {}, null);
  factory MonthLoadState.loading() => const MonthLoadState._('loading', {}, null);
  factory MonthLoadState.ready(Map<DateTime, CompletionRecord> data) => MonthLoadState._('ready', data, null);
  factory MonthLoadState.error(String message) => MonthLoadState._('error', const {}, message);

  bool get isReady => status == 'ready';
  bool get isLoading => status == 'loading';
}

/// Controller that manages background prefetching of month data for a habit.
///
/// It keeps a sliding window of months around the visible month loaded and cached
/// for snappy calendar navigation.
class StatsCalendarController extends ChangeNotifier {
  final DataAccessService _dataAccessService;

  // Current habit in focus
  String _habitId;

  // Cache keyed by first-of-month DateTime (local)
  final Map<DateTime, MonthLoadState> _monthCache = {};

  // In-flight dedupe: keys are "habitId|yyyy-mm"
  final Set<String> _inFlight = {};

  // Simple queue for month loads to cap concurrency
  final List<DateTime> _loadQueue = [];
  int _activeLoads = 0;
  final int _maxConcurrency;

  // Debounce for rapid month changes
  Timer? _debounce;
  final Duration _debounceDuration;

  // Feature flag (can be externalized later)
  static const bool _enabled = true;

  StatsCalendarController({
    required DataAccessService dataAccessService,
    required String habitId,
    int maxConcurrency = 2,
    Duration debounceDuration = const Duration(milliseconds: 150),
  })  : _dataAccessService = dataAccessService,
        _habitId = habitId,
        _maxConcurrency = maxConcurrency,
        _debounceDuration = debounceDuration;

  // Public API ----------------------------------------------------------------

  void updateHabit(String habitId) {
    if (_habitId == habitId) return;
    _habitId = habitId;
    _monthCache.clear();
    _inFlight.clear();
    _loadQueue.clear();
    _activeLoads = 0;
    notifyListeners();
  }

  MonthLoadState? getMonthState(DateTime monthKey) => _monthCache[monthKey];

  Map<DateTime, CompletionRecord> mergeWithMonthData(Map<DateTime, CompletionRecord> base) {
    if (_monthCache.isEmpty) return base;
    final merged = Map<DateTime, CompletionRecord>.from(base);
    for (final entry in _monthCache.entries) {
      if (!entry.value.isReady) continue;
      merged.addAll(entry.value.data);
    }
    return merged;
  }

  Future<void> ensureMonthLoaded({required DateTime month}) async {
    if (!_enabled) return;
    final monthKey = _firstOfMonth(month);
    final flightKey = _flightKey(_habitId, monthKey);

    final current = _monthCache[monthKey];
    if (current?.isReady == true || current?.isLoading == true) return;
    if (_inFlight.contains(flightKey)) return;

    _monthCache[monthKey] = MonthLoadState.loading();
    notifyListeners();

    _inFlight.add(flightKey);
    _loadQueue.add(monthKey);
    _pumpQueue();
  }

  void prefetchAroundMonth({required DateTime center, int radius = 2}) {
    if (!_enabled) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      final targets = <DateTime>[];
      for (int i = -radius; i <= radius; i++) {
        final m = DateTime(center.year, center.month + i, 1);
        targets.add(_firstOfMonth(m));
      }
      for (final m in targets) {
        unawaited(ensureMonthLoaded(month: m));
      }
    });
  }

  // Internal ------------------------------------------------------------------

  void _pumpQueue() {
    while (_activeLoads < _maxConcurrency && _loadQueue.isNotEmpty) {
      final monthKey = _loadQueue.removeAt(0);
      _activeLoads += 1;
      _loadMonth(monthKey).whenComplete(() {
        _activeLoads -= 1;
        _pumpQueue();
      });
    }
  }

  Future<void> _loadMonth(DateTime monthKey) async {
    final flightKey = _flightKey(_habitId, monthKey);
    try {
      final range = _monthRange(monthKey);
      final result = await PerformanceMonitor.monitorOperation(
        'prefetchMonth($_habitId, ${_fmtMonth(monthKey)})',
        () async {
          return await _dataAccessService.atomicDataService.getCompletions(
            startDate: range.$1,
            endDate: range.$2,
            habitIds: [_habitId],
            context: DataAccessContext(
              component: 'StatsCalendarController',
              operation: 'prefetch',
              parameters: {
                'habitId': _habitId,
                'month': _fmtMonth(monthKey),
              },
            ),
          );
        },
      );

      if (result.success && result.data != null) {
        final data = result.data![_habitId] ?? <DateTime, CompletionRecord>{};
        _monthCache[monthKey] = MonthLoadState.ready(data);
      } else {
        _monthCache[monthKey] = MonthLoadState.error(result.errorMessage ?? 'Unknown error');
      }
    } catch (e) {
      _monthCache[monthKey] = MonthLoadState.error('$e');
    } finally {
      _inFlight.remove(flightKey);
      notifyListeners();
    }
  }

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static (DateTime, DateTime) _monthRange(DateTime firstOfMonth) {
    final start = DateTime(firstOfMonth.year, firstOfMonth.month, 1);
    final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0);
    final end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59, 999);
    return (start, end);
  }

  static String _flightKey(String habitId, DateTime monthKey) => '$habitId|${_fmtMonth(monthKey)}';
  static String _fmtMonth(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}


