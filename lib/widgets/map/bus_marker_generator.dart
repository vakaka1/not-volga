import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class BusMarkerGenerator {
  static Uint8List? _blueTeardropPinBytes;

  /// Генерация синего маркера-капли (как ic_routes.png, но синий с автобусом),
  /// направленного вверх (на Север при course = 0).
  /// MapKit поворачивает маркер через `direction: course`.
  static Future<Uint8List> getBlueBusPin() async {
    if (_blueTeardropPinBytes != null) {
      return _blueTeardropPinBytes!;
    }

    const double width = 80.0;
    const double height = 100.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    const radius = 34.0;

    // 1. Тень под каплей
    final shadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final shadowPath = Path();
    // Кончик указывает вверх (на 40, 4)
    shadowPath.moveTo(40, 6);
    shadowPath.lineTo(40 + radius * 0.85, 42);
    shadowPath.arcToPoint(
      const Offset(40 - radius * 0.85, 42),
      radius: const Radius.circular(radius),
      clockwise: true,
    );
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);

    // 2. Синее тело капли (в точности форма ic_routes.png, но синий цвет и острие вверх)
    final pinPaint = Paint()..color = const Color(0xFF0052FF);
    final pinPath = Path();
    pinPath.moveTo(40, 4);
    pinPath.lineTo(40 + radius * 0.85, 40);
    pinPath.arcToPoint(
      const Offset(40 - radius * 0.85, 40),
      radius: const Radius.circular(radius),
      clockwise: true,
    );
    pinPath.close();
    canvas.drawPath(pinPath, pinPaint);

    // Белая окантовка капли
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(pinPath, borderPaint);

    // 3. Белый автобус внутри (вид спереди)
    final busPaint = Paint()..color = Colors.white;
    final busRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(26, 32, 28, 28),
      const Radius.circular(5),
    );
    canvas.drawRRect(busRect, busPaint);

    // Лобовое стекло (синее)
    final windowPaint = Paint()..color = const Color(0xFF0052FF);
    final windowRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(29, 36, 22, 9),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(windowRect, windowPaint);

    // Фары (синие кружки)
    canvas.drawCircle(const Offset(31, 52), 2.5, windowPaint);
    canvas.drawCircle(const Offset(49, 52), 2.5, windowPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    _blueTeardropPinBytes = byteData!.buffer.asUint8List();

    return _blueTeardropPinBytes!;
  }
}
