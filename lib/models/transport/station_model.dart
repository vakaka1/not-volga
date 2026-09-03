class StationModel {
  final int stationId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final int locationId;
  final String? externalId;

  const StationModel({
    required this.stationId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.locationId = 1,
    this.externalId,
  });

  factory StationModel.fromJson(Map<String, dynamic> json) {
    return StationModel(
      stationId: json['station_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      locationId: json['location_id'] as int? ?? 1,
      externalId: json['external_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'station_id': stationId,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'location_id': locationId,
      'external_id': externalId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationModel &&
          runtimeType == other.runtimeType &&
          stationId == other.stationId;

  @override
  int get hashCode => stationId.hashCode;
}
