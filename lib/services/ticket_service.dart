import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/trip_history_item.dart';
import 'trip_history_service.dart';

/// Helper to format Russian vehicle license plates according to national standard:
/// e.g. "H390CP69" or "Н390СР69" -> "Н 390 СР 69".
/// Translates Latin lookalikes to Russian Cyrillic letters.
String formatRussianLicensePlate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  const latinToCyrillic = {
    'A': 'А', 'B': 'В', 'E': 'Е', 'K': 'К', 'M': 'М', 'H': 'Н',
    'O': 'О', 'P': 'Р', 'C': 'С', 'T': 'Т', 'Y': 'У', 'X': 'Х',
    'a': 'А', 'b': 'В', 'e': 'Е', 'k': 'К', 'm': 'М', 'h': 'Н',
    'o': 'О', 'p': 'Р', 'c': 'С', 't': 'Т', 'y': 'У', 'x': 'Х',
  };

  final clean = trimmed.replaceAll(' ', '');
  final buffer = StringBuffer();
  for (int i = 0; i < clean.length; i++) {
    final ch = clean[i];
    buffer.write(latinToCyrillic[ch] ?? ch.toUpperCase());
  }
  final converted = buffer.toString();

  final regPlate = RegExp(r'^[А-Я]\d{3}[А-Я]{2}\d{2,3}$');
  if (regPlate.hasMatch(converted)) {
    final letter1 = converted.substring(0, 1);
    final digits = converted.substring(1, 4);
    final letters2 = converted.substring(4, 6);
    final region = converted.substring(6);
    return '$letter1 $digits $letters2 $region';
  }

  return raw.trim();
}

/// Represents an active transport ticket purchased by the passenger.
/// Strictly implements the architectural specification in TICKET_SCREEN_ARCHITECTURE.md.
class ActiveTicket {
  final String id;                  // Internal key: TICKET_{timestamp}
  final String ticketUuid;          // UUID v4 for checker URL
  final String routeNumber;         // E.g.: "2" (without "№")
  final String routeTitle;          // Direction: "Южный - Мигалово"
  final String station;             // Boarding stop: "Луговая улица"
  final String? endStation;         // Exit stop if suburban/intercity
  final int fare;                   // Price: 40
  final DateTime purchaseTime;      // Purchase time (e.g. 2026-09-03 07:48:00)
  final DateTime expiryTime;        // Expiration: purchaseTime + 2 hours
  final String licenseNumber;       // License plate: "Н 390 СР 69"
  final String boardNumber;         // Board number: "10106"
  final String carrierName;         // E.g. "ООО \"Верхневолжское автотранспортное предприятие\""
  final String vehicleModel;        // Vehicle model: "ЛиАЗ 429260"

  ActiveTicket({
    required this.id,
    required this.ticketUuid,
    required this.routeNumber,
    required this.routeTitle,
    required this.station,
    this.endStation,
    required this.fare,
    required this.purchaseTime,
    required this.expiryTime,
    required this.licenseNumber,
    required this.boardNumber,
    required this.carrierName,
    required this.vehicleModel,
  });

  /// Official checker URL matching Tver transport validation system
  String get checkerUrl => 'https://ticket-checker.merlin.tvercard.ru/$ticketUuid';

  bool get isExpired => DateTime.now().isAfter(expiryTime);

  Duration get remainingTime {
    final diff = expiryTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}

/// Service managing the active ticket lifecycle with 2-hour persistence across app restarts.
class TicketService extends ChangeNotifier {
  static final TicketService instance = TicketService._internal();
  TicketService._internal();

  static const String _keyTicketId = 'ticket_active_id';
  static const String _keyTicketUuid = 'ticket_uuid';
  static const String _keyRouteNumber = 'ticket_route_number';
  static const String _keyRouteTitle = 'ticket_route_title';
  static const String _keyStation = 'ticket_station';
  static const String _keyEndStation = 'ticket_end_station';
  static const String _keyFare = 'ticket_fare';
  static const String _keyPurchaseMs = 'ticket_purchase_ms';
  static const String _keyExpiryMs = 'ticket_expiry_ms';
  static const String _keyLicenseNumber = 'ticket_license_number';
  static const String _keyBoardNumber = 'ticket_board_number';
  static const String _keyCarrierName = 'ticket_carrier_name';
  static const String _keyVehicleModel = 'ticket_vehicle_model';

  ActiveTicket? _activeTicket;
  Timer? _expiryTimer;
  bool _isLoaded = false;

  ActiveTicket? get activeTicket => _activeTicket;
  bool get hasActiveTicket => _activeTicket != null && !_activeTicket!.isExpired;
  bool get isLoaded => _isLoaded;

