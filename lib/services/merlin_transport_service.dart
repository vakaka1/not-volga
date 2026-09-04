import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/transport/route_details_model.dart';
import '../models/transport/route_model.dart';
import '../models/transport/route_path_point.dart';
import '../models/transport/station_arrival_model.dart';
import '../models/transport/station_model.dart';
import '../models/transport/vehicle_model.dart';
import '../services/qr_payload_parser.dart';
import '../widgets/payment_confirmation_sheet.dart';
import '../services/tariff_service.dart';

class MerlinTransportService {
  static const String baseUrl = 'https://api.merlin.tvercard.ru/api/client/v1';

  static final MerlinTransportService _instance = MerlinTransportService._internal();
  factory MerlinTransportService({http.Client? client}) {
    if (client != null) {
      return MerlinTransportService._internal(client: client);
    }
    return _instance;
  }
  MerlinTransportService._internal({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Кэш в памяти
  List<StationModel> _cachedStations = [];
  List<RouteModel> _cachedRoutes = [];
  final Map<int, List<RoutePathPoint>> _cachedPaths = {};
  final Map<int, RouteDetailsModel> _cachedRouteDetails = {};

  List<StationModel> get cachedStations => _cachedStations;
  List<RouteModel> get cachedRoutes => _cachedRoutes;

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
      if (_cachedPaths.isEmpty) {
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
      }

      // 4. Загрузка всех деталей маршрутов с реальными остановками Твери
      if (_cachedRouteDetails.isEmpty) {
        final detailsJsonStr = await rootBundle.loadString('assets/data/tver_route_details.json');
        final Map<String, dynamic> detailsData = jsonDecode(detailsJsonStr);
        detailsData.forEach((key, val) {
          final rId = int.tryParse(key);
          if (rId != null && val is Map<String, dynamic>) {
            _cachedRouteDetails[rId] = RouteDetailsModel.fromJson(val);
          }
        });
      }
    } catch (_) {}
  }

