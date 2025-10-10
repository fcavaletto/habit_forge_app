import 'package:flutter/foundation.dart';

/// Interface for caching services
///
/// Provides a consistent interface for different caching implementations
/// (memory cache, persistent cache, etc.)
abstract class ICachingService {
  /// Cache habit metadata
  Future<void> cacheMetadata(List<String> habitIds, Map<String, dynamic> metadata);

  /// Get cached habit metadata
  Future<Map<String, dynamic>?> getCachedMetadata(String habitId);

  /// Invalidate habit metadata cache
  Future<void> invalidateMetadata();
  
  /// Add a single habit to metadata cache (additive - no clear)
  Future<void> addHabitToMetadata(String habitId, Map<String, dynamic> metadata);
  
  /// Update a single habit in metadata cache (selective update)
  Future<void> updateHabitInMetadata(String habitId, Map<String, dynamic> metadata);
  
  /// Remove a single habit from metadata cache (selective remove)
  Future<void> removeHabitFromMetadata(String habitId);

  /// Cache completion data for a habit and date
  Future<void> cacheCompletion(String habitId, DateTime date, int count);

  /// Get cached completion count for a habit and date
  Future<int?> getCachedCompletion(String habitId, DateTime date);

  /// Invalidate completion cache for a habit and date
  Future<void> invalidateCompletion(String habitId, DateTime date);

  /// Invalidate all completion caches
  Future<void> invalidateAllCompletions();
  
  /// Invalidate all caches for a specific habit (metadata + completions)
  Future<void> invalidateHabit(String habitId);

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats();

  /// Clear all cached data
  Future<void> clearAll();
}

/// Memory-based caching implementation
///
/// Fast, in-memory cache with TTL (Time To Live) support
class MemoryCachingService implements ICachingService {
  final Map<String, _CacheEntry> _metadataCache = {};
  final Map<String, Map<DateTime, _CacheEntry>> _completionCache = {};
  static const Duration _defaultTtl = Duration(minutes: 5);

  @override
  Future<void> cacheMetadata(List<String> habitIds, Map<String, dynamic> metadata) async {
    final entry = _CacheEntry(
      data: metadata,
      timestamp: DateTime.now(),
      ttl: _defaultTtl,
    );

    for (final habitId in habitIds) {
      _metadataCache[habitId] = entry;
    }

    debugPrint('📦 Cached metadata for ${habitIds.length} habits');
  }

  @override
  Future<Map<String, dynamic>?> getCachedMetadata(String habitId) async {
    final entry = _metadataCache[habitId];

    if (entry == null) {
      return null;
    }

    if (entry.isExpired) {
      _metadataCache.remove(habitId);
      return null;
    }

    return entry.data;
  }

  @override
  Future<void> invalidateMetadata() async {
    _metadataCache.clear();
    debugPrint('🗑️ Metadata cache invalidated');
  }
  
  @override
  Future<void> addHabitToMetadata(String habitId, Map<String, dynamic> metadata) async {
    final entry = _CacheEntry(
      data: metadata,
      timestamp: DateTime.now(),
      ttl: _defaultTtl,
    );
    
    _metadataCache[habitId] = entry;
    debugPrint('💾 [ADDITIVE] Added habit $habitId to metadata cache');
  }
  
  @override
  Future<void> updateHabitInMetadata(String habitId, Map<String, dynamic> metadata) async {
    final entry = _CacheEntry(
      data: metadata,
      timestamp: DateTime.now(),
      ttl: _defaultTtl,
    );
    
    _metadataCache[habitId] = entry;
    debugPrint('💾 [SELECTIVE] Updated habit $habitId in metadata cache');
  }
  
  @override
  Future<void> removeHabitFromMetadata(String habitId) async {
    _metadataCache.remove(habitId);
    debugPrint('💾 [SELECTIVE] Removed habit $habitId from metadata cache');
  }

  @override
  Future<void> cacheCompletion(String habitId, DateTime date, int count) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    _completionCache[habitId] ??= {};
    _completionCache[habitId]![normalizedDate] = _CacheEntry(
      data: count,
      timestamp: DateTime.now(),
      ttl: _defaultTtl,
    );

    debugPrint('📦 Cached completion for habit $habitId on $normalizedDate');
  }

  @override
  Future<int?> getCachedCompletion(String habitId, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final habitCache = _completionCache[habitId];

    if (habitCache == null) {
      return null;
    }

    final entry = habitCache[normalizedDate];

    if (entry == null) {
      return null;
    }

    if (entry.isExpired) {
      habitCache.remove(normalizedDate);
      return null;
    }

    return entry.data as int?;
  }

  @override
  Future<void> invalidateCompletion(String habitId, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (_completionCache.containsKey(habitId)) {
      _completionCache[habitId]!.remove(normalizedDate);
      debugPrint('🗑️ Completion cache invalidated for habit $habitId on $normalizedDate');
    }
  }

  @override
  Future<void> invalidateAllCompletions() async {
    _completionCache.clear();
    debugPrint('🗑️ All completion caches invalidated');
  }
  
  @override
  Future<void> invalidateHabit(String habitId) async {
    _metadataCache.remove(habitId);
    _completionCache.remove(habitId);
    debugPrint('🗑️ All caches invalidated for habit $habitId');
  }

  @override
  Future<Map<String, dynamic>> getStats() async {
    final totalMetadataEntries = _metadataCache.length;
    final totalCompletionEntries = _completionCache.values
        .fold<int>(0, (sum, habitCache) => sum + habitCache.length);

    final expiredMetadata = _metadataCache.values.where((entry) => entry.isExpired).length;
    final expiredCompletions = _completionCache.values
        .expand((habitCache) => habitCache.values)
        .where((entry) => entry.isExpired)
        .length;

    return {
      'total_metadata_entries': totalMetadataEntries,
      'total_completion_entries': totalCompletionEntries,
      'expired_metadata': expiredMetadata,
      'expired_completions': expiredCompletions,
      'memory_usage_mb': _estimateMemoryUsage(),
    };
  }

  @override
  Future<void> clearAll() async {
    _metadataCache.clear();
    _completionCache.clear();
    debugPrint('🗑️ All caches cleared');
  }

  double _estimateMemoryUsage() {
    // Rough estimation: assume average entry size
    const avgEntrySize = 1024; // 1KB per entry
    final totalEntries = _metadataCache.length + _completionCache.values
        .fold<int>(0, (sum, habitCache) => sum + habitCache.length);

    return (totalEntries * avgEntrySize) / (1024 * 1024); // Convert to MB
  }
}

/// Cache entry with TTL support
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;

  _CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().isAfter(timestamp.add(ttl));

  @override
  String toString() => 'CacheEntry(data: ${data.runtimeType}, expired: $isExpired)';
}

/// Factory for creating caching services
class CachingServiceFactory {
  static ICachingService createMemoryCache() => MemoryCachingService();

  static ICachingService createPersistentCache() {
    // TODO: Implement persistent cache service
    // This would use SharedPreferences or similar for persistence across app restarts
    return MemoryCachingService(); // Fallback for now
  }

  static ICachingService createHybridCache() {
    // TODO: Implement hybrid cache that combines memory and persistent storage
    return MemoryCachingService(); // Fallback for now
  }
}
