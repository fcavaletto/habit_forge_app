import 'package:flutter/widgets.dart';

class OutlinedIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color fillColor;
  final Color outlineColor;
  final double outlineFraction; // Fraction of size used as outline width

  const OutlinedIcon(
    this.icon, {
    super.key,
    required this.size,
    this.fillColor = const Color(0xFFFFFFFF),
    this.outlineColor = const Color(0xFF000000),
    this.outlineFraction = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    final String glyph = String.fromCharCode(icon.codePoint);
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          glyph,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (size * outlineFraction)
              ..strokeJoin = StrokeJoin.round
              ..color = outlineColor,
          ),
        ),
        Text(
          glyph,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: fillColor,
          ),
        ),
      ],
    );
  }
}


