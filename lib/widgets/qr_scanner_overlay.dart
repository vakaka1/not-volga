import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';

/// Overlay widget that paints the darkened background with a rounded cutout window
/// matching `res/qr.webp` and renders a thin solid BLUE detection contour on recognized QR codes.
class QrScannerOverlay extends StatelessWidget {
  final List<Barcode> detectedBarcodes;
  final Size? captureSize;
  final Rect? customCutoutRect;

  const QrScannerOverlay({
    super.key,
    this.detectedBarcodes = const [],
    this.captureSize,
    this.customCutoutRect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // Calculate viewfinder cutout window size and position matching res/qr.webp
        final cutoutWidth = math.min(screenWidth * 0.86, 330.0);
        final cutoutHeight = cutoutWidth;
        final cutoutLeft = (screenWidth - cutoutWidth) / 2;
        // Positioned slightly above vertical center, matching res/qr.webp
        final cutoutTop = screenHeight * 0.28;

        final cutoutRect = customCutoutRect ??
            Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutWidth, cutoutHeight);

        return CustomPaint(
          size: Size(screenWidth, screenHeight),
          painter: _QrScannerOverlayPainter(
            cutoutRect: cutoutRect,
            detectedBarcodes: detectedBarcodes,
            captureSize: captureSize,
          ),
        );
      },
    );
  }
}

class _QrScannerOverlayPainter extends CustomPainter {
  final Rect cutoutRect;
  final List<Barcode> detectedBarcodes;
  final Size? captureSize;

  _QrScannerOverlayPainter({
    required this.cutoutRect,
    required this.detectedBarcodes,
    required this.captureSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = AppColors.qrOverlayBackground
      ..style = PaintingStyle.fill;

    const cornerRadius = Radius.circular(26.0);
    final cutoutRRect = RRect.fromRectAndRadius(cutoutRect, cornerRadius);

    // Create overlay path with a transparent hole for the cutout window
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutoutRRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, overlayPaint);

    // Subtle edge highlight for the cutout window
    final cutoutBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(cutoutRRect, cutoutBorderPaint);

    // Draw thin solid BLUE contour on detected QR codes
    if (detectedBarcodes.isNotEmpty) {
      _drawDetectedBarcodes(canvas, size);
    }
  }

  void _drawDetectedBarcodes(Canvas canvas, Size size) {
    // Тонкая сплошная синяя линия (#0052FF)
    final contourPaint = Paint()
      ..color = const Color(0xFF0052FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final barcode in detectedBarcodes) {
      final corners = barcode.corners;
      if (corners.length == 4 && captureSize != null && captureSize!.width > 0 && captureSize!.height > 0) {
        // Map corners from camera image coordinate space to screen coordinate space
        final mappedPoints = corners.map((corner) {
          return _mapPointToScreen(corner, captureSize!, size);
        }).toList();

        final path = Path()
          ..moveTo(mappedPoints[0].dx, mappedPoints[0].dy)
          ..lineTo(mappedPoints[1].dx, mappedPoints[1].dy)
          ..lineTo(mappedPoints[2].dx, mappedPoints[2].dy)
          ..lineTo(mappedPoints[3].dx, mappedPoints[3].dy)
          ..close();

        // Рисуем сплошную тонкую синюю линию
        canvas.drawPath(path, contourPaint);
      } else {
        // Fallback: сплошная синяя рамка вокруг окна видоискателя
        canvas.drawRRect(
          RRect.fromRectAndRadius(cutoutRect, const Radius.circular(26.0)),
          contourPaint,
        );
      }
    }
  }

  Offset _mapPointToScreen(Offset point, Size imageSize, Size screenSize) {
    // Determine scale for BoxFit.cover
    final double scaleX = screenSize.width / imageSize.width;
    final double scaleY = screenSize.height / imageSize.height;
    final double scale = math.max(scaleX, scaleY);

    final double offsetX = (screenSize.width - imageSize.width * scale) / 2.0;
    final double offsetY = (screenSize.height - imageSize.height * scale) / 2.0;

    return Offset(
      point.dx * scale + offsetX,
      point.dy * scale + offsetY,
    );
  }

  @override
  bool shouldRepaint(covariant _QrScannerOverlayPainter oldDelegate) {
    return oldDelegate.detectedBarcodes != detectedBarcodes ||
        oldDelegate.captureSize != captureSize ||
        oldDelegate.cutoutRect != cutoutRect;
  }
}
