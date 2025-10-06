/// Data freshness utility for determining when data needs to be refreshed
/// 
/// This utility provides methods to check if data is stale and should be
/// refreshed based on various criteria like time elapsed and day changes.
library data_freshness;

import '../services/virtual_date_service.dart';

class DataFreshness {
  /// Default maximum age for data before considering it stale
  static const Duration _defaultMaxAge = Duration(hours: 1);
  
  /// Check if data is stale based on last load time
  /// 
  /// [lastLoadTime] - When the data was last loaded
  /// [maxAge] - Maximum age before data is considered stale (default: 1 hour)
  /// Returns true if data is stale and should be refreshed
  static bool isDataStale(DateTime lastLoadTime, {Duration? maxAge}) {
    final maxAgeDuration = maxAge ?? _defaultMaxAge;
    final timeDifference = VirtualDateService().currentDate.difference(lastLoadTime);
    return timeDifference > maxAgeDuration;
  }
  
  /// Check if a new day has passed since last load
  /// 
  /// [lastLoadTime] - When the data was last loaded
  /// Returns true if a new day has started since last load
  static bool isNewDay(DateTime lastLoadTime) {
    final now = VirtualDateService().currentDate;
    final lastLoad = DateTime(lastLoadTime.year, lastLoadTime.month, lastLoadTime.day);
    final today = DateTime(now.year, now.month, now.day);
    return lastLoad.isBefore(today);
  }
  
  /// Check if data should be refreshed when app resumes
  /// 
  /// [lastLoadTime] - When the data was last loaded
  /// Returns true if data should be refreshed on app resume
  static bool shouldRefreshOnResume(DateTime lastLoadTime) {
    return isDataStale(lastLoadTime) || isNewDay(lastLoadTime);
  }
  
  /// Check if data should be refreshed based on multiple criteria
  /// 
  /// [lastLoadTime] - When the data was last loaded
  /// [maxAge] - Maximum age before data is considered stale
  /// [checkNewDay] - Whether to check for new day (default: true)
  /// Returns true if data should be refreshed
  static bool shouldRefresh({
    required DateTime lastLoadTime,
    Duration? maxAge,
    bool checkNewDay = true,
  }) {
    if (isDataStale(lastLoadTime, maxAge: maxAge)) {
      return true;
    }
    
    if (checkNewDay && isNewDay(lastLoadTime)) {
      return true;
    }
    
    return false;
  }
  
  /// Get time remaining until data becomes stale
  /// 
  /// [lastLoadTime] - When the data was last loaded
  /// [maxAge] - Maximum age before data is considered stale
  /// Returns duration until data becomes stale, or Duration.zero if already stale
  static Duration timeUntilStale(DateTime lastLoadTime, {Duration? maxAge}) {
    final maxAgeDuration = maxAge ?? _defaultMaxAge;
    final timeDifference = VirtualDateService().currentDate.difference(lastLoadTime);
    final remaining = maxAgeDuration - timeDifference;
    return remaining.isNegative ? Duration.zero : remaining;
  }
  
  /// Get human-readable description of data age
  /// 
  /// [lastLoadTime] - When the data was last loaded
  /// Returns a string describing how old the data is
  static String getDataAgeDescription(DateTime lastLoadTime) {
    final now = VirtualDateService().currentDate;
    final difference = now.difference(lastLoadTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
  }
}
