import 'package:flutter/material.dart';

class RubleIcon extends StatelessWidget {
  final double size;
  final Color color;

  const RubleIcon({
    super.key,
    this.size = 38,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          '₽',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: size * 0.95,
            fontWeight: FontWeight.w400,
            color: color,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class TelegramPlaneIcon extends StatelessWidget {
  final double size;
  final Color color;

  const TelegramPlaneIcon({
    super.key,
    this.size = 36,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TelegramPlanePainter(color: color),
    );
  }
}

class _TelegramPlanePainter extends CustomPainter {
  final Color color;

  _TelegramPlanePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Outer paper plane body
    final path = Path();
    path.moveTo(w * 0.96, h * 0.04);
    path.lineTo(w * 0.04, h * 0.44);
    path.lineTo(w * 0.36, h * 0.60);
    path.lineTo(w * 0.36, h * 0.92);
    path.lineTo(w * 0.54, h * 0.74);
    path.lineTo(w * 0.78, h * 0.92);
    path.close();

    canvas.drawPath(path, paint);

    // Inner wing fold
    final foldPaint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final foldPath = Path();
    foldPath.moveTo(w * 0.96, h * 0.04);
    foldPath.lineTo(w * 0.36, h * 0.60);
    foldPath.lineTo(w * 0.54, h * 0.74);
    foldPath.close();

    canvas.drawPath(foldPath, foldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassesIcon extends StatelessWidget {
  final double size;
  final Color color;

  const GlassesIcon({
    super.key,
    this.size = 36,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.45),
      painter: _GlassesPainter(color: color),
    );
  }
}

class _GlassesPainter extends CustomPainter {
  final Color color;

  _GlassesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.22
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final r = size.height * 0.42;
    final cy = size.height * 0.5;

    final leftCenter = Offset(r + size.width * 0.08, cy);
    final rightCenter = Offset(size.width - r - size.width * 0.08, cy);

    // Left circular lens
    canvas.drawCircle(leftCenter, r, strokePaint);
    // Right circular lens
    canvas.drawCircle(rightCenter, r, strokePaint);

    // Bridge between lenses
    final bridgePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.20
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawLine(
      Offset(leftCenter.dx + r, cy),
      Offset(rightCenter.dx - r, cy),
      bridgePaint,
    );

    // Left temple stub
    canvas.drawLine(
      Offset(0, cy),
      Offset(leftCenter.dx - r, cy),
      bridgePaint,
    );

    // Right temple stub
    canvas.drawLine(
      Offset(rightCenter.dx + r, cy),
      Offset(size.width, cy),
      bridgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RegionBusIcon extends StatelessWidget {
  final double size;
  final Color color;

  const RegionBusIcon({
    super.key,
    this.size = 38,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.75, size),
      painter: _RegionBusPainter(color: color),
    );
  }
}

class _RegionBusPainter extends CustomPainter {
  final Color color;

  _RegionBusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Bus body
    final bodyRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, w, h * 0.88),
      topLeft: Radius.circular(w * 0.28),
      topRight: Radius.circular(w * 0.28),
      bottomLeft: Radius.circular(w * 0.12),
      bottomRight: Radius.circular(w * 0.12),
    );

    // Cutout layer
    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
    canvas.drawRRect(bodyRRect, fillPaint);

    // Wheels
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.84, w * 0.18, h * 0.16),
        Radius.circular(w * 0.06),
      ),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.74, h * 0.84, w * 0.18, h * 0.16),
        Radius.circular(w * 0.06),
      ),
      fillPaint,
    );

    final cutoutPaint = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;

    // Windshield
    final windshield = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.12, h * 0.14, w * 0.76, h * 0.32),
      topLeft: Radius.circular(w * 0.10),
      topRight: Radius.circular(w * 0.10),
      bottomLeft: Radius.circular(w * 0.06),
      bottomRight: Radius.circular(w * 0.06),
    );
    canvas.drawRRect(windshield, cutoutPaint);

    // Left Headlight
    canvas.drawCircle(Offset(w * 0.24, h * 0.65), w * 0.10, cutoutPaint);

    // Right Headlight
    canvas.drawCircle(Offset(w * 0.76, h * 0.65), w * 0.10, cutoutPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
