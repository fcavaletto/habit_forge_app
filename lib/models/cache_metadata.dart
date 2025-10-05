import 'dart:convert';

/// Metadata for persistent cache to track cache validity and versioning
///
/// This class stores essential information about cached data to enable
/// intelligent cache invalidation, data integrity checks, and migration
/// handling. It provides versioning and freshness tracking capabilities.
///
/// ## Key Features:
/// - **Version Tracking**: Tracks app version when cache was created
/// - **Timestamp Management**: Records when cache was created and last modified
/// - **Data Integrity**: Includes hash for corruption detection
/// - **Size Tracking**: Monitors cache size and habit count
/// - **Migration Support**: Enables smooth cache format migrations
/// - **Date-Aware Caching**: Tracks the date when cache was created for day-change detection
class CacheMetadata {
  /// App version when cache was created
  final String version;
  
  /// When the cache was created
  final DateTime cachedAt;
  
  /// The date when the cache was created (for day-change detection)
  /// This is normalized to the start of the day (00:00:00) to enable
  /// accurate day boundary comparisons
  final DateTime cacheDate;
  
  /// Hash of the cached data for integrity checking
  final String dataHash;
  
  /// Number of habits in the cache
  final int habitCount;
  
  /// When the data was last modified in the database
  final DateTime lastModified;
  
  /// Cache format version for migration support
  final int cacheFormatVersion;

  const CacheMetadata({
    required this.version,
    required this.cachedAt,
    required this.cacheDate,
    required this.dataHash,
    required this.habitCount,
    required this.lastModified,
    this.cacheFormatVersion = 1,
  });

  /// Create CacheMetadata from JSON
  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    // Handle backward compatibility: if cacheDate is missing, use cachedAt as fallback
    DateTime cacheDate;
    if (json.containsKey('cacheDate')) {
      cacheDate = DateTime.parse(json['cacheDate'] as String);
    } else {
      // Fallback to cachedAt for backward compatibility
      final cachedAt = DateTime.parse(json['cachedAt'] as String);
      cacheDate = DateTime(cachedAt.year, cachedAt.month, cachedAt.day);
    }
    
    return CacheMetadata(
      version: json['version'] as String,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      cacheDate: cacheDate,
      dataHash: json['dataHash'] as String,
      habitCount: json['habitCount'] as int,
      lastModified: DateTime.parse(json['lastModified'] as String),
      cacheFormatVersion: json['cacheFormatVersion'] as int? ?? 1,
    );
  }

  /// Convert CacheMetadata to JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'cachedAt': cachedAt.toIso8601String(),
      'cacheDate': cacheDate.toIso8601String(),
      'dataHash': dataHash,
      'habitCount': habitCount,
      'lastModified': lastModified.toIso8601String(),
      'cacheFormatVersion': cacheFormatVersion,
    };
  }

  /// Create CacheMetadata from JSON string
  factory CacheMetadata.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return CacheMetadata.fromJson(json);
  }

  /// Convert CacheMetadata to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Check if cache is expired based on age
  bool get isExpired {
    const maxAge = Duration(hours: 24);
    return DateTime.now().difference(cachedAt) > maxAge;
  }

  /// Check if cache version matches current app version
  bool isVersionMatch(String currentVersion) {
    return version == currentVersion;
  }

  /// Check if cache format is compatible
  bool get isFormatCompatible {
    return cacheFormatVersion == 1; // Current format version
  }

  /// Check if cache data is stale based on last modification
  bool isDataStale(Duration maxStaleness) {
    return DateTime.now().difference(lastModified) > maxStaleness;
  }

  /// Check if cache is from a different day than current date
  /// 
  /// This method compares the cache date with the current date to determine
  /// if the cache was created on a different day. This is used for day-change
  /// detection to ensure fresh data is loaded when a new day starts.
  bool get isFromDifferentDay {
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day);
    final cacheDateNormalized = DateTime(cacheDate.year, cacheDate.month, cacheDate.day);
    return !cacheDateNormalized.isAtSameMomentAs(currentDate);
  }

  /// Create a copy with updated values
  CacheMetadata copyWith({
    String? version,
    DateTime? cachedAt,
    DateTime? cacheDate,
    String? dataHash,
    int? habitCount,
    DateTime? lastModified,
    int? cacheFormatVersion,
  }) {
    return CacheMetadata(
      version: version ?? this.version,
      cachedAt: cachedAt ?? this.cachedAt,
      cacheDate: cacheDate ?? this.cacheDate,
      dataHash: dataHash ?? this.dataHash,
      habitCount: habitCount ?? this.habitCount,
      lastModified: lastModified ?? this.lastModified,
      cacheFormatVersion: cacheFormatVersion ?? this.cacheFormatVersion,
    );
  }

  @override
  String toString() {
    return 'CacheMetadata(version: $version, cachedAt: $cachedAt, '
           'cacheDate: $cacheDate, dataHash: $dataHash, habitCount: $habitCount, '
           'lastModified: $lastModified, cacheFormatVersion: $cacheFormatVersion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CacheMetadata &&
        other.version == version &&
        other.cachedAt == cachedAt &&
        other.cacheDate == cacheDate &&
        other.dataHash == dataHash &&
        other.habitCount == habitCount &&
        other.lastModified == lastModified &&
        other.cacheFormatVersion == cacheFormatVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      version,
      cachedAt,
      cacheDate,
      dataHash,
      habitCount,
      lastModified,
      cacheFormatVersion,
    );
  }
}
