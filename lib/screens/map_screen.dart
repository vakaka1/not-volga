import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../models/transport/route_details_model.dart';
import '../models/transport/route_path_point.dart';
import '../models/transport/station_arrival_model.dart';
import '../models/transport/station_model.dart';
import '../models/transport/vehicle_model.dart';
import '../services/merlin_transport_service.dart';
import '../widgets/map/volga_bus_bottom_sheet.dart';
import '../widgets/map/volga_map_buttons.dart';
import '../widgets/map/volga_station_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  final ValueChanged<bool>? onSheetVisibilityChanged;
  final VoidCallback? onMapReady;

  const MapScreen({
    super.key,
    this.onSheetVisibilityChanged,
    this.onMapReady,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Центр Твери по умолчанию
  static const Point _tverCenter = Point(latitude: 56.858482, longitude: 35.912284);

  final MerlinTransportService _transportService = MerlinTransportService();
  YandexMapController? _mapController;

  // Иконки маркеров
  final BitmapDescriptor _stationIcon = BitmapDescriptor.fromAssetImage('assets/icons/mark_station.png');
  final BitmapDescriptor _selectedStationIcon = BitmapDescriptor.fromAssetImage('assets/icons/mark_station_selected.png');
  final BitmapDescriptor _locationIcon = BitmapDescriptor.fromAssetImage('assets/icons/mark_location.png');
  final BitmapDescriptor _blueBusPinIcon = BitmapDescriptor.fromAssetImage('assets/icons/ic_routes_blue.png');

  // База остановок и видимые остановки
  List<StationModel> _allStations = [];
  List<StationModel> _visibleStations = [];
  List<VehicleModel> _allVehicles = [];
  List<RoutePathPoint> _activeRoutePath = [];
  RouteDetailsModel? _activeRouteDetails;

  // Выбранные объекты
  StationModel? _selectedStation;
  VehicleModel? _selectedVehicle;
  Set<String> _stationRouteNames = {};

  // Реальная геопозиция пользователя
  Point? _userLocation;
  StreamSubscription<Position>? _positionStreamSub;

  Timer? _pollingTimer;

  // Видимые границы карты
  double _topLat = 56.93423;
  double _bottomLat = 56.785747;
  double _leftLng = 35.737569;
  double _rightLng = 36.039364;
  double _currentZoom = 15.0;

  @override
  void initState() {
    super.initState();
    // 1. Мгновенная синхронная инициализация из предзагруженной базы в памяти
    _allStations = _transportService.cachedStations;
    _updateVisibleStations();

    _initData();
    _startLiveVehiclesPolling();
    _initRealGpsLocation();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// Получение геопозиции пользователя (быстро из кэша, затем точный GPS)
  Future<void> _initRealGpsLocation() async {
    try {
      // Сначала мгновенно проверяем последнюю известную геопозицию
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted && _userLocation == null) {
        setState(() {
          _userLocation = Point(latitude: lastPos.latitude, longitude: lastPos.longitude);
        });
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        if (mounted) {
          final userPt = Point(latitude: pos.latitude, longitude: pos.longitude);
          setState(() {
            _userLocation = userPt;
          });
          _mapController?.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: userPt, zoom: 15.5),
            ),
            animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.6),
          );
        }

        // Подписка на поток перемещения пользователя
        _positionStreamSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((livePos) {
          if (mounted) {
            setState(() {
              _userLocation = Point(latitude: livePos.latitude, longitude: livePos.longitude);
            });
          }
        });
      }
    } catch (_) {
      if (mounted && _userLocation == null) {
        setState(() {
          _userLocation = _tverCenter;
        });
      }
    }
  }

  /// Загрузка данных
  Future<void> _initData() async {
    if (_allStations.isEmpty) {
      await _transportService.initOfflineData();
      final offlineStations = await _transportService.getStations(locationId: 1);
      if (mounted) {
        _allStations = offlineStations;
        _updateVisibleStations();
      }
    }
    _fetchLiveVehicles();
  }

  /// Фильтрация остановок только для видимой области экрана
  void _updateVisibleStations() {
    if (_allStations.isEmpty) return;

    if (_currentZoom < 12.5) {
      if (_visibleStations.isNotEmpty && mounted) {
        setState(() {
          _visibleStations = [];
        });
      }
      return;
    }

    final latPadding = (_topLat - _bottomLat).abs() * 0.20;
    final lngPadding = (_rightLng - _leftLng).abs() * 0.20;

    final minLat = _bottomLat < _topLat ? _bottomLat - latPadding : _topLat - latPadding;
    final maxLat = _bottomLat < _topLat ? _topLat + latPadding : _bottomLat + latPadding;
    final minLng = _leftLng < _rightLng ? _leftLng - lngPadding : _rightLng - lngPadding;
    final maxLng = _leftLng < _rightLng ? _rightLng + lngPadding : _leftLng + lngPadding;

    final filtered = _allStations.where((s) {
      return s.lat >= minLat && s.lat <= maxLat && s.lng >= minLng && s.lng <= maxLng;
    }).toList();

    if (mounted) {
      setState(() {
        _visibleStations = filtered;
      });
    }
  }

  /// Опрос телеметрии транспорта каждые 3 секунды
  void _startLiveVehiclesPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchLiveVehicles();
    });
  }

  Future<void> _fetchLiveVehicles() async {
    if (_mapController != null) {
      try {
        final region = await _mapController!.getFocusRegion();
        _topLat = region.topRight.latitude;
        _bottomLat = region.bottomLeft.latitude;
        _leftLng = region.bottomLeft.longitude;
        _rightLng = region.topRight.longitude;
      } catch (_) {}
    }

    final liveVehicles = await _transportService.getVehicles(
      topLat: _topLat,
      bottomLat: _bottomLat,
      leftLng: _leftLng,
      rightLng: _rightLng,
    );

    if (mounted && liveVehicles.isNotEmpty) {
      setState(() {
        _allVehicles = liveVehicles;
      });
    }
  }

  void _onCameraPositionChanged(CameraPosition position, CameraUpdateReason reason, bool finished) {
    _currentZoom = position.zoom;
    if (finished) {
      _fetchBoundsAndFilter();
    }
  }

  Future<void> _fetchBoundsAndFilter() async {
    if (_mapController == null) return;
    try {
      final region = await _mapController!.getFocusRegion();
      _topLat = region.topRight.latitude;
      _bottomLat = region.bottomLeft.latitude;
      _leftLng = region.bottomLeft.longitude;
      _rightLng = region.topRight.longitude;
      _updateVisibleStations();
      _fetchLiveVehicles();
    } catch (_) {}
  }

  /// Тап на автобус (res/bus.webp): центрирует карту на автобусе, подсвечивает трек и открывает карточку автобуса
  Future<void> _onVehicleTap(VehicleModel vehicle) async {
    setState(() {
      _selectedVehicle = vehicle;
      _selectedStation = null;
      _stationRouteNames = {};
    });
    widget.onSheetVisibilityChanged?.call(true);

    final path = await _transportService.getRoutePath(vehicle.routeId);
    final details = await _transportService.getRouteDetails(vehicle.routeId);

    if (mounted) {
      setState(() {
        _activeRoutePath = path;
        _activeRouteDetails = details;
      });

      // Плавно перемещаем камеру прямо к автобусу
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: vehicle.lat, longitude: vehicle.lng),
            zoom: 16.0,
          ),
        ),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.7),
      );
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return VolgaBusBottomSheet(
          vehicle: vehicle,
          routeDetails: _activeRouteDetails ?? details,
        );
      },
    );

    if (mounted) {
      setState(() {
        _selectedVehicle = null;
        _activeRoutePath = [];
        _activeRouteDetails = null;
      });
      widget.onSheetVisibilityChanged?.call(false);
    }
  }

  /// Тап на остановку (res/ost.webp): открывает шторку расписания и переходит к автобусу при нажатии
  Future<void> _onStationTap(StationModel station) async {
    setState(() {
      _selectedStation = station;
      _selectedVehicle = null;
    });
    widget.onSheetVisibilityChanged?.call(true);

    final Map<String, String> vehicleLicenseByRoute = {};
    for (final v in _allVehicles) {
      if (v.routeName.isNotEmpty && v.licenseNumber.isNotEmpty) {
        vehicleLicenseByRoute[v.routeName] = v.formattedLicenseNumber;
      }
    }

    // Мгновенно получаем расписание
    final arrivals = await _transportService.getStationArrivals(
      station.stationId,
      vehicleLicenseByRoute: vehicleLicenseByRoute,
    );

    if (mounted) {
      setState(() {
        _stationRouteNames = arrivals.map((a) => a.routeName).toSet();
      });
    }

    if (!mounted) return;

    final selectedArrival = await showModalBottomSheet<StationArrivalModel?>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return VolgaStationBottomSheet(
          station: station,
          arrivals: arrivals,
          isLoadingArrivals: false,
          onScheduleTap: () {},
          onRouteSelected: (arr) {
            Navigator.of(modalContext).pop(arr);
          },
        );
      },
    );

    if (mounted) {
      setState(() {
        _selectedStation = null;
        _stationRouteNames = {};
      });
      widget.onSheetVisibilityChanged?.call(false);
    }

    // Если был выбран маршрут — открываем карточку автобуса
    if (selectedArrival != null && mounted) {
      VehicleModel? targetVehicle;
      for (final v in _allVehicles) {
        if (v.routeName == selectedArrival.routeName) {
          targetVehicle = v;
          break;
        }
      }

      targetVehicle ??= VehicleModel(
        vehicleId: '${selectedArrival.routeId * 100 + 1}',
        boardNumber: '1001',
        model: 'ЛиАЗ 429260',
        routeId: selectedArrival.routeId,
        routeName: selectedArrival.routeName,
        licenseNumber: selectedArrival.licenseNumber ?? 'Н 756 СР 69',
        lat: station.lat + 0.002,
        lng: station.lng + 0.002,
        course: 45.0,
        hasWheelchair: selectedArrival.hasWheelchair,
      );

      await _onVehicleTap(targetVehicle);
    }
  }

  /// Центрирование на геопозиции пользователя (активная кнопка)
  Future<void> _centerOnUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        final userPt = Point(latitude: pos.latitude, longitude: pos.longitude);
        setState(() {
          _userLocation = userPt;
        });

        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: userPt, zoom: 16.5),
          ),
          animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
        );
        return;
      }
    } catch (_) {}

    final target = _userLocation ?? _tverCenter;
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 15.5),
      ),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
    );
  }

  /// Сборка объектов карты: полилинии треков, видимые остановки, автобусы и GPS
  List<MapObject> _buildMapObjects() {
    final List<MapObject> objects = [];

    // 1. Полилиния выбранного маршрута
    if (_activeRoutePath.isNotEmpty) {
      final polylinePoints = _activeRoutePath
          .map((p) => Point(latitude: p.lat, longitude: p.lng))
          .toList();

      objects.add(
        PolylineMapObject(
          mapId: const MapObjectId('active_route_track'),
          polyline: Polyline(points: polylinePoints),
          strokeColor: const Color(0xFFE52929),
          strokeWidth: 5.0,
          outlineColor: Colors.white,
          outlineWidth: 1.0,
        ),
      );
    }

    // 2. Маркеры остановок (видимая область экрана)
    for (final station in _visibleStations) {
      final isSelected = _selectedStation?.stationId == station.stationId;
      objects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('station_${station.stationId}'),
          point: Point(latitude: station.lat, longitude: station.lng),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: isSelected ? _selectedStationIcon : _stationIcon,
              scale: isSelected ? 0.25 : 0.24,
            ),
          ),
          opacity: 1.0,
          onTap: (PlacemarkMapObject self, Point point) {
            _onStationTap(station);
          },
        ),
      );
    }

    // 3. Маркеры автобусов (если выбрана остановка — показываем автобусы этой остановки)
    final displayVehicles = _stationRouteNames.isNotEmpty
        ? _allVehicles.where((v) => _stationRouteNames.contains(v.routeName)).toList()
        : _allVehicles;

    for (final vehicle in displayVehicles) {
      final isSelected = _selectedVehicle?.vehicleId == vehicle.vehicleId;
      objects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('bus_${vehicle.vehicleId}'),
          point: Point(latitude: vehicle.lat, longitude: vehicle.lng),
          direction: (vehicle.course + 180) % 360,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: _blueBusPinIcon,
              scale: isSelected ? 0.46 : 0.38,
              rotationType: RotationType.rotate,
            ),
          ),
          opacity: 1.0,
          onTap: (PlacemarkMapObject self, Point point) {
            _onVehicleTap(vehicle);
          },
        ),
      );
    }

    // 4. Реальный маркер геопозиции пользователя (желтая капля mark_location.png)
    if (_userLocation != null) {
      objects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('user_location_marker'),
          point: _userLocation!,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: _locationIcon,
              scale: 0.50,
            ),
          ),
          opacity: 1.0,
        ),
      );
    }

    return objects;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      body: Stack(
        children: [
          // 1. Полноэкранная векторная карта Яндекс MapKit
          YandexMap(
            onMapCreated: (controller) async {
              _mapController = controller;
              final target = _userLocation ?? _tverCenter;
              await _mapController?.moveCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: target, zoom: 15.0),
                ),
              );
              await _fetchBoundsAndFilter();
              widget.onMapReady?.call();
            },
            onCameraPositionChanged: _onCameraPositionChanged,
            mapObjects: _buildMapObjects(),
            nightModeEnabled: false,
            rotateGesturesEnabled: true,
            zoomGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),

          // 2. Плавающие фирменные кнопки (только Центрирование и Зум активны)
          SafeArea(
            child: VolgaMapButtons(
              onFilterTap: () {}, // Декоративная
              onCenterLocationTap: _centerOnUserLocation, // АКТИВНАЯ
              onBusModeTap: () {}, // Декоративная
              onZoomInTap: () { // АКТИВНАЯ
                _mapController?.moveCamera(
                  CameraUpdate.zoomIn(),
                  animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.3),
                );
              },
              onZoomOutTap: () { // АКТИВНАЯ
                _mapController?.moveCamera(
                  CameraUpdate.zoomOut(),
                  animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.3),
                );
              },
              onCompassTap: () {}, // Декоративная
              onBlindModeTap: () {}, // Декоративная
              isBusModeActive: true,
            ),
          ),

          // 3. Плавающая белая кнопка "Построить маршрут" внизу (по res/app/original.webp)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {},
                  child: const Center(
                    child: Text(
                      'Построить маршрут',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF1E1E1E),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
