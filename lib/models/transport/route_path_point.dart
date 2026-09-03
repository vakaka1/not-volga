class RoutePathPoint {
  final int routeId;
  final int order;
  final double lat;
  final double lng;
  final double distance;

  const RoutePathPoint({
    required this.routeId,
    required this.order,
    required this.lat,
    required this.lng,
    this.distance = 0.0,
  });

  factory RoutePathPoint.fromJson(Map<String, dynamic> json) {
    return RoutePathPoint(
      routeId: json['route_id'] as int? ?? 0,
      order: json['order'] as int? ?? 0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'order': order,
      'lat': lat,
      'lng': lng,
      'distance': distance,
    };
  }
}
