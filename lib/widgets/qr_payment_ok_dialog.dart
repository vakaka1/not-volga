import 'package:flutter/material.dart';

/// Modal dialog strictly reproducing `res/bilet/qr-scan-ok.webp`.
/// Displays a clean white card with a close button (✕) in the top-right corner,
/// a perfectly centered large vibrant green checkmark (✓), and the bold text "Оплачено {fare} ₽".
class QrPaymentOkDialog extends StatelessWidget {
  final int fare;

  const QrPaymentOkDialog({
    super.key,
    this.fare = 40,
  });

  static Future<void> show(BuildContext context, {int fare = 40}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => QrPaymentOkDialog(fare: fare),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Close button (✕) in top-right corner matching reference
          Positioned(
            top: 14,
            right: 14,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6.0),
                child: const Icon(
                  Icons.close,
                  color: Color(0xFF1E293B),
                  size: 24,
                ),
              ),
            ),
          ),

          // Dialog Body Content - Perfectly Centered
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 54),

                // Centered Green Checkmark matching res/bilet/qr-scan-ok.webp
                Center(
                  child: SizedBox(
                    width: 60,
                    height: 44,
                    child: CustomPaint(
                      painter: _GreenCheckmarkPainter(),
                    ),
                  ),
                ),
                const SizedBox(height: 44),

                // Bold text: "Оплачено 40 ₽"
                Center(
                  child: Text(
                    'Оплачено $fare ₽',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000000),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenCheckmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22C55E) // Vibrant green matching res/bilet/qr-scan-ok.webp
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.54)
      ..lineTo(size.width * 0.40, size.height * 0.90)
      ..lineTo(size.width * 0.88, size.height * 0.12);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
