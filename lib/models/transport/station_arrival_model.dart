import 'package:intl/intl.dart';

class StationArrivalModel {
  final int routeId;
  final String routeName;
  final String endStation;
  final List<DateTime> estimatedArrivals;
  final String? licenseNumber;
  final bool hasWheelchair;

  const StationArrivalModel({
    required this.routeId,
    required this.routeName,
    required this.endStation,
    this.estimatedArrivals = const [],
    this.licenseNumber,
    this.hasWheelchair = false,
  });

  factory StationArrivalModel.fromJson(Map<String, dynamic> json, {String? matchedLicense}) {
    final rawArrivals = json['estimated_arrival'] as List<dynamic>? ?? [];
    final arrivals = <DateTime>[];
    for (final a in rawArrivals) {
      if (a is String) {
        try {
          arrivals.add(DateTime.parse(a));
        } catch (_) {}
      }
    }
    arrivals.sort();

    return StationArrivalModel(
      routeId: json['route_id'] as int? ?? 0,
      routeName: json['name'] as String? ?? '',
      endStation: json['end_station'] as String? ?? '',
      estimatedArrivals: arrivals,
      licenseNumber: matchedLicense,
      hasWheelchair: matchedLicense != null && matchedLicense.isNotEmpty,
    );
  }

  /// Получить оставшееся количество минут до первого прибытия
  int? get minutesToFirstArrival {
    if (estimatedArrivals.isEmpty) return null;
    final now = DateTime.now();
    final diff = estimatedArrivals.first.difference(now).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  /// Получить оставшееся количество минут до второго прибытия
  int? get minutesToSecondArrival {
    if (estimatedArrivals.length < 2) return null;
    final now = DateTime.now();
    final diff = estimatedArrivals[1].difference(now).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  /// Строка времени первого прибытия в формате "7 мин", "Прибывает" или "15:41"
  String get primaryTimeText {
    final mins = minutesToFirstArrival;
    if (mins == null) return '--';
    if (mins <= 0) {
      return 'Прибывает';
    }
    if (mins <= 45) {
      return '$mins мин';
    }
    return DateFormat('HH:mm').format(estimatedArrivals.first);
  }

  /// Строка времени второго прибытия в формате "15 мин", "Прибывает" или "16:10"
  String? get secondaryTimeText {
    final mins = minutesToSecondArrival;
    if (mins == null) return null;
    if (mins <= 0) {
      return 'Прибывает';
    }
    if (mins <= 60) {
      return '$mins мин';
    }
    return DateFormat('HH:mm').format(estimatedArrivals[1]);
  }
}
