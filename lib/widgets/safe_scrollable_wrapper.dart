import 'package:flutter/material.dart';

/// A wrapper widget that ensures content is properly padded to avoid
/// being hidden behind system navigation bars or other UI elements.
///
/// This widget provides:
/// - Safe area padding to avoid system UI overlap
/// - Consistent bottom padding for scrollable content
/// - Proper handling of keyboard and navigation bar interactions
class SafeScrollableWrapper extends StatelessWidget {
  /// The child widget to wrap
  final Widget child;
  
  /// Whether to add extra bottom padding for better scrolling experience
  final bool addExtraBottomPadding;
  
  /// Custom bottom padding (overrides default if provided)
  final double? bottomPadding;
  
  /// Whether to use SafeArea for all sides (default: true)
  final bool useSafeArea;
  
  /// Whether to maintain bottom view padding (default: true)
  final bool maintainBottomViewPadding;

  const SafeScrollableWrapper({
    super.key,
    required this.child,
    this.addExtraBottomPadding = true,
    this.bottomPadding,
    this.useSafeArea = true,
    this.maintainBottomViewPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    // Get the system bottom padding
    final mediaQuery = MediaQuery.of(context);
    final systemBottomPadding = mediaQuery.padding.bottom;
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    
    // Calculate the total bottom padding needed
    double totalBottomPadding = 0.0;
    
    if (addExtraBottomPadding) {
      // Add system padding plus minimal extra padding
      totalBottomPadding = systemBottomPadding + 4.0;
    } else {
      // Only use system padding when extra padding is disabled
      totalBottomPadding = systemBottomPadding;
    }
    
    // Use custom bottom padding if provided
    if (bottomPadding != null) {
      totalBottomPadding = bottomPadding!;
    }
    
    // If keyboard is open, don't add extra padding
    if (viewInsetsBottom > 0) {
      totalBottomPadding = systemBottomPadding;
    }

    Widget content = child;
    
    // Wrap with SafeArea if requested
    if (useSafeArea) {
      content = SafeArea(
        maintainBottomViewPadding: maintainBottomViewPadding,
        child: content,
      );
    }
    
    // Add bottom padding to ensure content doesn't get hidden
    return Padding(
      padding: EdgeInsets.only(bottom: totalBottomPadding),
      child: content,
    );
  }
}

/// A specialized wrapper for scrollable content that ensures proper
/// bottom padding while maintaining scroll behavior.
class SafeScrollView extends StatelessWidget {
  /// The scrollable content
  final Widget child;
  
  /// Scroll controller for the content
  final ScrollController? controller;
  
  /// Whether to add extra bottom padding
  final bool addExtraBottomPadding;
  
  /// Custom bottom padding
  final double? bottomPadding;
  
  /// Physics for the scroll view
  final ScrollPhysics? physics;

  const SafeScrollView({
    super.key,
    required this.child,
    this.controller,
    this.addExtraBottomPadding = false, // Default to false for scroll views
    this.bottomPadding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return SafeScrollableWrapper(
      addExtraBottomPadding: addExtraBottomPadding,
      bottomPadding: bottomPadding,
      useSafeArea: false, // Disable SafeArea for scroll views
      child: SingleChildScrollView(
        controller: controller,
        physics: physics,
        child: child,
      ),
    );
  }
}

/// A specialized wrapper for CustomScrollView that ensures proper
/// bottom padding while maintaining sliver behavior.
class SafeCustomScrollView extends StatelessWidget {
  /// The slivers to display
  final List<Widget> slivers;
  
  /// Scroll controller for the content
  final ScrollController? controller;
  
  /// Whether to add extra bottom padding
  final bool addExtraBottomPadding;
  
  /// Custom bottom padding
  final double? bottomPadding;
  
  /// Physics for the scroll view
  final ScrollPhysics? physics;

  const SafeCustomScrollView({
    super.key,
    required this.slivers,
    this.controller,
    this.addExtraBottomPadding = false, // Default to false for scroll views
    this.bottomPadding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return SafeScrollableWrapper(
      addExtraBottomPadding: addExtraBottomPadding,
      bottomPadding: bottomPadding,
      useSafeArea: false, // Disable SafeArea for scroll views
      child: CustomScrollView(
        controller: controller,
        physics: physics,
        slivers: slivers,
      ),
    );
  }
}
