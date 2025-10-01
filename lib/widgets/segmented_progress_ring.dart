import 'package:flutter/material.dart';

/// A custom progress ring widget that displays progress as segmented chunks
/// 
/// This widget divides a circular progress ring into equal segments, where each
/// segment represents one completion toward the goal. This provides clear
/// visual feedback on how many completions are needed.
/// 
/// Features:
/// - Segmented ring for goals ≤ 12 (falls back to smooth ring for higher goals)
/// - Same visual styling as existing CircularProgressIndicator
/// - No animations for instant visual feedback
/// - Uses existing habit colors from theme
/// - Customizable separators between segments
/// - Background ring to hide underlying button color in gaps
class SegmentedProgressRing extends StatelessWidget {
  /// Number of completed segments
  final int completed;
  
  /// Total number of segments (goal)
  final int goal;
  
  /// Color for filled segments
  final Color segmentColor;
  
  /// Color for empty segments
  final Color emptyColor;
  
  /// Color for the background ring (typically card background color)
  final Color? backgroundColor;
  
  /// Thickness of the ring segments
  final double strokeWidth;
  
  /// Size of the entire widget
  final double size;
  
  /// Size of gaps between segments (in degrees)
  /// Set to 0 for no gaps, or a small value like 2-8 degrees
  final double gapSize;
  
  /// Starting angle offset from top (in degrees)
  /// 0 = starts at top, 10 = starts 10° clockwise from top
  final double startAngleOffset;

  const SegmentedProgressRing({
    super.key,
    required this.completed,
    required this.goal,
    required this.segmentColor,
    required this.emptyColor,
    this.backgroundColor,
    this.strokeWidth = 8.0,
    this.size = 48.0,
    this.gapSize = 6.0,
    this.startAngleOffset = 10.0,
  }) : assert(completed >= 0 && completed <= goal),
       assert(goal > 0),
       assert(strokeWidth > 0),
       assert(size > 0),
       assert(gapSize >= 0),
       assert(startAngleOffset >= 0);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SegmentedProgressPainter(
          completed: completed,
          goal: goal,
          segmentColor: segmentColor,
          emptyColor: emptyColor,
          backgroundColor: backgroundColor,
          strokeWidth: strokeWidth,
          gapSize: gapSize,
          startAngleOffset: startAngleOffset,
        ),
      ),
    );
  }
}

/// Custom painter that draws the segmented progress ring
class _SegmentedProgressPainter extends CustomPainter {
  final int completed;
  final int goal;
  final Color segmentColor;
  final Color emptyColor;
  final Color? backgroundColor;
  final double strokeWidth;
  final double gapSize;
  final double startAngleOffset;

  _SegmentedProgressPainter({
    required this.completed,
    required this.goal,
    required this.segmentColor,
    required this.emptyColor,
    this.backgroundColor,
    required this.strokeWidth,
    required this.gapSize,
    required this.startAngleOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Convert angles from degrees to radians
    final gapAngleRad = (gapSize * 3.14159) / 180;
    final startAngleRad = ((startAngleOffset - 90) * 3.14159) / 180; // -90° to start from top
    
    // Calculate total angle needed for all segments and gaps
    final totalGapAngle = goal * gapAngleRad;
    final availableAngle = (2 * 3.14159) - totalGapAngle;
    final segmentAngle = availableAngle / goal;
    
    // Draw background ring first if backgroundColor is provided
    if (backgroundColor != null) {
      final backgroundPaint = Paint()
        ..color = backgroundColor!
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      
      // Draw a complete background ring
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        0,
        2 * 3.14159, // Full circle
        false,
        backgroundPaint,
      );
    }
    
    // Draw each segment individually
    for (int i = 0; i < goal; i++) {
      // Calculate start angle for this segment
      final segmentStartAngle = startAngleRad + (i * (segmentAngle + gapAngleRad));
      
      // Determine if this segment should be filled or empty
      final isFilled = i < completed;
      final color = isFilled ? segmentColor : emptyColor;
      
      // Create paint for this segment with sharp edges
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt; // Sharp edges like cuts
      
      // Draw the arc segment
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segmentStartAngle,
        segmentAngle,
        false, // Don't fill the arc
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SegmentedProgressPainter oldDelegate) {
    return oldDelegate.completed != completed ||
           oldDelegate.goal != goal ||
           oldDelegate.segmentColor != segmentColor ||
           oldDelegate.emptyColor != emptyColor ||
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.gapSize != gapSize ||
           oldDelegate.startAngleOffset != startAngleOffset;
  }
}