  /// Предзагрузка деталей всех маршрутов для офлайн-режима
  Future<void> preCacheAllRouteDetails() async {
    for (final route in _cachedRoutes) {
      if (!_cachedRouteDetails.containsKey(route.routeId)) {
        try {
          await getRouteDetails(route.routeId);
        } catch (_) {}
      }
    }
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
  Future<RouteDetailsModel?> getRouteDetails(int routeId, {bool preferOffline = false}) async {
    if (_cachedRouteDetails.containsKey(routeId)) {
      return _cachedRouteDetails[routeId];
    }

    if (!preferOffline) {
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
    }

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

    final fallbackDetails = RouteDetailsModel(
      routeId: route.routeId,
      name: route.name,
      title: route.title,
      startEndStations: route.startEndStations,
      stations: [],
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

  /// Расчёт расстояния между двумя остановками маршрута (в км)
  double computeDistanceBetweenStations(int routeId, String fromStation, String toStation) {
    StationModel? from;
    StationModel? to;
    
    // 1. Ищем в деталях конкретного маршрута
    final details = _cachedRouteDetails[routeId];
    if (details != null) {
      for (final s in details.stations) {
        if (s.name == fromStation && from == null) from = s;
        if (s.name == toStation && to == null) to = s;
      }
    }
    
    // 2. Если не найдены — ищем по всем деталям маршрутов
    if (from == null || to == null) {
      for (final d in _cachedRouteDetails.values) {
        for (final s in d.stations) {
          if (s.name == fromStation && from == null) from = s;
          if (s.name == toStation && to == null) to = s;
        }
        if (from != null && to != null) break;
      }
    }

    // 3. Если всё ещё не найдены — ищем в общем реестре остановок
    if (from == null || to == null) {
      for (final s in _cachedStations) {
        if (s.name == fromStation && from == null) from = s;
        if (s.name == toStation && to == null) to = s;
      }
    }

    if (from == null || to == null) return 0.0;
    return TariffService.haversineDistanceKm(from.lat, from.lng, to.lat, to.lng);
  }

  /// Поиск деталей маршрута по имени (номеру) маршрута
  RouteDetailsModel? getRouteDetailsByName(String routeName) {
    final clean = routeName.replaceAll('№', '').trim();
    for (final details in _cachedRouteDetails.values) {
      if (details.name.toLowerCase() == clean.toLowerCase() && details.stations.isNotEmpty) {
        return details;
      }
    }
    return null;
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
        final vehicles = list
            .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _cachedVehicles = vehicles;
        return vehicles;
      }
    } catch (_) {}

    return [];
  }

  List<VehicleModel> _cachedVehicles = [];
  List<VehicleModel> get cachedVehicles => _cachedVehicles;

  VehicleModel? getLiveVehicleForRoute(String routeName) {
    final clean = routeName.replaceAll('№', '').trim();
    for (final v in _cachedVehicles) {
      if (v.routeName == clean && v.licenseNumber.isNotEmpty) {
        return v;
      }
    }
    return null;
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
          final arrivals = list.map((e) {
            final map = e as Map<String, dynamic>;
            final rName = map['name'] as String? ?? '';
            final matchedLic = vehicleLicenseByRoute?[rName];
            return StationArrivalModel.fromJson(map, matchedLicense: matchedLic);
          }).toList();

          arrivals.sort((a, b) {
            final aTime = a.estimatedArrivals.isNotEmpty ? a.estimatedArrivals.first : null;
            final bTime = b.estimatedArrivals.isNotEmpty ? b.estimatedArrivals.first : null;
            if (aTime != null && bTime != null) {
              return aTime.compareTo(bTime);
            } else if (aTime != null) {
              return -1;
            } else if (bTime != null) {
              return 1;
            }
            return a.routeName.compareTo(b.routeName);
          });

          return arrivals;
        }
      }
    } catch (_) {}

    return [];
  }

  /// Проверка доступности API (пингуем легковесный эндпоинт)
  Future<bool> pingApi({Duration timeout = const Duration(milliseconds: 1500)}) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/locations'),
            headers: {'User-Agent': 'Dart/3.0 (dart:io)', 'Accept': 'application/json'},
          )
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Определение транспорта с защитой от отсутствия интернета (до 5 попыток)
  Future<({bool isApiAvailable, ScannedTransportInfo? transportInfo})> resolveVehicleWithRetry(
    String rawQrData, {
    int maxAttempts = 5,
    void Function(int attempt, int maxAttempts)? onAttempt,
  }) async {
    bool apiAvailable = false;
    ScannedTransportInfo? transportInfo;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      onAttempt?.call(attempt, maxAttempts);
      final isOnline = await pingApi();
      if (isOnline) {
        apiAvailable = true;
        transportInfo = await resolveVehicleForPayment(rawQrData);
        break;
      }
      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return (isApiAvailable: apiAvailable, transportInfo: transportInfo);
  }

  /// Определение транспорта и подготовка данных для покупки билета по QR-коду
  Future<ScannedTransportInfo?> resolveVehicleForPayment(
    String rawQrData, {
    int locationId = 1,
  }) async {
    final parsed = QrPayloadParser.parse(rawQrData);

    // Если QR-код не содержит идентификаторов транспорта и не относится к tvercard
    if (!parsed.hasIdentifier && !rawQrData.toLowerCase().contains('tvercard')) {
      return null;
    }

    // 1. Инициализируем локальные данные маршрутов и остановок
    await initOfflineData();

    // 2. Опрашиваем живые автобусы по всей Тверской области
    List<VehicleModel> liveVehicles = [];
    try {
      liveVehicles = await getVehicles(
        topLat: 59.5,
        bottomLat: 55.0,
        leftLng: 30.0,
        rightLng: 39.0,
      );
    } catch (_) {}

    VehicleModel? matchedVehicle;

    // 3. Поиск по живым автобусам Твери
    if (parsed.uuid != null) {
      for (final v in liveVehicles) {
        if (v.vehicleId.toLowerCase() == parsed.uuid ||
            (v.qrUuid != null && v.qrUuid!.toLowerCase() == parsed.uuid)) {
          matchedVehicle = v;
          break;
        }
      }
    }

    if (matchedVehicle == null && parsed.qrNumber != null) {
      for (final v in liveVehicles) {
        if (v.qrNumber != null && v.qrNumber!.toLowerCase() == parsed.qrNumber!.toLowerCase()) {
          matchedVehicle = v;
          break;
        }
      }
    }

    if (matchedVehicle == null && parsed.boardNumber != null) {
      for (final v in liveVehicles) {
        if (v.boardNumber == parsed.boardNumber) {
          matchedVehicle = v;
          break;
        }
      }
    }

    if (matchedVehicle == null && parsed.routeNumber != null) {
      for (final v in liveVehicles) {
        if (v.routeName == parsed.routeNumber) {
          matchedVehicle = v;
          break;
        }
      }
    }

    // Если найден активный автобус на линии в Твери
    if (matchedVehicle != null) {
      final routeDetails = await getRouteDetails(matchedVehicle.routeId);
      final rawRouteName = matchedVehicle.routeName;
      final routeDigits = int.tryParse(rawRouteName.replaceAll(RegExp(r'\D'), ''));
      final isIntercity = (routeDigits != null && routeDigits >= 100) || rawRouteName.length >= 3;

      final stations = routeDetails?.stations.map((s) => s.name).toList() ?? [];
      String currentStop = matchedVehicle.nextStationName;
      if (routeDetails != null && routeDetails.stations.isNotEmpty) {
        try {
          final pos = await Geolocator.getLastKnownPosition().timeout(const Duration(milliseconds: 300));
          if (pos != null) {
            double minDist = double.infinity;
            String closestName = '';
            for (final st in routeDetails.stations) {
              final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, st.lat, st.lng);
              if (d < minDist) {
                minDist = d;
                closestName = st.name;
              }
            }
            if (minDist < 1000 && closestName.isNotEmpty) {
              currentStop = closestName;
            }
          }
        } catch (_) {}
      }
      if (currentStop.isEmpty) {
        currentStop = matchedVehicle.nextStationName.isNotEmpty
            ? matchedVehicle.nextStationName
            : (stations.isNotEmpty ? stations.first : '');
      }

      final endStation = routeDetails?.finalStation.isNotEmpty == true
          ? routeDetails!.finalStation
          : (stations.isNotEmpty ? stations.last : 'Конечная');

      final routeTitle = routeDetails?.title.isNotEmpty == true
          ? routeDetails!.title
          : (routeDetails?.startEndStations.isNotEmpty == true
              ? routeDetails!.startEndStations
              : 'Маршрут №${matchedVehicle.routeName}');

      final carrier = matchedVehicle.carrierName.isNotEmpty
          ? matchedVehicle.carrierName
          : 'ООО "Верхневолжское автотранспортное предприятие"';

      return ScannedTransportInfo(
        routeNumber: '№${matchedVehicle.routeName}',
        routeTitle: routeTitle,
        transportType: matchedVehicle.model,
        regNumber: matchedVehicle.formattedLicenseNumber,
        carrier: carrier,
        city: 'Тверь',
        fare: 0,
        rawQrData: rawQrData,
        isIntercity: isIntercity,
        startStation: currentStop,
        endStation: endStation,
        availableStations: stations.isNotEmpty ? stations : [currentStop, endStation],
        routeId: matchedVehicle.routeId,
        isLiveVehicle: true,
        boardNumber: matchedVehicle.boardNumber,
      );
    }

    // 4. Офлайн Fallback (если автобус не на линии в GPS-потоке)
    String route = '';
    String reg = '';
    String type = '';
    int rId = 0;
    bool isIntercity = false;
    String startStation = '';
    String endStation = '';
    String routeTitle = 'Выберите маршрут';
    List<String> stations = [];

    if (parsed.routeNumber != null) {
      final numStr = parsed.routeNumber!;
      route = numStr.startsWith('№') ? numStr : '№$numStr';
      final digits = int.tryParse(numStr.replaceAll(RegExp(r'\D'), ''));
      isIntercity = (digits != null && digits >= 100) || numStr.length >= 3;

      final cleanRouteName = route.replaceAll('№', '').trim();
      final matchingRoute = _cachedRoutes.firstWhere(
        (r) => r.name == cleanRouteName,
        orElse: () => const RouteModel(routeId: 0, name: '', title: ''),
      );

      if (matchingRoute.routeId != 0) {
        rId = matchingRoute.routeId;
        final routeDetails = await getRouteDetails(rId);
        routeTitle = routeDetails?.title.isNotEmpty == true
            ? routeDetails!.title
            : (matchingRoute.title.isNotEmpty ? matchingRoute.title : 'Маршрут №$cleanRouteName');
        stations = routeDetails?.stations.map((s) => s.name).toList() ?? [];
        if (routeDetails?.finalStation.isNotEmpty == true) {
          endStation = routeDetails!.finalStation;
        }
      }
    }

    return ScannedTransportInfo(
      routeNumber: route,
      routeTitle: routeTitle,
      transportType: type,
      regNumber: reg,
      carrier: '',
      city: 'Тверь',
      fare: 0,
      rawQrData: rawQrData,
      isIntercity: isIntercity,
      startStation: startStation,
      endStation: endStation,
      availableStations: stations,
      routeId: rId,
      isLiveVehicle: false,
    );
  }
}

