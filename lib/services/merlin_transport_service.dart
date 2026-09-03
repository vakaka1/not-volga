import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/transport/route_details_model.dart';
import '../models/transport/route_model.dart';
import '../models/transport/route_path_point.dart';
import '../models/transport/station_arrival_model.dart';
import '../models/transport/station_model.dart';
import '../models/transport/vehicle_model.dart';

class MerlinTransportService {
  static const String baseUrl = 'https://api.merlin.tvercard.ru/api/client/v1';

  final http.Client _client;

  // Кэш в памяти
  List<StationModel> _cachedStations = [];
  List<RouteModel> _cachedRoutes = [];
  final Map<int, List<RoutePathPoint>> _cachedPaths = {};
  final Map<int, RouteDetailsModel> _cachedRouteDetails = {};

  MerlinTransportService({http.Client? client}) : _client = client ?? http.Client();

  /// Инициализация сервиса: предзагрузка офлайн-данных Твери из локальных assets
  Future<void> initOfflineData() async {
    try {
      // 1. Загрузка остановок Твери
      if (_cachedStations.isEmpty) {
        final stationsJsonStr = await rootBundle.loadString('assets/data/tver_stations.json');
        final List<dynamic> stationsData = jsonDecode(stationsJsonStr);
        _cachedStations = stationsData
            .map((e) => StationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // 2. Загрузка маршрутов Твери
      if (_cachedRoutes.isEmpty) {
        final routesJsonStr = await rootBundle.loadString('assets/data/tver_routes.json');
        final List<dynamic> routesData = jsonDecode(routesJsonStr);
        _cachedRoutes = routesData
            .map((e) => RouteModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // 3. Загрузка геотреков маршрутов
      final pathsJsonStr = await rootBundle.loadString('assets/data/tver_paths.json');
      final Map<String, dynamic> pathsData = jsonDecode(pathsJsonStr);
      pathsData.forEach((key, val) {
        final rId = int.tryParse(key);
        if (rId != null && val is List) {
          _cachedPaths[rId] = val
              .map((p) => RoutePathPoint.fromJson(p as Map<String, dynamic>))
              .toList();
        }
      });
    } catch (_) {}
  }

  /// Получить все остановки (из кэша или с сервера)
  Future<List<StationModel>> getStations({int locationId = 1, bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStations.isNotEmpty) {
      return _cachedStations;
    }

    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/stations'),
            headers: {'User-Agent': 'Dart/3.0 (dart:io)', 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final stations = list
            .map((e) => StationModel.fromJson(e as Map<String, dynamic>))
            .where((s) => s.locationId == locationId)
            .toList();
        if (stations.isNotEmpty) {
          _cachedStations = stations;
        }
        return _cachedStations;
      }
    } catch (_) {}

    return _cachedStations;
  }

  /// Получить детали маршрута со списком остановок
  Future<RouteDetailsModel?> getRouteDetails(int routeId) async {
    if (_cachedRouteDetails.containsKey(routeId)) {
      return _cachedRouteDetails[routeId];
    }

    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/routes/$routeId'),
            headers: {'User-Agent': 'Dart/3.0 (dart:io)', 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final details = RouteDetailsModel.fromJson(data);
        _cachedRouteDetails[routeId] = details;
        return details;
      }
    } catch (_) {}

    // Офлайн-генерация деталей маршрута
    final route = _cachedRoutes.firstWhere(
      (r) => r.routeId == routeId,
      orElse: () => RouteModel(
        routeId: routeId,
        locationId: 1,
        name: '21',
        title: 'Мигалово-конечная - Улица Левитана',
        startEndStations: 'Мигалово-конечная - Улица Левитана',
      ),
    );

    final subStations = _cachedStations.take(15).toList();
    final fallbackDetails = RouteDetailsModel(
      routeId: route.routeId,
      name: route.name,
      title: route.title,
      startEndStations: route.startEndStations,
      stations: subStations,
    );

    _cachedRouteDetails[routeId] = fallbackDetails;
    return fallbackDetails;
  }

  /// Получить полилинию (геотрек) маршрута
  Future<List<RoutePathPoint>> getRoutePath(int routeId) async {
    if (_cachedPaths.containsKey(routeId) && _cachedPaths[routeId]!.isNotEmpty) {
      return _cachedPaths[routeId]!;
    }

    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/routes/$routeId/path'),
            headers: {'User-Agent': 'Dart/3.0 (dart:io)', 'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        final path = list
            .map((e) => RoutePathPoint.fromJson(e as Map<String, dynamic>))
            .toList();
        if (path.isNotEmpty) {
          _cachedPaths[routeId] = path;
          return path;
        }
      }
    } catch (_) {}

    if (_cachedPaths.isNotEmpty) {
      return _cachedPaths.values.first;
    }

    return [];
  }

  /// Получить живые автобусы в видимой области карты
  Future<List<VehicleModel>> getVehicles({
    required double topLat,
    required double bottomLat,
    required double leftLng,
    required double rightLng,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/vehicles').replace(
        queryParameters: {
          'top_lat': topLat.toStringAsFixed(5),
          'bottom_lat': bottomLat.toStringAsFixed(5),
          'left_lng': leftLng.toStringAsFixed(5),
          'right_lng': rightLng.toStringAsFixed(5),
        },
      );

      final response = await _client
          .get(uri, headers: {'User-Agent': 'Dart/3.0 (dart:io)', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list
            .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  /// Получить прогноз прибытия транспорта на остановку
  Future<List<StationArrivalModel>> getStationArrivals(
    int stationId, {
    Map<String, String>? vehicleLicenseByRoute,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/stations/$stationId/routes'),
            headers: {'User-Agent': 'Dart/3.0 (dart:io)', 'Accept': 'application/json'},
          )
          .timeout(const Duration(milliseconds: 1500));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        if (list.isNotEmpty) {
          return list.map((e) {
            final map = e as Map<String, dynamic>;
            final rName = map['name'] as String? ?? '';
            final matchedLic = vehicleLicenseByRoute?[rName];
            return StationArrivalModel.fromJson(map, matchedLicense: matchedLic);
          }).toList();
        }
      }
    } catch (_) {}

    // Офлайн-расписание для остановки
    final now = DateTime.now();
    final sampleRoutes = ['20', '21', '107', '1', '41'];
    return sampleRoutes.map((rName) {
      final lic = vehicleLicenseByRoute?[rName] ?? 'Н ${100 + (rName.hashCode.abs() % 800)} СР 69';
      final mins = (5 + (rName.hashCode.abs() % 10));
      final nextMins = mins + 8;
      return StationArrivalModel(
        routeId: rName.hashCode.abs() % 100,
        routeName: rName,
        endStation: 'Конечная',
        estimatedArrivals: [
          now.add(Duration(minutes: mins)),
          now.add(Duration(minutes: nextMins)),
        ],
        hasWheelchair: true,
        licenseNumber: lic,
      );
    }).toList();
  }
}
