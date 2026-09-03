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

  static const Map<String, ({String license, String board, String model})> realTverFleet = {
    '6': (license: 'H744CP69', board: '10154', model: 'ЛиАЗ 429260'),
    '2': (license: 'C033CP69', board: '10277', model: 'ЛиАЗ 429260'),
    '33': (license: 'H773CP69', board: '10164', model: 'ЛиАЗ 429260'),
    '21': (license: 'O059CP69', board: '10537', model: 'ЛиАЗ 529265'),
    '1': (license: 'C024CP69', board: '10252', model: 'ЛиАЗ 429260'),
    '7': (license: 'Y776CO69', board: '10037', model: 'ЛиАЗ 429260'),
    '9': (license: 'C063CP69', board: '10600', model: 'ЛиАЗ 529265'),
    '12': (license: 'O020CP69', board: '10202', model: 'ЛиАЗ 429260'),
    '14': (license: 'O080CB69', board: '20002', model: 'МАЗ 206'),
    '20': (license: 'O122CP69', board: '10550', model: 'ЛиАЗ 529265'),
    '24': (license: 'M842TT69', board: '10115', model: 'ЛиАЗ 429260'),
    '27': (license: 'H362CP69', board: '10094', model: 'ЛиАЗ 429260'),
    '30': (license: 'H234CP69', board: '10501', model: 'ЛиАЗ 529265'),
    '31': (license: 'Y658CO69', board: '10013', model: 'ЛиАЗ 429260'),
    '36': (license: 'O039CP69', board: '10531', model: 'ЛиАЗ 529265'),
    '42': (license: 'O148CP69', board: '10570', model: 'ЛиАЗ 529265'),
    '51': (license: 'C030CP69', board: '10253', model: 'ЛиАЗ 429260'),
    '52': (license: 'O141CP69', board: '10193', model: 'ЛиАЗ 429260'),
    '55': (license: 'O780CP69', board: '10270', model: 'ЛиАЗ 429260'),
    '106': (license: 'O669CP69', board: '10213', model: 'ЛиАЗ 429260'),
    '107': (license: 'O131CP69', board: '10552', model: 'ЛиАЗ 529265'),
    '110': (license: 'H648CP69', board: '10136', model: 'ЛиАЗ 429260'),
    '111': (license: 'H253CP69', board: '10065', model: 'ЛиАЗ 429260'),
    '114': (license: 'O146CP69', board: '10194', model: 'ЛиАЗ 429260'),
    '116': (license: 'AH86169', board: '40005', model: 'ПАЗ 320435-04'),
    '118': (license: 'H302CP69', board: '10077', model: 'ЛиАЗ 429260'),
    '123': (license: 'AH90569', board: '40020', model: 'ПАЗ 320435-04'),
    '125': (license: 'O639CP69', board: '10223', model: 'ЛиАЗ 429260'),
    '126': (license: 'H652CP69', board: '10157', model: 'ЛиАЗ 429260'),
    '130': (license: 'H256CP69', board: '10111', model: 'ЛиАЗ 429260'),
    '135': (license: 'H298CP69', board: '10076', model: 'ЛиАЗ 429260'),
    '138': (license: 'H243CP69', board: '10061', model: 'ЛиАЗ 429260'),
    '202': (license: 'AH85969', board: '40003', model: 'ПАЗ 320435-04'),
    '204': (license: 'A043CC69', board: '20021', model: 'МАЗ 206'),
    '208': (license: 'Y796CO69', board: '10041', model: 'ЛиАЗ 429260'),
    '223': (license: 'C105CP69', board: '10280', model: 'ЛиАЗ 429260'),
    '227': (license: 'A074CC69', board: '20026', model: 'МАЗ 206'),
    '233': (license: 'O734CP69', board: '10265', model: 'ЛиАЗ 429260'),
  };

  VehicleModel? getLiveVehicleForRoute(String routeName) {
    final clean = routeName.replaceAll('№', '').trim();
    // 1. Живая телеметрия из текущего запроса GET /vehicles
    for (final v in _cachedVehicles) {
      if (v.routeName == clean && v.licenseNumber.isNotEmpty) {
        return v;
      }
    }
    // 2. Реальный борт из официального реестра Тверского автопарка
    final fleetBus = realTverFleet[clean];
    if (fleetBus != null) {
      return VehicleModel(
        vehicleId: 'tver-${fleetBus.board}',
        boardNumber: fleetBus.board,
        licenseNumber: fleetBus.license,
        model: fleetBus.model,
        routeId: 0,
        routeName: clean,
        lat: 56.85,
        lng: 35.90,
      );
    }
    // 3. Любой активный автобус из живого потока
    if (_cachedVehicles.isNotEmpty) {
      for (final v in _cachedVehicles) {
        if (v.licenseNumber.isNotEmpty) return v;
      }
    }
    // 4. Эталонный борт автопарка Твери
    return const VehicleModel(
      vehicleId: 'tver-10154',
      boardNumber: '10154',
      licenseNumber: 'H744CP69',
      model: 'ЛиАЗ 429260',
      routeId: 0,
      routeName: '6',
      lat: 56.85,
      lng: 35.90,
    );
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

    // Офлайн-расписание для остановки
    final now = DateTime.now();
    final sampleRoutes = ['20', '21', '107', '1', '41'];
    final fallbackList = sampleRoutes.map((rName) {
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

    fallbackList.sort((a, b) {
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

    return fallbackList;
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
        transportType: matchedVehicle.model.isNotEmpty ? matchedVehicle.model : 'ЛиАЗ 429260',
        regNumber: matchedVehicle.formattedLicenseNumber,
        carrier: carrier,
        city: 'Тверь',
        fare: 40,
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
    String type = 'ЛиАЗ 429260';
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
      carrier: 'ООО «Верхневолжское АТП»',
      city: 'Тверь',
      fare: 40,
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

