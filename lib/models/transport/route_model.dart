class RouteModel {
  final int routeId;
  final String name;
  final String title;
  final String startEndStations;
  final String endStation;
  final int locationId;
  final int vehicleTypeId;
  final bool isCircular;
  final String colourHex;
  final String comment;

  const RouteModel({
    required this.routeId,
    required this.name,
    required this.title,
    this.startEndStations = '',
    this.endStation = '',
    this.locationId = 1,
    this.vehicleTypeId = 2,
    this.isCircular = false,
    this.colourHex = '',
    this.comment = '',
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      routeId: json['route_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startEndStations: json['start_end_stations'] as String? ?? '',
      endStation: json['end_station'] as String? ?? '',
      locationId: json['location_id'] as int? ?? 1,
      vehicleTypeId: json['vehicle_type_id'] as int? ?? 2,
      isCircular: json['is_circular'] as bool? ?? false,
      colourHex: json['colour_hex'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'name': name,
      'title': title,
      'start_end_stations': startEndStations,
      'end_station': endStation,
      'location_id': locationId,
      'vehicle_type_id': vehicleTypeId,
      'is_circular': isCircular,
      'colour_hex': colourHex,
      'comment': comment,
    };
  }

  /// Получение начальной остановки из строки "Начало - Конец"
  String get startStation {
    if (startEndStations.contains(' - ')) {
      return startEndStations.split(' - ').first.trim();
    }
    if (title.contains(' - ')) {
      return title.split(' - ').first.trim();
    }
    return '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteModel &&
          runtimeType == other.runtimeType &&
          routeId == other.routeId;

  @override
  int get hashCode => routeId.hashCode;
}
