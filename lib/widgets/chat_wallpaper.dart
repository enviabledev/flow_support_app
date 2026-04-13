import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.chatWallpaper,
      child: CustomPaint(
        painter: _WallpaperPainter(iconColor: colors.wallpaperIcon),
        size: Size.infinite,
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  final Color iconColor;
  _WallpaperPainter({required this.iconColor});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = iconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = iconColor
      ..style = PaintingStyle.fill;

    const cellSize = 80.0;
    const iconSize = 16.0;

    final icons = [
      _drawChat, _drawPhone, _drawCamera, _drawSmile,
      _drawPaperclip, _drawClock, _drawStar, _drawHeart,
      _drawEnvelope, _drawPin, _drawMicrophone, _drawDocument,
    ];

    final rng = Random(42);

    for (double y = -cellSize; y < size.height + cellSize; y += cellSize) {
      for (double x = -cellSize; x < size.width + cellSize; x += cellSize) {
        final ox = x + (rng.nextDouble() - 0.5) * 20;
        final oy = y + (rng.nextDouble() - 0.5) * 20;
        final rot = (rng.nextDouble() - 0.5) * 0.5;

        canvas.save();
        canvas.translate(ox, oy);
        canvas.rotate(rot);
        icons[rng.nextInt(icons.length)](canvas, Offset.zero, iconSize, stroke, fill);
        canvas.restore();
      }
    }

    // Scatter Enviable pins less frequently
    final logoRng = Random(99);
    for (double y = 0; y < size.height; y += cellSize * 3) {
      for (double x = cellSize * 1.5; x < size.width; x += cellSize * 3) {
        final ox = x + (logoRng.nextDouble() - 0.5) * 30;
        final oy = y + (logoRng.nextDouble() - 0.5) * 30;
        canvas.save();
        canvas.translate(ox, oy);
        _drawEnviablePin(canvas, Offset.zero, iconSize * 1.2, stroke);
        canvas.restore();
      }
    }
  }

  void _drawChat(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: s, height: s * 0.75), Radius.circular(s * 0.15)), stroke);
    final path = Path()
      ..moveTo(c.dx - s * 0.3, c.dy + s * 0.375)
      ..lineTo(c.dx - s * 0.5, c.dy + s * 0.55)
      ..lineTo(c.dx - s * 0.15, c.dy + s * 0.375);
    canvas.drawPath(path, stroke);
  }

  void _drawPhone(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: s * 0.5, height: s), Radius.circular(s * 0.1)), stroke);
    canvas.drawCircle(Offset(c.dx, c.dy + s * 0.35), s * 0.06, stroke);
  }

  void _drawCamera(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.05), width: s, height: s * 0.65), Radius.circular(s * 0.1)), stroke);
    canvas.drawCircle(c, s * 0.18, stroke);
    canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.32), width: s * 0.3, height: s * 0.12), stroke);
  }

  void _drawSmile(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    canvas.drawCircle(c, s * 0.4, stroke);
    canvas.drawCircle(Offset(c.dx - s * 0.15, c.dy - s * 0.1), s * 0.04, fill);
    canvas.drawCircle(Offset(c.dx + s * 0.15, c.dy - s * 0.1), s * 0.04, fill);
    canvas.drawPath(Path()..addArc(
      Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.02), width: s * 0.35, height: s * 0.25), 0.2, 2.7), stroke);
  }

  void _drawPaperclip(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    final path = Path()
      ..moveTo(c.dx + s * 0.1, c.dy + s * 0.4)
      ..lineTo(c.dx + s * 0.1, c.dy - s * 0.2)
      ..arcToPoint(Offset(c.dx - s * 0.1, c.dy - s * 0.2), radius: Radius.circular(s * 0.1))
      ..lineTo(c.dx - s * 0.1, c.dy + s * 0.25)
      ..arcToPoint(Offset(c.dx + s * 0.1, c.dy + s * 0.25), radius: Radius.circular(s * 0.1), clockwise: false);
    canvas.drawPath(path, stroke);
  }

  void _drawClock(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    canvas.drawCircle(c, s * 0.4, stroke);
    canvas.drawLine(c, Offset(c.dx, c.dy - s * 0.25), stroke);
    canvas.drawLine(c, Offset(c.dx + s * 0.2, c.dy), stroke);
  }

  void _drawStar(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final a = (i * 4 * pi / 5) - pi / 2;
      final p = Offset(c.dx + s * 0.4 * cos(a), c.dy + s * 0.4 * sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, stroke);
  }

  void _drawHeart(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.3)
      ..cubicTo(c.dx - s * 0.5, c.dy, c.dx - s * 0.5, c.dy - s * 0.35, c.dx, c.dy - s * 0.15)
      ..cubicTo(c.dx + s * 0.5, c.dy - s * 0.35, c.dx + s * 0.5, c.dy, c.dx, c.dy + s * 0.3);
    canvas.drawPath(path, stroke);
  }

  void _drawEnvelope(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    final rect = Rect.fromCenter(center: c, width: s, height: s * 0.7);
    canvas.drawRect(rect, stroke);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(c.dx, c.dy + s * 0.05), stroke);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(c.dx, c.dy + s * 0.05), stroke);
  }

  void _drawPin(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.45)
      ..cubicTo(c.dx - s * 0.4, c.dy + s * 0.05, c.dx - s * 0.4, c.dy - s * 0.35, c.dx, c.dy - s * 0.45)
      ..cubicTo(c.dx + s * 0.4, c.dy - s * 0.35, c.dx + s * 0.4, c.dy + s * 0.05, c.dx, c.dy + s * 0.45);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(Offset(c.dx, c.dy - s * 0.1), s * 0.12, stroke);
  }

  void _drawMicrophone(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(c.dx, c.dy - s * 0.1), width: s * 0.3, height: s * 0.5), Radius.circular(s * 0.15)), stroke);
    canvas.drawLine(Offset(c.dx, c.dy + s * 0.15), Offset(c.dx, c.dy + s * 0.35), stroke);
    canvas.drawLine(Offset(c.dx - s * 0.15, c.dy + s * 0.35), Offset(c.dx + s * 0.15, c.dy + s * 0.35), stroke);
  }

  void _drawDocument(Canvas canvas, Offset c, double s, Paint stroke, Paint fill) {
    final rect = Rect.fromCenter(center: c, width: s * 0.6, height: s * 0.8);
    canvas.drawRect(rect, stroke);
    for (int i = 0; i < 3; i++) {
      final y = rect.top + s * 0.2 + i * s * 0.18;
      canvas.drawLine(Offset(rect.left + s * 0.08, y), Offset(rect.right - s * 0.08, y), stroke);
    }
  }

  void _drawEnviablePin(Canvas canvas, Offset c, double s, Paint stroke) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.5)
      ..cubicTo(c.dx - s * 0.45, c.dy + s * 0.05, c.dx - s * 0.45, c.dy - s * 0.35, c.dx, c.dy - s * 0.5)
      ..cubicTo(c.dx + s * 0.45, c.dy - s * 0.35, c.dx + s * 0.45, c.dy + s * 0.05, c.dx, c.dy + s * 0.5);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(Offset(c.dx, c.dy - s * 0.15), s * 0.13, stroke);
    canvas.drawPath(Path()..addArc(
      Rect.fromCenter(center: Offset(c.dx, c.dy + s * 0.15), width: s * 0.3, height: s * 0.2), pi * 0.2, pi * 0.6), stroke);
  }

  @override
  bool shouldRepaint(covariant _WallpaperPainter old) => old.iconColor != iconColor;
}
