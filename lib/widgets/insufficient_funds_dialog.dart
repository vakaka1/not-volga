import 'package:flutter/material.dart';

/// Dialog shown when attempting payment or opening QR scanner with insufficient balance (< 40 ₽).
/// Strictly reproduces res/bilet/qr-error.webp with exact title, message, shape (BorderRadius.circular(4.0)), and flat "OK" button.
class InsufficientFundsDialog extends StatelessWidget {
  const InsufficientFundsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const InsufficientFundsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      title: const Text(
        'Ошибка',
        style: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: Color(0xFF000000),
        ),
      ),
      content: const Text(
        'Недостаточно средств',
        style: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFF000000),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF165AF0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'OK',
            style: TextStyle(
              fontFamily: 'NotoSans',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
