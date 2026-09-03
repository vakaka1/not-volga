import 'station_model.dart';

class RouteDetailsModel {
  final int routeId;
  final String name;
  final String title;
  final String startEndStations;
  final String endStation;
  final int locationId;
  final int vehicleTypeId;
  final bool isCircular;
  final List<StationModel> stations;

  const RouteDetailsModel({
    required this.routeId,
    required this.name,
    required this.title,
    this.startEndStations = '',
    this.endStation = '',
    this.locationId = 1,
    this.vehicleTypeId = 2,
    this.isCircular = false,
    this.stations = const [],
  });

  factory RouteDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawStations = json['stations'] as List<dynamic>? ?? [];
    final parsedStations = rawStations
        .map((s) => StationModel.fromJson(s as Map<String, dynamic>))
        .toList();

    return RouteDetailsModel(
      routeId: json['route_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startEndStations: json['start_end_stations'] as String? ?? '',
      endStation: json['end_station'] as String? ?? '',
      locationId: json['location_id'] as int? ?? 1,
      vehicleTypeId: json['vehicle_type_id'] as int? ?? 2,
      isCircular: json['is_circular'] as bool? ?? false,
      stations: parsedStations,
    );
  }

  String get startStation {
    if (stations.isNotEmpty) {
      return stations.first.name;
    }
    if (startEndStations.contains(' - ')) {
      return startEndStations.split(' - ').first.trim();
    }
    return '';
  }

  String get finalStation {
    if (endStation.isNotEmpty) {
      return endStation;
    }
    if (stations.isNotEmpty) {
      return stations.last.name;
    }
    return '';
  }
}
