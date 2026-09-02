import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';

/// Overlay widget that paints the darkened background with a rounded cutout window
/// matching `res/qr.webp` and renders a yellow detection contour on recognized QR codes.
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

    // Draw yellow contour on detected QR codes
    if (detectedBarcodes.isNotEmpty) {
      _drawDetectedBarcodes(canvas, size);
    }
  }

  void _drawDetectedBarcodes(Canvas canvas, Size size) {
    final contourPaint = Paint()
      ..color = AppColors.qrContourYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = AppColors.qrContourYellow.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    final fillPaint = Paint()
      ..color = AppColors.qrContourYellow.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

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

        // Draw glow, fill, and sharp contour in yellow
        canvas.drawPath(path, glowPaint);
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, contourPaint);

        // Draw corner brackets
        _drawCornerAccents(canvas, mappedPoints);
      } else {
        // If exact corners aren't available, draw a yellow outline around the cutout
        canvas.drawRRect(
          RRect.fromRectAndRadius(cutoutRect, const Radius.circular(26.0)),
          glowPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(cutoutRect, const Radius.circular(26.0)),
          contourPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(cutoutRect, const Radius.circular(26.0)),
          fillPaint,
        );
      }
    }
  }

  void _drawCornerAccents(Canvas canvas, List<Offset> points) {
    final accentPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final pNext = points[(i + 1) % points.length];
      final pPrev = points[(i - 1 + points.length) % points.length];

      final vNext = (pNext - p1);
      final vPrev = (pPrev - p1);

      final lenNext = vNext.distance;
      final lenPrev = vPrev.distance;

      if (lenNext > 0 && lenPrev > 0) {
        final dNext = math.min(18.0, lenNext * 0.25);
        final dPrev = math.min(18.0, lenPrev * 0.25);

        final pAccentNext = p1 + (vNext / lenNext) * dNext;
        final pAccentPrev = p1 + (vPrev / lenPrev) * dPrev;

        canvas.drawLine(p1, pAccentNext, accentPaint);
        canvas.drawLine(p1, pAccentPrev, accentPaint);
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
