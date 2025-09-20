import 'package:flutter/material.dart';
import '../utils/data_freshness.dart';

/// Mixin that provides app lifecycle management for StatefulWidgets
/// 
/// This mixin automatically handles app lifecycle events and provides
/// hooks for data refresh when the app resumes. It includes smart
/// refresh logic to avoid unnecessary data reloading.
mixin LifecycleMixin<T extends StatefulWidget> on State<T> {
  bool _isInitialized = false;
  DateTime? _lastResumeTime;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    debugPrint('🔄 LifecycleMixin initialized for ${T.toString()}');
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('🔄 LifecycleMixin disposed for ${T.toString()}');
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (!_isInitialized) return;
    
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }
  
  /// Handle app resume event with smart refresh logic
  void _onAppResumed() {
    final now = DateTime.now();
    final shouldRefresh = _lastResumeTime == null || 
      DataFreshness.shouldRefreshOnResume(_lastResumeTime!);
    
    debugPrint('🔄 App resumed for ${T.toString()}, shouldRefresh: $shouldRefresh');
    
    if (shouldRefresh) {
      debugPrint('🔄 Triggering data refresh for ${T.toString()}');
      onDataRefreshNeeded();
    }
    
    _lastResumeTime = now;
    onAppResumed();
  }
  
  /// Handle app pause event
  void _onAppPaused() {
    debugPrint('⏸️ App paused for ${T.toString()}');
    onAppPaused();
  }
  
  /// Handle app detached event
  void _onAppDetached() {
    debugPrint('🔌 App detached for ${T.toString()}');
    onAppDetached();
  }
  
  /// Handle app inactive event
  void _onAppInactive() {
    debugPrint('😴 App inactive for ${T.toString()}');
    onAppInactive();
  }
  
  /// Handle app hidden event
  void _onAppHidden() {
    debugPrint('👁️ App hidden for ${T.toString()}');
    onAppHidden();
  }
  
  /// Override this method to handle data refresh when app resumes
  /// This method is called when the app resumes and data needs refresh
  void onDataRefreshNeeded() {}
  
  /// Override this method to handle app resume events
  /// This method is called every time the app resumes
  void onAppResumed() {}
  
  /// Override this method to handle app pause events
  void onAppPaused() {}
  
  /// Override this method to handle app detached events
  void onAppDetached() {}
  
  /// Override this method to handle app inactive events
  void onAppInactive() {}
  
  /// Override this method to handle app hidden events
  void onAppHidden() {}
  
  /// Get the last resume time
  DateTime? get lastResumeTime => _lastResumeTime;
  
  /// Check if this is the first resume since initialization
  bool get isFirstResume => _lastResumeTime == null;
}
