/// Результат парсинга полезной нагрузки QR-кода транспорта
class ParsedQrPayload {
  final String rawData;
  final String? uuid;
  final String? qrNumber;
  final String? boardNumber;
  final String? routeNumber;

  const ParsedQrPayload({
    required this.rawData,
    this.uuid,
    this.qrNumber,
    this.boardNumber,
    this.routeNumber,
  });

  bool get hasIdentifier =>
      uuid != null || qrNumber != null || boardNumber != null || routeNumber != null;
}

/// Утилита парсинга любых форматов QR-кодов «Транспорт Верхневолжья»
class QrPayloadParser {
  static final RegExp _uuidRegex = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  static final RegExp _qrNumberRegex = RegExp(r'69-\d{4}', caseSensitive: false);
  static final RegExp _shortQrRegex = RegExp(r'690\d-\d{4}', caseSensitive: false);
  static final RegExp _boardRegex = RegExp(r'\b(1\d{4}|4\d{4}|78\d{3})\b');
  static final RegExp _routeParamRegex = RegExp(r'(?:route|marshrut)=([a-zA-Z0-9а-яА-Я]+)', caseSensitive: false);
  static final RegExp _cleanRouteRegex = RegExp(r'^[№N]?\s*(\d{1,3}[а-яА-Яa-zA-Z]?)$');

  static ParsedQrPayload parse(String rawData) {
    final clean = rawData.trim();
    String? uuid;
    String? qrNumber;
    String? boardNumber;
    String? routeNumber;

    // 1. Поиск UUID (в URL или прямом виде)
    final uuidMatch = _uuidRegex.firstMatch(clean);
    if (uuidMatch != null) {
      uuid = uuidMatch.group(0)!.toLowerCase();
    }

    // 2. Поиск номера наклейки (например, "69-0391")
    final qrNumMatch = _qrNumberRegex.firstMatch(clean);
    if (qrNumMatch != null) {
      qrNumber = qrNumMatch.group(0)!;
      final digits = qrNumber.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 4) {
        final last4 = digits.substring(digits.length - 4);
        boardNumber = '1$last4';
      }
    } else {
      final shortMatch = _shortQrRegex.firstMatch(clean);
      if (shortMatch != null) {
        qrNumber = shortMatch.group(0)!;
      }
    }

    // 3. Поиск явного бортового номера (10391, 10523 и т.д.)
    if (boardNumber == null) {
      final boardMatch = _boardRegex.firstMatch(clean);
      if (boardMatch != null) {
        boardNumber = boardMatch.group(0);
      }
    }

    // 4. Поиск маршрута из параметров URL
    final routeParamMatch = _routeParamRegex.firstMatch(clean);
    if (routeParamMatch != null) {
      routeNumber = routeParamMatch.group(1);
    } else {
      final cleanRouteMatch = _cleanRouteRegex.firstMatch(clean);
      if (cleanRouteMatch != null) {
        routeNumber = cleanRouteMatch.group(1);
      }
    }

    return ParsedQrPayload(
      rawData: clean,
      uuid: uuid,
      qrNumber: qrNumber,
      boardNumber: boardNumber,
      routeNumber: routeNumber,
    );
  }
}
