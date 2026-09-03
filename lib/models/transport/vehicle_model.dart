class VehicleModel {
  final String vehicleId;
  final String boardNumber;
  final String licenseNumber;
  final String model;
  final int routeId;
  final String routeName;
  final int locationId;
  final int vehicleTypeId;
  final double lat;
  final double lng;
  final int speed;
  final double course;
  final int? nextStationId;
  final String nextStationName;
  final bool hasWheelchair;
  final String? qrNumber;
  final String? qrUuid;
  final DateTime? timeLocation;
  final String carrierName;

  const VehicleModel({
    required this.vehicleId,
    required this.boardNumber,
    required this.licenseNumber,
    required this.model,
    required this.routeId,
    required this.routeName,
    this.locationId = 1,
    this.vehicleTypeId = 2,
    required this.lat,
    required this.lng,
    this.speed = 0,
    this.course = 0.0,
    this.nextStationId,
    this.nextStationName = '',
    this.hasWheelchair = true,
    this.qrNumber,
    this.qrUuid,
    this.timeLocation,
    this.carrierName = '',
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    final nextStationObj = json['next_station'] as Map<String, dynamic>?;
    final nextStationName = nextStationObj?['name'] as String? ?? '';
    final qrVehicleObj = json['qr_vehicle'] as Map<String, dynamic>?;
    final qrNumber = qrVehicleObj?['qr_number'] as String?;
    final qrUuid = qrVehicleObj?['qr_uuid'] as String?;

    DateTime? parsedTime;
    final timeStr = json['time_location'] as String?;
    if (timeStr != null) {
      try {
        parsedTime = DateTime.parse(timeStr);
      } catch (_) {}
    }

    final carrierObj = json['carrier'] as Map<String, dynamic>?;
    final carrierName = carrierObj?['name'] as String? ??
        (json['carrier_name'] as String? ??
            (json['carrier'] is String ? json['carrier'] as String : ''));

    return VehicleModel(
      vehicleId: json['vehicle_id'] as String? ?? '',
      boardNumber: json['board_number'] as String? ?? '',
      licenseNumber: json['license_number'] as String? ?? '',
      model: json['model'] as String? ?? 'ЛиАЗ 429260',
      routeId: json['route_id'] as int? ?? 0,
      routeName: json['route_name'] as String? ?? '',
      locationId: json['location_id'] as int? ?? 1,
      vehicleTypeId: json['vehicle_type_id'] as int? ?? 2,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toInt() ?? 0,
      course: (json['course'] as num?)?.toDouble() ?? 0.0,
      nextStationId: json['next_station_id'] as int?,
      nextStationName: nextStationName,
      hasWheelchair: true, // В Твери все современные автобусы «Транспорта Верхневолжья» оборудованы пандусом
      qrNumber: qrNumber,
      qrUuid: qrUuid,
      timeLocation: parsedTime,
      carrierName: carrierName,
    );
  }

  /// Форматированный госномер для плашки (например, "О 113 СР  69")
  String get formattedLicenseNumber {
    final clean = licenseNumber.replaceAll(' ', '').toUpperCase();
    if (clean.length >= 8) {
      final letter1 = clean.substring(0, 1);
      final digits = clean.substring(1, 4);
      final letter23 = clean.substring(4, 6);
      final region = clean.substring(6);
      return '$letter1 $digits $letter23  $region';
    }
    return licenseNumber;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleModel &&
          runtimeType == other.runtimeType &&
          vehicleId == other.vehicleId;

  @override
  int get hashCode => vehicleId.hashCode;
}
