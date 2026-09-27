import 'package:flutter/material.dart';

/// Oval outline showing where to place the face.
class FaceGuide extends StatelessWidget {
  const FaceGuide({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _GuidePainter(color)));
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.62;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: w,
      height: w * 1.3,
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(rect);
    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.color != color;
}
