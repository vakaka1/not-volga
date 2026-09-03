import 'dart:convert';

/// Represents a single completed or active trip entry in the ride history.
class TripHistoryItem {
  final String id;
  final String routeNumber; // e.g. "2", "204", "30", "208"
  final String routeTitle; // e.g. "Южный - Мигалово"
  final String startStation; // Boarding stop e.g. "Луговая улица"
  final String? endStation; // Optional exit stop for suburban/intercity (e.g. "Улица Фрунзе")
  final int fare; // Fare in rubles e.g. 40, 46
  final DateTime purchaseTime; // Purchase timestamp
  final String? customDateLabel; // Optional override for mock display (e.g. "Сегодня", "31 августа")

  const TripHistoryItem({
    required this.id,
    required this.routeNumber,
    required this.routeTitle,
    required this.startStation,
    this.endStation,
    required this.fare,
    required this.purchaseTime,
    this.customDateLabel,
  });

  /// Russian month names in genitive case for dates
  static const List<String> _monthsGenitive = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  /// Returns date part formatted according to specifications:
  /// "Сегодня" if the trip occurred today, or custom label, or "$day $month" (e.g. "31 августа").
  String get formattedDate {
    if (customDateLabel != null && customDateLabel!.isNotEmpty) {
      return customDateLabel!;
    }
    final now = DateTime.now();
    if (purchaseTime.year == now.year &&
        purchaseTime.month == now.month &&
        purchaseTime.day == now.day) {
      return 'Сегодня';
    }
    final monthName = _monthsGenitive[purchaseTime.month - 1];
    return '${purchaseTime.day} $monthName';
  }

  /// Returns time formatted as "HH:mm" (24-hour).
  String get formattedTime {
    final h = purchaseTime.hour.toString().padLeft(2, '0');
    final m = purchaseTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Clean route number without "№" prefix
  String get cleanRouteNumber {
    return routeNumber.replaceAll('№', '').trim();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routeNumber': routeNumber,
      'routeTitle': routeTitle,
      'startStation': startStation,
      'endStation': endStation,
      'fare': fare,
      'purchaseTime': purchaseTime.toIso8601String(),
      'customDateLabel': customDateLabel,
    };
  }

  factory TripHistoryItem.fromMap(Map<String, dynamic> map) {
    return TripHistoryItem(
      id: map['id'] as String? ?? '',
      routeNumber: map['routeNumber'] as String? ?? '',
      routeTitle: map['routeTitle'] as String? ?? '',
      startStation: map['startStation'] as String? ?? '',
      endStation: map['endStation'] as String?,
      fare: (map['fare'] as num?)?.toInt() ?? 40,
      purchaseTime: map['purchaseTime'] != null
          ? DateTime.tryParse(map['purchaseTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      customDateLabel: map['customDateLabel'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory TripHistoryItem.fromJson(String source) =>
      TripHistoryItem.fromMap(json.decode(source) as Map<String, dynamic>);
}
