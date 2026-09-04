import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Модель тарифов региона, загруженная из assets/data/tariffs.json
class RegionTariff {
  final String id;
  final String name;
  final int locationId;
  final double cityFareCashless;
  final double cityFareCash;
  final double cityFareAppQr;
  final double transferPrice;
  final int transferDurationMinutes;
  final double suburbanPerKmCashless;
  final double suburbanPerKmCash;

  const RegionTariff({
    required this.id,
    required this.name,
    required this.locationId,
    required this.cityFareCashless,
    required this.cityFareCash,
    required this.cityFareAppQr,
    required this.transferPrice,
    required this.transferDurationMinutes,
    required this.suburbanPerKmCashless,
    required this.suburbanPerKmCash,
  });

  factory RegionTariff.fromJson(Map<String, dynamic> json) {
    final city = json['city'] as Map<String, dynamic>? ?? {};
    final singleRide = city['single_ride'] as Map<String, dynamic>? ?? {};
    final transfer = city['transfer'] as Map<String, dynamic>? ?? {};
    final suburban = json['suburban'] as Map<String, dynamic>? ?? {};

    return RegionTariff(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      locationId: json['location_id'] as int? ?? 1,
      cityFareCashless: (singleRide['cashless'] as num?)?.toDouble() ?? 40.0,
      cityFareCash: (singleRide['cash'] as num?)?.toDouble() ?? 45.0,
      cityFareAppQr: (singleRide['app_qr'] as num?)?.toDouble() ?? 40.0,
      transferPrice: (transfer['transfer_price'] as num?)?.toDouble() ?? 20.0,
      transferDurationMinutes: (transfer['duration_minutes'] as num?)?.toInt() ?? 60,
      suburbanPerKmCashless: (suburban['per_km_cashless'] as num?)?.toDouble() ?? 4.75,
      suburbanPerKmCash: (suburban['per_km_cash'] as num?)?.toDouble() ?? 4.85,
    );
  }
}

/// Сервис тарифов — загружает тарифы из tariffs.json и предоставляет
/// методы расчёта стоимости проезда для городских, пригородных и пересадочных билетов.
class TariffService {
  static final TariffService instance = TariffService._internal();
  TariffService._internal();

  List<RegionTariff> _tariffs = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Загрузка тарифов из assets
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/tariffs.json');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final regions = data['regions'] as List<dynamic>? ?? [];
      _tariffs = regions
          .map((r) => RegionTariff.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback — дефолтный тариф Твери
      _tariffs = [
        const RegionTariff(
          id: 'tver',
          name: 'Тверь и Калининский район',
          locationId: 1,
          cityFareCashless: 40.0,
          cityFareCash: 45.0,
          cityFareAppQr: 40.0,
          transferPrice: 20.0,
          transferDurationMinutes: 60,
          suburbanPerKmCashless: 4.75,
          suburbanPerKmCash: 4.85,
        ),
      ];
    }
    _isLoaded = true;
  }

  RegionTariff _getRegion(int locationId) {
    return _tariffs.firstWhere(
      (t) => t.locationId == locationId,
      orElse: () => _tariffs.isNotEmpty
          ? _tariffs.first
          : const RegionTariff(
              id: 'tver',
              name: 'Тверь',
              locationId: 1,
              cityFareCashless: 40.0,
              cityFareCash: 45.0,
              cityFareAppQr: 40.0,
              transferPrice: 20.0,
              transferDurationMinutes: 60,
              suburbanPerKmCashless: 4.75,
              suburbanPerKmCash: 4.85,
            ),
    );
  }

  /// Городской тариф оплаты через приложение (QR)
  int getCityFare({int locationId = 1}) {
    return _getRegion(locationId).cityFareAppQr.round();
  }

  /// Стоимость пересадки
  int getTransferFare({int locationId = 1}) {
    return _getRegion(locationId).transferPrice.round();
  }

  /// Длительность окна для пересадки (минуты)
  int getTransferDurationMinutes({int locationId = 1}) {
    return _getRegion(locationId).transferDurationMinutes;
  }

  /// Тариф за километр (безналичный) для пригородных маршрутов
  double getSuburbanPerKm({int locationId = 1}) {
    return _getRegion(locationId).suburbanPerKmCashless;
  }

  /// Расчёт стоимости пригородного проезда по расстоянию
  /// distanceKm — расстояние между остановками в километрах
  int computeSuburbanFare(double distanceKm, {int locationId = 1}) {
    final region = _getRegion(locationId);
    final perKm = region.suburbanPerKmCashless;
    final computed = (perKm * distanceKm).round();
    return computed > 0 ? computed : 1;
  }

  /// Расстояние между двумя точками по формуле Haversine (в километрах)
  /// с коэффициентом 1.3 для учёта реальной длины дороги
  static double haversineDistanceKm(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const earthRadius = 6371.0; // км
    const roadCoefficient = 1.3;

    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final straightLine = earthRadius * c;

    return straightLine * roadCoefficient;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}
