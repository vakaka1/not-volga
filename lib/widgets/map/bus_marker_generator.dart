import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

class BusMarkerGenerator {
  static ui.Image? _bluePinImage;
  static ui.Image? _busIconImage;

  static final Map<int, BitmapDescriptor> _normalCache = {};
  static final Map<String, BitmapDescriptor> _selectedCache = {};

  static bool _isInitializing = false;
  static Completer<void>? _initCompleter;

  /// Инициализация исходных изображений из assets
  static Future<void> init() async {
    if (_bluePinImage != null && _busIconImage != null) return;
    if (_isInitializing) return _initCompleter?.future;

    _isInitializing = true;
    _initCompleter = Completer<void>();

    try {
      final blueData = await rootBundle.load('assets/icons/ic_routes_blue.png');
      final busData = await rootBundle.load('assets/icons/ic_routes_bus.png');

      final results = await Future.wait([
        _decodeImage(blueData.buffer.asUint8List()),
        _decodeImage(busData.buffer.asUint8List()),
      ]);

      _bluePinImage = results[0];
      _busIconImage = results[1];

      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      _isInitializing = false;
      _initCompleter = null;
    }
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return completer.future;
  }

  /// Получить маркер автобуса (синяя капля повернута по курсу, белый автобус внутри стоит ровно)
  static Future<BitmapDescriptor> getBusMarker({
    required double course,
    String? routeName,
    bool isSelected = false,
  }) async {
    await init();
    if (_bluePinImage == null || _busIconImage == null) {
      return BitmapDescriptor.fromAssetImage('assets/icons/ic_routes_blue.png');
    }

    // Округляем угол до 5 градусов для эффективного кэширования (всего 72 варианта)
    final int roundedAngle = ((course % 360) / 5).round() * 5 % 360;

    if (!isSelected) {
      final cached = _normalCache[roundedAngle];
      if (cached != null) return cached;

      final descriptor = await _generateNormalMarker(roundedAngle);
      _normalCache[roundedAngle] = descriptor;
      return descriptor;
    } else {
      final String key = '${routeName ?? ""}_$roundedAngle';
      final cached = _selectedCache[key];
      if (cached != null) return cached;

      final descriptor = await _generateSelectedMarker(roundedAngle, routeName ?? '');
      _selectedCache[key] = descriptor;
      return descriptor;
    }
  }

  /// Синхронный возврат из кэша (если уже сгенерирован), иначе null
  static BitmapDescriptor? getCachedMarker({
    required double course,
    String? routeName,
    bool isSelected = false,
  }) {
    final int roundedAngle = ((course % 360) / 5).round() * 5 % 360;
    if (!isSelected) {
      return _normalCache[roundedAngle];
    } else {
      return _selectedCache['${routeName ?? ""}_$roundedAngle'];
    }
  }

  static const double _busWidth = 46.0;
  static const double _busHeight = 52.5;
  static const Rect _busSrc = Rect.fromLTWH(26, 23, 43, 49);

  static Future<BitmapDescriptor> _generateNormalMarker(int angleDeg) async {
    const double size = 180.0;
    const double cx = size / 2;
    const double cy = size / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    // 1. Поворот синей капли по направлению движения
    // В исходном файле ic_routes_blue.png острие направлено ВНИЗ (180 градусов).
    // Поэтому для направления angleDeg поворачиваем на (angleDeg - 180) градусов.
    final double angleRad = (angleDeg - 180) * math.pi / 180.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angleRad);
    // Центр круглой части капли в изображении 96x128 находится в (48, 48)
    canvas.drawImage(_bluePinImage!, const Offset(-48, -48), Paint());
    canvas.restore();

    // 2. Белый значок автобуса ic_routes_bus.png поверх капли (уменьшенный на пару пунктов)
    final Rect busDest = Rect.fromCenter(
      center: const Offset(cx, cy),
      width: _busWidth,
      height: _busHeight,
    );
    canvas.drawImageRect(_busIconImage!, _busSrc, busDest, Paint());

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _generateSelectedMarker(int angleDeg, String routeName) async {
    // Для выбранного маркера добавляем плашку с номером маршрута справа (поверх капли)
    final textPainter = TextPainter(
      text: TextSpan(
        text: routeName,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          fontFamily: 'NotoSans',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double textWidth = textPainter.width;
    const double badgeHeight = 54.0;
    const double cx = 90.0;
    const double cy = 90.0;
    const double totalHeight = 180.0;

    // Круглая часть капли имеет радиус 48 вокруг (cx, cy). Край круга находится на x = 90 + 48 = 138.
    // Плашка начинается на x = 126 (стыкуется с круглой частью капли).
    // Текст начинается на x = 144, что строго за пределами синего круга.
    const double badgeLeft = 126.0;
    final double badgeWidth = textWidth + 36.0;
    final double totalWidth = badgeLeft + badgeWidth + 14.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, totalWidth, totalHeight));

    // 1. Синяя капля по направлению движения (рисуется первой!)
    final double angleRad = (angleDeg - 180) * math.pi / 180.0;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angleRad);
    canvas.drawImage(_bluePinImage!, const Offset(-48, -48), Paint());
    canvas.restore();

    // 2. Белый автобус поверх капли (уменьшенный)
    final Rect selBusDest = Rect.fromCenter(
      center: const Offset(cx, cy),
      width: _busWidth,
      height: _busHeight,
    );
    canvas.drawImageRect(_busIconImage!, _busSrc, selBusDest, Paint());

    // 3. Белая плашка с номером маршрута ПОВЕРХ капли (чтобы ни круг капли, ни повернутый хвост не наезжали на номер!)
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeLeft, cy - badgeHeight / 2, badgeWidth, badgeHeight),
      const Radius.circular(16),
    );
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(badgeRect.shift(const Offset(0, 2)), shadowPaint);

    final badgePaint = Paint()..color = Colors.white;
    canvas.drawRRect(badgeRect, badgePaint);

    // Отрисовка номера маршрута внутри плашки
    final double textX = badgeLeft + 18.0;
    textPainter.paint(
      canvas,
      Offset(textX, cy - textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(totalWidth.toInt(), totalHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  /// Точный якорь для выбранного маркера, чтобы центр капли (cx, cy) оставался ровно на координатах автобуса
  static Offset getSelectedAnchor(String? routeName) {
    if (routeName == null || routeName.isEmpty) {
      return const Offset(0.35, 0.5);
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: routeName,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          fontFamily: 'NotoSans',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const double badgeLeft = 126.0;
    final double badgeWidth = textPainter.width + 36.0;
    final double totalWidth = badgeLeft + badgeWidth + 14.0;
    return Offset(90.0 / totalWidth, 0.5);
  }
}
