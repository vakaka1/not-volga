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
import '../widgets/map/bus_marker_generator.dart';
import '../widgets/map/volga_map_buttons.dart';
import '../widgets/map/volga_route_badge.dart';

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

  // Кэш сгенерированных маркеров автобусов
  final Map<String, BitmapDescriptor> _busMarkerCache = {};

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

  // Состояние нижней панели
  bool _showBusSheet = false;
  bool _showStationSheet = false;
  bool _isSheetExpanded = false;
  List<StationArrivalModel> _stationArrivals = [];
  bool _isLoadingArrivals = false;

  // Реальная геопозиция и направление пользователя
  Point? _userLocation;
  double? _userHeading;
  StreamSubscription<Position>? _positionStreamSub;

  Timer? _pollingTimer;

  // Видимые границы карты
  double _topLat = 56.93423;
  double _bottomLat = 56.785747;
  double _leftLng = 35.737569;
  double _rightLng = 36.039364;
  double _currentZoom = 15.0;

  // Флаг загрузки остановок из сети
  bool _stationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _initBusMarkerGenerator();
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

  Future<void> _initBusMarkerGenerator() async {
    await BusMarkerGenerator.init();
    if (mounted) {
      _preloadBusMarkers();
    }
  }

  Future<void> _preloadBusMarkers() async {
    for (final v in _allVehicles) {
      final isSel = _selectedVehicle?.vehicleId == v.vehicleId;
      final key = '${v.vehicleId}_${v.course.toInt()}_$isSel';
      if (!_busMarkerCache.containsKey(key)) {
        final marker = await BusMarkerGenerator.getBusMarker(
          course: v.course,
          routeName: v.routeName,
          isSelected: isSel,
        );
        if (mounted) {
          setState(() {
            _busMarkerCache[key] = marker;
          });
        }
      }
    }
  }

  // ───────────────────────────── 1. ГЕОЛОКАЦИЯ И ПОВОРОТ ─────────────────────────────

  Future<void> _initRealGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location service disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever');
        return;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // 1. Сначала пробуем получить последнее известное положение мгновенно
        try {
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null && mounted) {
            setState(() {
              _userLocation = Point(latitude: lastPos.latitude, longitude: lastPos.longitude);
              if (lastPos.heading != 0) {
                _userHeading = lastPos.heading;
              }
            });
          }
        } catch (_) {}

        // 2. Получаем точное текущее положение
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 6),
            ),
          );
          if (mounted) {
            final userPt = Point(latitude: pos.latitude, longitude: pos.longitude);
            setState(() {
              _userLocation = userPt;
              if (pos.heading != 0) {
                _userHeading = pos.heading;
              }
            });
            _mapController?.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: userPt, zoom: 15.5),
              ),
              animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.6),
            );
          }
        } catch (_) {}

        // 3. Непрерывный поток координат и компаса/направления
        _positionStreamSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 2,
          ),
        ).listen((livePos) {
          if (mounted) {
            setState(() {
              _userLocation = Point(latitude: livePos.latitude, longitude: livePos.longitude);
              if (livePos.heading != 0) {
                _userHeading = livePos.heading;
              }
            });
          }
        });
      }
    } catch (e) {
      debugPrint('GPS init error: $e');
    }
  }

  /// Кнопка центрирования на пользователе (запрашивает права при необходимости и двигает камеру)
  Future<void> _centerOnUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
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
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 6),
          ),
        );
        final userPt = Point(latitude: pos.latitude, longitude: pos.longitude);
        if (mounted) {
          setState(() {
            _userLocation = userPt;
            if (pos.heading != 0) {
              _userHeading = pos.heading;
            }
          });
        }

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
        CameraPosition(target: target, zoom: 16.0),
      ),
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
    );
  }

  // ───────────────────────────── 2. ЗАГРУЗКА ДАННЫХ ─────────────────────────────

  Future<void> _initData() async {
    await _loadStationsFromNetwork();
    _fetchLiveVehicles();
  }

  /// Остановки подгружаются ТОЛЬКО с интернетом (как в оригинале)
  Future<void> _loadStationsFromNetwork() async {
    if (_stationsLoaded) return;
    try {
      final stations = await _transportService.getStations(locationId: 1, forceRefresh: true);
      if (mounted && stations.isNotEmpty) {
        _stationsLoaded = true;
        _allStations = stations;
        _updateVisibleStations();
      }
    } catch (_) {
      // Нет сети — остановки не отображаются
    }
  }

  void _updateVisibleStations() {
    if (_allStations.isEmpty) return;

    if (_currentZoom < 12.5) {
      if (_visibleStations.isNotEmpty && mounted) {
        setState(() => _visibleStations = []);
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

    if (mounted) setState(() => _visibleStations = filtered);
  }

  void _startLiveVehiclesPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchLiveVehicles());
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
      setState(() => _allVehicles = liveVehicles);
      _preloadBusMarkers();
    }
  }

  void _onCameraPositionChanged(CameraPosition position, CameraUpdateReason reason, bool finished) {
    _currentZoom = position.zoom;
    if (finished) _fetchBoundsAndFilter();
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
      if (!_stationsLoaded) _loadStationsFromNetwork();
    } catch (_) {}
  }

  // ───────────────────────────── 3. ЗАКРЫТИЕ И ВЫБОР ОБЪЕКТОВ ─────────────────────────────

  void _closeAnySheet() {
    if (!_showBusSheet && !_showStationSheet) return;
    setState(() {
      _showBusSheet = false;
      _showStationSheet = false;
      _isSheetExpanded = false;
      _selectedStation = null;
      _selectedVehicle = null;
      _stationRouteNames = {};
      _activeRoutePath = [];
      _activeRouteDetails = null;
      _stationArrivals = [];
    });
    widget.onSheetVisibilityChanged?.call(false);
  }

  Future<void> _onVehicleTap(VehicleModel vehicle) async {
    setState(() {
      _selectedVehicle = vehicle;
      _selectedStation = null;
      _stationRouteNames = {};
      _showStationSheet = false;
      _showBusSheet = true;
      _isSheetExpanded = false;
      _stationArrivals = [];
    });
    widget.onSheetVisibilityChanged?.call(true);

    // Генерируем выбранный маркер (с номером маршрута)
    final selKey = '${vehicle.vehicleId}_${vehicle.course.toInt()}_true';
    if (!_busMarkerCache.containsKey(selKey)) {
      final marker = await BusMarkerGenerator.getBusMarker(
        course: vehicle.course,
        routeName: vehicle.routeName,
        isSelected: true,
      );
      if (mounted) {
        setState(() {
          _busMarkerCache[selKey] = marker;
        });
      }
    }

    final path = await _transportService.getRoutePath(vehicle.routeId);
    final details = await _transportService.getRouteDetails(vehicle.routeId);

    if (mounted) {
      setState(() {
        _activeRoutePath = path;
        _activeRouteDetails = details;
      });

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
  }

  Future<void> _onStationTap(StationModel station) async {
    setState(() {
      _selectedStation = station;
      _selectedVehicle = null;
      _showBusSheet = false;
      _showStationSheet = true;
      _isSheetExpanded = false;
      _isLoadingArrivals = true;
      _stationArrivals = [];
      _activeRoutePath = [];
      _activeRouteDetails = null;
    });
    widget.onSheetVisibilityChanged?.call(true);

    final Map<String, String> vehicleLicenseByRoute = {};
    for (final v in _allVehicles) {
      if (v.routeName.isNotEmpty && v.licenseNumber.isNotEmpty) {
        vehicleLicenseByRoute[v.routeName] = v.formattedLicenseNumber;
      }
    }

    final arrivals = await _transportService.getStationArrivals(
      station.stationId,
      vehicleLicenseByRoute: vehicleLicenseByRoute,
    );

    if (mounted) {
      setState(() {
        _stationArrivals = arrivals;
        _isLoadingArrivals = false;
        _stationRouteNames = arrivals.map((a) => a.routeName).toSet();
      });
    }
  }

  void _onRouteSelectedFromStation(StationArrivalModel selectedArrival) {
    final stationLat = _selectedStation?.lat ?? _tverCenter.latitude;
    final stationLng = _selectedStation?.lng ?? _tverCenter.longitude;

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
      lat: stationLat + 0.002,
      lng: stationLng + 0.002,
      course: 45.0,
      hasWheelchair: selectedArrival.hasWheelchair,
    );

    _onVehicleTap(targetVehicle);
  }

  // ───────────────────────────── 4. ОБЪЕКТЫ НА КАРТЕ ─────────────────────────────

  List<MapObject> _buildMapObjects() {
    final List<MapObject> objects = [];

    // 1. Полилиния выбранного маршрута
    if (_activeRoutePath.isNotEmpty) {
      objects.add(
        PolylineMapObject(
          mapId: const MapObjectId('active_route_track'),
          polyline: Polyline(
            points: _activeRoutePath.map((p) => Point(latitude: p.lat, longitude: p.lng)).toList(),
          ),
          strokeColor: const Color(0xFFE52929),
          strokeWidth: 5.0,
          outlineColor: Colors.white,
          outlineWidth: 1.0,
        ),
      );
    }

    // 2. Маркеры остановок (только если загружены из сети)
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
          onTap: (PlacemarkMapObject self, Point point) => _onStationTap(station),
        ),
      );
    }

    // 3. Маркеры автобусов
    // Рисуются через сгенерированный Canvas: синяя капля повернута по курсу, белый автобус ВСЕГДА стоит ровно!
    // При выборе автобуса добавляется плашка с номером маршрута справа (по res/bus.webp).
    final displayVehicles = _stationRouteNames.isNotEmpty
        ? _allVehicles.where((v) => _stationRouteNames.contains(v.routeName)).toList()
        : _allVehicles;

    for (final vehicle in displayVehicles) {
      final isSelected = _selectedVehicle?.vehicleId == vehicle.vehicleId;
      final key = '${vehicle.vehicleId}_${vehicle.course.toInt()}_$isSelected';
      final cachedIcon = _busMarkerCache[key] ??
          BusMarkerGenerator.getCachedMarker(
            course: vehicle.course,
            routeName: vehicle.routeName,
            isSelected: isSelected,
          );

      // Если иконка еще в процессе генерации, показываем базовый маркер
      final iconDescriptor = cachedIcon ?? BitmapDescriptor.fromAssetImage('assets/icons/ic_routes_blue.png');

      objects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('bus_${vehicle.vehicleId}'),
          point: Point(latitude: vehicle.lat, longitude: vehicle.lng),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: iconDescriptor,
              scale: isSelected ? 0.65 : 0.52,
              rotationType: RotationType.noRotation, // Поворот выполнен в Canvas!
              anchor: isSelected ? const Offset(0.35, 0.5) : const Offset(0.5, 0.5),
            ),
          ),
          opacity: 1.0,
          onTap: (PlacemarkMapObject self, Point point) => _onVehicleTap(vehicle),
        ),
      );
    }

    // 4. Реальный маркер геопозиции пользователя с направлением (куда смотрит!)
    if (_userLocation != null) {
      objects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('user_location_marker'),
          point: _userLocation!,
          direction: _userHeading ?? 0.0,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: _locationIcon,
              scale: 0.50,
              rotationType: RotationType.rotate, // Поворачивает стрелку по направлению движения/компаса!
              anchor: const Offset(0.5, 0.5),
            ),
          ),
          opacity: 1.0,
        ),
      );
    }

    return objects;
  }

  // ───────────────────────────── 5. BUILD МАКЕТА ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool anySheetOpen = _showBusSheet || _showStationSheet;
    final screenHeight = MediaQuery.of(context).size.height;
    final double sheetHeight = _isSheetExpanded ? screenHeight * 0.85 : screenHeight * 0.40;

    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      body: Stack(
        children: [
          // 1. Полноэкранная векторная карта Яндекс MapKit
          // Всегда на весь экран, управляется пользователем даже при открытой панели!
          Positioned.fill(
            child: YandexMap(
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
              onMapTap: (point) {
                // Клик по свободной карте закрывает панель
                if (anySheetOpen) {
                  _closeAnySheet();
                }
              },
              mapObjects: _buildMapObjects(),
              nightModeEnabled: false,
              rotateGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
          ),

          // 2. Плавающие фирменные кнопки карты
          SafeArea(
            child: VolgaMapButtons(
              onFilterTap: () {},
              onCenterLocationTap: _centerOnUserLocation, // Активная кнопка центрирования
              onBusModeTap: () {},
              onZoomInTap: () {
                _mapController?.moveCamera(
                  CameraUpdate.zoomIn(),
                  animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.3),
                );
              },
              onZoomOutTap: () {
                _mapController?.moveCamera(
                  CameraUpdate.zoomOut(),
                  animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.3),
                );
              },
              onCompassTap: () {},
              onBlindModeTap: () {},
              isBusModeActive: true,
            ),
          ),

          // 3. Плавающая белая кнопка «Построить маршрут» (прячется при открытой панели)
          if (!anySheetOpen)
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
                    BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 2)),
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

          // 4. Выдвигающаяся панель ОСТАНОВКИ
          // - Без скруглений!
          // - Без полоски/линии сверху!
          // - Заголовок ФИКСИРОВАН (не скроллится)!
          // - Скроллятся ТОЛЬКО маршруты!
          // - Кнопка крестика для закрытия + свайп вниз!
          if (_showStationSheet && _selectedStation != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: sheetHeight,
              child: _buildStationPanel(),
            ),

          // 5. Выдвигающаяся панель АВТОБУСА
          // - Без скруглений!
          // - Без полоски/линии сверху!
          // - Раскрывается по нажатию на остановки (как и остановка)!
          // - Заголовок ФИКСИРОВАН, скроллятся ТОЛЬКО остановки!
          // - Кнопка крестика для закрытия + свайп вниз!
          if (_showBusSheet && _selectedVehicle != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: sheetHeight,
              child: _buildBusPanel(),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────── ПАНЕЛЬ ОСТАНОВКИ ─────────────────────────────

  Widget _buildStationPanel() {
    final station = _selectedStation!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: const BoxDecoration(
        color: Colors.white,
        // БЕЗ СКРУГЛЕНИЙ (ровный прямоугольник, как в оригинале)
        boxShadow: [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ФИКСИРОВАННЫЙ ЗАГОЛОВОК (НЕ СКРОЛЛИТСЯ НИКОГДА!) ──
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null) {
                if (details.primaryDelta! < -10 && !_isSheetExpanded) {
                  setState(() => _isSheetExpanded = true);
                } else if (details.primaryDelta! > 10 && _isSheetExpanded) {
                  setState(() => _isSheetExpanded = false);
                }
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
                _closeAnySheet();
              }
            },
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Верхняя строка: надпись "Остановка"
                  const Text(
                    'Остановка',
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF707070),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Название остановки (крупный жирный заголовок)
                  Text(
                    station.name,
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Адрес
                  Text(
                    station.address.isNotEmpty ? station.address : 'Тверь, Советская улица',
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 15,
                      color: Color(0xFF707070),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Большая синяя кнопка "Посмотреть расписание"
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isSheetExpanded = !_isSheetExpanded;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isSheetExpanded ? 'Свернуть' : 'Посмотреть расписание',
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFE8EAEF), height: 1, thickness: 1),
                ],
              ),
            ),
          ),

          // ── СКРОЛЛЯТСЯ ТОЛЬКО МАРШРУТЫ! ──
          Expanded(
            child: _isLoadingArrivals && _stationArrivals.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0052FF)),
                    ),
                  )
                : _stationArrivals.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет данных о ближайших рейсах',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 14,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _stationArrivals.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: Color(0xFFE8EAEF), height: 1, thickness: 1),
                        itemBuilder: (context, index) {
                          final item = _stationArrivals[index];
                          return _buildArrivalItem(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalItem(StationArrivalModel item) {
    return InkWell(
      onTap: () => _onRouteSelectedFromStation(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Синий бейдж маршрута с острием наружу
            VolgaRouteBadge(
              routeName: item.routeName,
              height: 36,
              fontSize: 18,
            ),
            const SizedBox(width: 8),

            // Значок инвалида
            if (item.hasWheelchair) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC700),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(Icons.accessible, size: 20, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Госномер
            if (item.licenseNumber != null && item.licenseNumber!.isNotEmpty) ...[
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F5),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.licenseNumber!,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Время прибытия
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.primaryTimeText,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                if (item.secondaryTimeText != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    item.secondaryTimeText!,
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── ПАНЕЛЬ АВТОБУСА ─────────────────────────────

  Widget _buildBusPanel() {
    final vehicle = _selectedVehicle!;
    final startStationName = _activeRouteDetails?.startStation.isNotEmpty == true
        ? _activeRouteDetails!.startStation
        : 'Мигалово-конечная';
    final endStationName = _activeRouteDetails?.finalStation.isNotEmpty == true
        ? _activeRouteDetails!.finalStation
        : (vehicle.nextStationName.isNotEmpty ? vehicle.nextStationName : 'Улица Левитана');
    final totalStationsCount = _activeRouteDetails?.stations.length ?? 33;
    final List<StationModel> routeStations = _activeRouteDetails?.stations ?? [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: const BoxDecoration(
        color: Colors.white,
        // БЕЗ СКРУГЛЕНИЙ
        boxShadow: [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ФИКСИРОВАННЫЙ ЗАГОЛОВОК АВТОБУСА ──
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null) {
                if (details.primaryDelta! < -10 && !_isSheetExpanded) {
                  setState(() => _isSheetExpanded = true);
                } else if (details.primaryDelta! > 10 && _isSheetExpanded) {
                  setState(() => _isSheetExpanded = false);
                }
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
                _closeAnySheet();
              }
            },
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Верхняя плашка: [ 🚌  21 ]   [ ♿ ]   [ O 113 CP  69 ]   + [ X ]
                  Row(
                    children: [
                      VolgaRouteBadge(
                        routeName: vehicle.routeName,
                        height: 34,
                        fontSize: 17,
                      ),
                      const SizedBox(width: 8),

                      if (vehicle.hasWheelchair) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC700),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Icon(Icons.accessible, size: 20, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F1F5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          vehicle.formattedLicenseNumber,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Вертикальный таймлайн маршрута:
                  // ● Мигалово-конечная
                  // | 33 остановки ▼ (кликабельно — раскрывает панель!)
                  // ● Улица Левитана
                  _buildTimeline(
                    startStation: startStationName,
                    endStation: endStationName,
                    totalCount: totalStationsCount,
                    onToggleExpand: () {
                      setState(() {
                        _isSheetExpanded = !_isSheetExpanded;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFFE8EAEF), height: 1, thickness: 1),
                ],
              ),
            ),
          ),

          // ── СКРОЛЛЯТСЯ ТОЛЬКО ПРОМЕЖУТОЧНЫЕ ОСТАНОВКИ! ──
          Expanded(
            child: routeStations.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: routeStations.length,
                    itemBuilder: (context, idx) {
                      final st = routeStations[idx];
                      final isCurrent = st.name == vehicle.nextStationName;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              isCurrent ? Icons.directions_bus : Icons.circle,
                              size: isCurrent ? 18 : 8,
                              color: isCurrent ? const Color(0xFF0052FF) : const Color(0xFFE52929),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                st.name,
                                style: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 15,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                                  color: isCurrent ? const Color(0xFF0052FF) : const Color(0xFF1E1E1E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline({
    required String startStation,
    required String endStation,
    required int totalCount,
    required VoidCallback onToggleExpand,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildRedDot(),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                startStation,
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              margin: const EdgeInsets.only(left: 4.5),
              width: 3,
              height: 40,
              color: const Color(0xFFE52929),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: InkWell(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$totalCount остановки',
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      Icon(
                        _isSheetExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: const Color(0xFF1E1E1E),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildRedDot(),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                endStation,
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRedDot() {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Color(0xFFE52929),
        shape: BoxShape.circle,
      ),
    );
  }
}