  Future<void> init({bool force = false}) async {
    if (_isLoaded && !force) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = prefs.getInt(_keyExpiryMs);
      if (expiryMs != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        final now = DateTime.now();
        if (now.isBefore(expiryTime)) {
          final id = prefs.getString(_keyTicketId) ?? 'TICKET_${expiryMs - 2 * 3600 * 1000}';
          final ticketUuid = prefs.getString(_keyTicketUuid) ?? const Uuid().v4();
          final routeNumber = prefs.getString(_keyRouteNumber) ?? '';
          final routeTitle = prefs.getString(_keyRouteTitle) ?? '';
          final station = prefs.getString(_keyStation) ?? '';
          final endStation = prefs.getString(_keyEndStation);
          final fare = prefs.getInt(_keyFare) ?? 40;
          final purchaseMs = prefs.getInt(_keyPurchaseMs) ?? (expiryMs - 2 * 3600 * 1000);
          final purchaseTime = DateTime.fromMillisecondsSinceEpoch(purchaseMs);
          final licenseNumber = prefs.getString(_keyLicenseNumber) ?? '';
          final boardNumber = prefs.getString(_keyBoardNumber) ?? '';
          final carrierName = prefs.getString(_keyCarrierName) ?? 'ООО "Верхневолжское автотранспортное предприятие"';
          final vehicleModel = prefs.getString(_keyVehicleModel) ?? 'ЛиАЗ 429260';

          _activeTicket = ActiveTicket(
            id: id,
            ticketUuid: ticketUuid,
            routeNumber: routeNumber,
            routeTitle: routeTitle,
            station: station,
            endStation: endStation,
            fare: fare,
            purchaseTime: purchaseTime,
            expiryTime: expiryTime,
            licenseNumber: licenseNumber,
            boardNumber: boardNumber,
            carrierName: carrierName,
            vehicleModel: vehicleModel,
          );
          _scheduleExpiryTimer(expiryTime.difference(now));
          await TripHistoryService.instance.ensureTicketInHistory(_activeTicket!);
        } else {
          await _clearStorage();
        }
      }
    } catch (e) {
      debugPrint('TicketService.init error: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> createTicket({
    required String routeNumber,
    required String routeTitle,
    required String station,
    required int fare,
    String? endStation,
    String? ticketUuid,
    String? licenseNumber,
    String? boardNumber,
    String? carrierName,
    String? vehicleModel,
    Duration duration = const Duration(hours: 2),
  }) async {
    final now = DateTime.now();
    final expiry = now.add(duration);
    final id = 'TICKET_${now.millisecondsSinceEpoch}';
    final uuid = (ticketUuid != null && ticketUuid.isNotEmpty) ? ticketUuid : const Uuid().v4();
    final cleanRoute = routeNumber.replaceAll('№', '').trim();
    final formattedPlate = formatRussianLicensePlate(licenseNumber ?? '');
    final bNum = boardNumber ?? '';
    final carrier = (carrierName != null && carrierName.isNotEmpty)
        ? carrierName
        : 'ООО "Верхневолжское автотранспортное предприятие"';
    final model = (vehicleModel != null && vehicleModel.isNotEmpty)
        ? vehicleModel
        : 'ЛиАЗ 429260';

    _activeTicket = ActiveTicket(
      id: id,
      ticketUuid: uuid,
      routeNumber: cleanRoute,
      routeTitle: routeTitle,
      station: station,
      endStation: endStation,
      fare: fare,
      purchaseTime: now,
      expiryTime: expiry,
      licenseNumber: formattedPlate,
      boardNumber: bNum,
      carrierName: carrier,
      vehicleModel: model,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTicketId, id);
      await prefs.setString(_keyTicketUuid, uuid);
      await prefs.setString(_keyRouteNumber, cleanRoute);
      await prefs.setString(_keyRouteTitle, routeTitle);
      await prefs.setString(_keyStation, station);
      if (endStation != null && endStation.isNotEmpty) {
        await prefs.setString(_keyEndStation, endStation);
      } else {
        await prefs.remove(_keyEndStation);
      }
      await prefs.setInt(_keyFare, fare);
      await prefs.setInt(_keyPurchaseMs, now.millisecondsSinceEpoch);
      await prefs.setInt(_keyExpiryMs, expiry.millisecondsSinceEpoch);
      await prefs.setString(_keyLicenseNumber, formattedPlate);
      await prefs.setString(_keyBoardNumber, bNum);
      await prefs.setString(_keyCarrierName, carrier);
      await prefs.setString(_keyVehicleModel, model);
    } catch (e) {
      debugPrint('TicketService.createTicket error: $e');
    }

    // Automatically record ticket in trip history
    await TripHistoryService.instance.addTrip(
      TripHistoryItem(
        id: id,
        routeNumber: cleanRoute,
        routeTitle: routeTitle,
        startStation: station,
        endStation: endStation,
        fare: fare,
        purchaseTime: now,
      ),
    );

    _scheduleExpiryTimer(duration);
    notifyListeners();
  }

  void checkExpiry() {
    if (_activeTicket != null && _activeTicket!.isExpired) {
      clearTicket();
    }
  }

  Future<void> clearTicket() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _activeTicket = null;
    await _clearStorage();
    notifyListeners();
  }

  Future<void> _clearStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyTicketId);
      await prefs.remove(_keyTicketUuid);
      await prefs.remove(_keyRouteNumber);
      await prefs.remove(_keyRouteTitle);
      await prefs.remove(_keyStation);
      await prefs.remove(_keyEndStation);
      await prefs.remove(_keyFare);
      await prefs.remove(_keyPurchaseMs);
      await prefs.remove(_keyExpiryMs);
      await prefs.remove(_keyLicenseNumber);
      await prefs.remove(_keyBoardNumber);
      await prefs.remove(_keyCarrierName);
      await prefs.remove(_keyVehicleModel);
    } catch (_) {}
  }

  void _scheduleExpiryTimer(Duration duration) {
    _expiryTimer?.cancel();
    _expiryTimer = Timer(duration, () {
      clearTicket();
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}
