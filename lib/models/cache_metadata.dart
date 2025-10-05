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
class CacheMetadata {
  /// App version when cache was created
  final String version;
  
  /// When the cache was created
  final DateTime cachedAt;
  
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
    required this.dataHash,
    required this.habitCount,
    required this.lastModified,
    this.cacheFormatVersion = 1,
  });

  /// Create CacheMetadata from JSON
  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    return CacheMetadata(
      version: json['version'] as String,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
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

  /// Create a copy with updated values
  CacheMetadata copyWith({
    String? version,
    DateTime? cachedAt,
    String? dataHash,
    int? habitCount,
    DateTime? lastModified,
    int? cacheFormatVersion,
  }) {
    return CacheMetadata(
      version: version ?? this.version,
      cachedAt: cachedAt ?? this.cachedAt,
      dataHash: dataHash ?? this.dataHash,
      habitCount: habitCount ?? this.habitCount,
      lastModified: lastModified ?? this.lastModified,
      cacheFormatVersion: cacheFormatVersion ?? this.cacheFormatVersion,
    );
  }

  @override
  String toString() {
    return 'CacheMetadata(version: $version, cachedAt: $cachedAt, '
           'dataHash: $dataHash, habitCount: $habitCount, '
           'lastModified: $lastModified, cacheFormatVersion: $cacheFormatVersion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CacheMetadata &&
        other.version == version &&
        other.cachedAt == cachedAt &&
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
      dataHash,
      habitCount,
      lastModified,
      cacheFormatVersion,
    );
  }
}
