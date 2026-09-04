import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../models/transport/route_details_model.dart';
import '../models/transport/route_path_point.dart';
import '../models/transport/station_arrival_model.dart';
import '../models/transport/station_model.dart';
import '../models/transport/vehicle_model.dart';
import '../services/merlin_transport_service.dart';
import '../services/ticket_service.dart';
import '../widgets/map/bus_marker_generator.dart';
import '../widgets/map/volga_map_buttons.dart';
import '../widgets/map/volga_route_badge.dart';
import '../widgets/map/volga_bus_bottom_sheet.dart';

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

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
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
  Set<int> _stationRouteIds = {};

  // Состояние нижней панели
  bool _showBusSheet = false;
  bool _showStationSheet = false;
  bool _isSheetExpanded = false;
  bool get isSheetExpanded => _isSheetExpanded;
  bool _isPassedStopsExpanded = false;
  bool _isRemainingStopsExpanded = false;
  List<StationArrivalModel> _stationArrivals = [];
  bool _isLoadingArrivals = false;

  // Контроллеры плавной анимации выдвижной панели
  late final AnimationController _sheetVisibilityController;
  late final AnimationController _sheetExpandController;

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

  // Видимость автобусов и остановок
  bool _showBuses = true;
  bool _showStations = true;

  @override
  void initState() {
    super.initState();
    _sheetVisibilityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _sheetExpandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _initBusMarkerGenerator();
    _initData();
    _startLiveVehiclesPolling();
    _initRealGpsLocation();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _pollingTimer?.cancel();
    _sheetVisibilityController.dispose();
    _sheetExpandController.dispose();
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

  /// Кнопка центрирования на пользователе (стрелка)
  Future<void> _centerOnUserLocation() async {
    // 1. Если координаты уже известны, мгновенно анимируем камеру туда
    if (_userLocation != null) {
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _userLocation!, zoom: 16.5),
        ),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.6),
      );
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (_userLocation == null) {
          await Geolocator.openLocationSettings();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (_userLocation == null) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 5),
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

          _mapController?.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: userPt, zoom: 16.5),
            ),
            animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
          );
        }
        return;
      }
    } catch (_) {}

    if (_userLocation == null) {
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          const CameraPosition(target: _tverCenter, zoom: 16.0),
        ),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
      );
    }
  }

  /// Переключение отображения автобусов на карте
  void _toggleBusMode() {
    setState(() {
      _showBuses = !_showBuses;
      if (!_showBuses && _showBusSheet) {
        _closeAnySheet();
      }
    });
    if (_showBuses) {
      _fetchLiveVehicles();
    }
  }

  /// Переключение отображения остановок на карте
  void _toggleStationsMode() {
    setState(() {
      _showStations = !_showStations;
      if (!_showStations && _showStationSheet) {
        _closeAnySheet();
      }
    });
    if (_showStations) {
      if (!_stationsLoaded) {
        _loadStationsFromNetwork();
      } else {
        _updateVisibleStations();
      }
    }
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
    if (!_showBusSheet && !_showStationSheet && _sheetVisibilityController.value == 0) return;
    _sheetVisibilityController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showBusSheet = false;
          _showStationSheet = false;
          _isSheetExpanded = false;
          _isPassedStopsExpanded = false;
          _isRemainingStopsExpanded = false;
          _selectedStation = null;
          _selectedVehicle = null;
          _stationRouteNames = {};
          _stationRouteIds = {};
          _activeRoutePath = [];
          _activeRouteDetails = null;
          _stationArrivals = [];
        });
        _sheetExpandController.value = 0.0;
        widget.onSheetVisibilityChanged?.call(false);
      }
    });
  }

  void _toggleOrExpandSheet() {
    if (_sheetExpandController.value > 0.5) {
      _sheetExpandController.animateTo(0.0, curve: Curves.easeInOutCubic, duration: const Duration(milliseconds: 260));
      setState(() => _isSheetExpanded = false);
    } else {
      _sheetExpandController.animateTo(1.0, curve: Curves.easeInOutCubic, duration: const Duration(milliseconds: 260));
      setState(() => _isSheetExpanded = true);
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details, double minH, double maxH) {
    final double range = maxH - minH;
    if (range <= 0) return;
    final double deltaFraction = details.primaryDelta! / range;
    _sheetExpandController.value = (_sheetExpandController.value - deltaFraction).clamp(0.0, 1.0);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0.0;
    if (velocity > 600) {
      // Быстрый свайп вниз
      if (_sheetExpandController.value < 0.25) {
        _closeAnySheet();
      } else {
        _sheetExpandController.animateTo(0.0, curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 220));
        setState(() => _isSheetExpanded = false);
      }
    } else if (velocity < -600) {
      // Быстрый свайп вверх
      _sheetExpandController.animateTo(1.0, curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 220));
      setState(() => _isSheetExpanded = true);
    } else {
      if (_sheetExpandController.value > 0.45) {
        _sheetExpandController.animateTo(1.0, curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 200));
        setState(() => _isSheetExpanded = true);
      } else {
        _sheetExpandController.animateTo(0.0, curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 200));
        setState(() => _isSheetExpanded = false);
      }
    }
  }

  Future<void> _onVehicleTap(VehicleModel vehicle) async {
    final bool wasOpen = _showStationSheet || _showBusSheet || _sheetVisibilityController.value > 0;
    setState(() {
      _selectedVehicle = vehicle;
      _selectedStation = null;
      _stationRouteNames = {};
      _stationRouteIds = {};
      _showStationSheet = false;
      _showBusSheet = true;
      _isPassedStopsExpanded = false;
      _isRemainingStopsExpanded = false;
      _stationArrivals = [];
    });
    widget.onSheetVisibilityChanged?.call(true);

    if (!wasOpen) {
      _sheetExpandController.value = 0.0;
      _isSheetExpanded = false;
      _sheetVisibilityController.forward(from: 0.0);
    }

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
    final bool wasOpen = _showStationSheet || _showBusSheet || _sheetVisibilityController.value > 0;
    setState(() {
      _selectedStation = station;
      _selectedVehicle = null;
      _showBusSheet = false;
      _showStationSheet = true;
      _isLoadingArrivals = true;
      _stationArrivals = [];
      _stationRouteNames = {};
      _stationRouteIds = {};
      _activeRoutePath = [];
      _activeRouteDetails = null;
    });
    widget.onSheetVisibilityChanged?.call(true);

    if (!wasOpen) {
      _sheetExpandController.value = 0.0;
      _isSheetExpanded = false;
      _sheetVisibilityController.forward(from: 0.0);
    }

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

    // Сортировка: сверху ближайшие, ниже — которые будут позже
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

    if (mounted) {
      setState(() {
        _stationArrivals = arrivals;
        _isLoadingArrivals = false;
        _stationRouteNames = arrivals.map((a) => a.routeName).where((n) => n.isNotEmpty).toSet();
        _stationRouteIds = arrivals.map((a) => a.routeId).where((id) => id != 0).toSet();
      });
    }
  }

  Future<void> _onRouteSelectedFromStation(StationArrivalModel selectedArrival) async {
    // 1. Ищем живой автобус для этого рейса/маршрута
    VehicleModel? targetVehicle;

    // 1.1 По точному совпадению госномера среди уже загруженных автобусов
    if (selectedArrival.licenseNumber != null && selectedArrival.licenseNumber!.trim().isNotEmpty) {
      final cleanTargetLic = selectedArrival.licenseNumber!.replaceAll(' ', '').toUpperCase();
      for (final v in _allVehicles) {
        final cleanVLic = v.licenseNumber.replaceAll(' ', '').toUpperCase();
        if (cleanVLic.isNotEmpty &&
            (cleanVLic == cleanTargetLic || cleanVLic.contains(cleanTargetLic) || cleanTargetLic.contains(cleanVLic))) {
          targetVehicle = v;
          break;
        }
      }
    }

    // 1.2 По номеру маршрута (routeName) или routeId
    if (targetVehicle == null) {
      final matching = _allVehicles.where((v) =>
          (v.routeName.isNotEmpty && v.routeName == selectedArrival.routeName) ||
          (selectedArrival.routeId != 0 && v.routeId == selectedArrival.routeId)).toList();

      if (matching.isNotEmpty) {
        final stationLat = _selectedStation?.lat;
        final stationLng = _selectedStation?.lng;
        if (stationLat != null && stationLng != null) {
          matching.sort((a, b) {
            final distA = (a.lat - stationLat) * (a.lat - stationLat) + (a.lng - stationLng) * (a.lng - stationLng);
            final distB = (b.lat - stationLat) * (b.lat - stationLat) + (b.lng - stationLng) * (b.lng - stationLng);
            return distA.compareTo(distB);
          });
        }
        targetVehicle = matching.first;
      }
    }

    // 1.3 Если в текущей области не найден, пробуем загрузить живые автобусы по всей Твери
    if (targetVehicle == null) {
      try {
        final cityVehicles = await _transportService.getVehicles(
          topLat: 56.98,
          bottomLat: 56.72,
          leftLng: 35.65,
          rightLng: 36.15,
        );
        if (cityVehicles.isNotEmpty) {
          _allVehicles = cityVehicles;
          if (selectedArrival.licenseNumber != null && selectedArrival.licenseNumber!.trim().isNotEmpty) {
            final cleanTargetLic = selectedArrival.licenseNumber!.replaceAll(' ', '').toUpperCase();
            for (final v in cityVehicles) {
              final cleanVLic = v.licenseNumber.replaceAll(' ', '').toUpperCase();
              if (cleanVLic.isNotEmpty &&
                  (cleanVLic == cleanTargetLic || cleanVLic.contains(cleanTargetLic) || cleanTargetLic.contains(cleanVLic))) {
                targetVehicle = v;
                break;
              }
            }
          }
          if (targetVehicle == null) {
            final matching = cityVehicles.where((v) =>
                (v.routeName.isNotEmpty && v.routeName == selectedArrival.routeName) ||
                (selectedArrival.routeId != 0 && v.routeId == selectedArrival.routeId)).toList();
            if (matching.isNotEmpty) {
              final stationLat = _selectedStation?.lat;
              final stationLng = _selectedStation?.lng;
              if (stationLat != null && stationLng != null) {
                matching.sort((a, b) {
                  final distA = (a.lat - stationLat) * (a.lat - stationLat) + (a.lng - stationLng) * (a.lng - stationLng);
                  final distB = (b.lat - stationLat) * (b.lat - stationLat) + (b.lng - stationLng) * (b.lng - stationLng);
                  return distA.compareTo(distB);
                });
              }
              targetVehicle = matching.first;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Загружаем геометрию (трек) маршрута и детальную информацию со списком остановок
    final routeId = targetVehicle?.routeId ?? selectedArrival.routeId;
    final path = await _transportService.getRoutePath(routeId);
    final details = await _transportService.getRouteDetails(routeId);

    if (!mounted) return;

    // 3. Заменяем нижнюю панель остановки на панель автобуса
    _sheetExpandController.value = 0.0;
    _isSheetExpanded = false;

    if (targetVehicle != null) {
      // ── АВТОБУС НАЙДЕН ──
      // Камеру перемещаем к этому автобусу и центрируем
      setState(() {
        _selectedVehicle = targetVehicle;
        _selectedStation = null;
        _showStationSheet = false;
        _showBusSheet = true;
        _stationArrivals = [];
        _stationRouteNames = {};
        _stationRouteIds = {};
        _activeRoutePath = path;
        _activeRouteDetails = details;
        _showBuses = true;
      });
      widget.onSheetVisibilityChanged?.call(true);

      final selKey = '${targetVehicle.vehicleId}_${targetVehicle.course.toInt()}_true';
      if (!_busMarkerCache.containsKey(selKey)) {
        final marker = await BusMarkerGenerator.getBusMarker(
          course: targetVehicle.course,
          routeName: targetVehicle.routeName,
          isSelected: true,
        );
        if (mounted) {
          setState(() {
            _busMarkerCache[selKey] = marker;
          });
        }
      }

      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: targetVehicle.lat, longitude: targetVehicle.lng),
            zoom: 16.5,
          ),
        ),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
      );
    } else {
      // ── АВТОБУС НАЙТИ НЕВОЗМОЖНО ──
      // Отдаляем и центрируем маршрут, панель остановки заменяем на панель автобуса
      final fallbackVehicle = VehicleModel(
        vehicleId: 'route_${selectedArrival.routeId}',
        boardNumber: '',
        model: '',
        routeId: selectedArrival.routeId,
        routeName: selectedArrival.routeName,
        licenseNumber: selectedArrival.licenseNumber ?? '',
        lat: 0.0,
        lng: 0.0,
        hasWheelchair: selectedArrival.hasWheelchair,
      );

      setState(() {
        _selectedVehicle = fallbackVehicle;
        _selectedStation = null;
        _showStationSheet = false;
        _showBusSheet = true;
        _stationArrivals = [];
        _stationRouteNames = {};
        _stationRouteIds = {};
        _activeRoutePath = path;
        _activeRouteDetails = details;
      });
      widget.onSheetVisibilityChanged?.call(true);

      // Собираем точки маршрута для вычисления охвата (bounding box)
      List<Point> routePoints = [];
      if (path.isNotEmpty) {
        routePoints = path.map((p) => Point(latitude: p.lat, longitude: p.lng)).toList();
      } else if (details?.stations.isNotEmpty == true) {
        routePoints = details!.stations
            .where((s) => s.lat != 0.0 && s.lng != 0.0)
            .map((s) => Point(latitude: s.lat, longitude: s.lng))
            .toList();
      }

      if (routePoints.isNotEmpty) {
        double minLat = 90.0, maxLat = -90.0;
        double minLng = 180.0, maxLng = -180.0;
        for (final pt in routePoints) {
          if (pt.latitude < minLat) minLat = pt.latitude;
          if (pt.latitude > maxLat) maxLat = pt.latitude;
          if (pt.longitude < minLng) minLng = pt.longitude;
          if (pt.longitude > maxLng) maxLng = pt.longitude;
        }

        final latSpan = (maxLat - minLat).abs();
        final lngSpan = (maxLng - minLng).abs();
        final maxSpan = math.max(latSpan, lngSpan);
        final centerLat = (minLat + maxLat) / 2;
        final centerLng = (minLng + maxLng) / 2;

        // Рассчитываем зум так, чтобы весь маршрут поместился целиком
        double routeZoom = 12.2;
        if (maxSpan > 0.22) {
          routeZoom = 10.8;
        } else if (maxSpan > 0.16) {
          routeZoom = 11.3;
        } else if (maxSpan > 0.10) {
          routeZoom = 11.8;
        } else if (maxSpan > 0.06) {
          routeZoom = 12.3;
        } else {
          routeZoom = 13.0;
        }

        // Сдвигаем центр немного южнее, чтобы маршрут был идеально виден над открытой шторкой
        final targetLat = centerLat - latSpan * 0.15;
        final targetCenter = Point(latitude: targetLat, longitude: centerLng);

        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: targetCenter, zoom: routeZoom),
          ),
          animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
        );
      } else {
        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            const CameraPosition(target: _tverCenter, zoom: 12.0),
          ),
          animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.8),
        );
      }
    }
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

    // 2. Маркеры остановок (только если включены и загружены из сети)
    if (_showStations) {
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
    }

    // 3. Маркеры автобусов (только если включены)
    // Рисуются через сгенерированный Canvas: синяя капля повернута по курсу, белый автобус ВСЕГДА стоит ровно!
    // При выборе автобуса добавляется плашка с номером маршрута справа (по res/bus.webp).
    if (_showBuses) {
      final List<VehicleModel> displayVehicles;

      if (_selectedVehicle != null && _showBusSheet) {
        // ── 2. ВЫБРАН АВТОБУС ──
        // На карте должны быть ТОЛЬКО автобусы этого маршрута
        displayVehicles = _allVehicles.where((v) {
          final matchesName = v.routeName.isNotEmpty && v.routeName == _selectedVehicle!.routeName;
          final matchesId = _selectedVehicle!.routeId != 0 && v.routeId == _selectedVehicle!.routeId;
          return matchesName || matchesId;
        }).toList();

        // Если выбранный автобус имеет координаты, но его нет в списке (например, загружен по городу), добавляем его
        if (_selectedVehicle!.lat != 0.0 &&
            _selectedVehicle!.lng != 0.0 &&
            !displayVehicles.any((v) => v.vehicleId == _selectedVehicle!.vehicleId)) {
          displayVehicles.add(_selectedVehicle!);
        }
      } else if (_selectedStation != null && _showStationSheet) {
        // ── 3. ВЫБРАНА ОСТАНОВКА ──
        // На карте показываются ТОЛЬКО автобусы, релевантные этой остановке
        if (_isLoadingArrivals && _stationRouteNames.isEmpty && _stationRouteIds.isEmpty) {
          displayVehicles = [];
        } else {
          displayVehicles = _allVehicles.where((v) {
            final matchesName = v.routeName.isNotEmpty && _stationRouteNames.contains(v.routeName);
            final matchesId = v.routeId != 0 && _stationRouteIds.contains(v.routeId);
            return matchesName || matchesId;
          }).toList();
        }
      } else {
        // ── ОБЫЧНЫЙ РЕЖИМ ──
        // Показываем все видимые автобусы
        displayVehicles = _allVehicles;
      }

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
                anchor: isSelected
                    ? BusMarkerGenerator.getSelectedAnchor(vehicle.routeName)
                    : const Offset(0.5, 0.5),
              ),
            ),
            opacity: 1.0,
            onTap: (PlacemarkMapObject self, Point point) => _onVehicleTap(vehicle),
          ),
        );
      }
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
    final bool anySheetOpen = _showBusSheet || _showStationSheet || _sheetVisibilityController.value > 0;
    final screenHeight = MediaQuery.of(context).size.height;
    final double collapsedHeight = screenHeight * 0.34;
    final double expandedHeight = screenHeight * 0.86;

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
              onStationsModeTap: _toggleStationsMode,
              onBusModeTap: _toggleBusMode,
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
              onCenterLocationTap: _centerOnUserLocation,
              onBlindModeTap: () {},
              isBusModeActive: _showBuses,
              isStationsModeActive: _showStations,
            ),
          ),

          // 3. Плавающая белая кнопка «Построить маршрут» (прячется при открытой панели)
          if (!anySheetOpen)
            ListenableBuilder(
              listenable: TicketService.instance,
              builder: (context, _) {
                final hasTicket = TicketService.instance.hasActiveTicket;
                final bottomPadding = MediaQuery.of(context).padding.bottom;
                // When ticket is active, nav bar (56 + bottomPadding) + ticket header (54) + 16dp spacing
                final double bottomOffset = hasTicket
                    ? (56.0 + bottomPadding + 54.0 + 16.0)
                    : 16.0;

                return Positioned(
                  left: 16,
                  right: 16,
                  bottom: bottomOffset,
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
                );
              },
            ),

          // 4 & 5. Плавная выдвигающаяся панель (Остановка или Автобус)
          AnimatedBuilder(
            animation: Listenable.merge([_sheetVisibilityController, _sheetExpandController]),
            builder: (context, child) {
              final bool isSheetActive = _sheetVisibilityController.value > 0 || _showStationSheet || _showBusSheet;
              if (!isSheetActive) return const SizedBox.shrink();

              final double currentHeight = collapsedHeight + (expandedHeight - collapsedHeight) * _sheetExpandController.value;

              Widget content;
              if (_showStationSheet && _selectedStation != null) {
                content = _buildStationPanel(collapsedHeight, expandedHeight);
              } else if (_showBusSheet && _selectedVehicle != null) {
                content = _buildBusPanel(collapsedHeight, expandedHeight);
              } else {
                content = const SizedBox.shrink();
              }

              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: currentHeight,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _sheetVisibilityController,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  )),
                  child: content,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── ПАНЕЛЬ ОСТАНОВКИ ─────────────────────────────

  Widget _buildStationPanel(double collapsedHeight, double expandedHeight) {
    final station = _selectedStation!;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 14,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ФИКСИРОВАННЫЙ ЗАГОЛОВОК (НЕ СКРОЛЛИТСЯ, ПЛАВНО ПЕРЕТАСКИВАЕТСЯ) ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) => _handleVerticalDragUpdate(details, collapsedHeight, expandedHeight),
            onVerticalDragEnd: _handleVerticalDragEnd,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Верхняя строка: надпись "Остановка"
                  const Text(
                    'Остановка',
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Название остановки (аккуратный заголовок, точно по оригиналу)
                  Text(
                    station.name,
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                      height: 1.15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Адрес
                  Text(
                    station.address.isNotEmpty ? station.address : 'Тверь, улица Дарвина',
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 13),

                  // Синяя кнопка "Посмотреть расписание" (скругление 16, высота 44)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _toggleOrExpandSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Посмотреть расписание',
                        style: TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Divider(color: Color(0xFFEDEDED), height: 1, thickness: 1),
                ],
              ),
            ),
          ),

          // ── СКРОЛЛЯТСЯ ТОЛЬКО МАРШРУТЫ НА БЛИЖАЙШИЙ ЧАС! ──
          Builder(
            builder: (context) {
              final visibleArrivals = _stationArrivals.where((a) {
                final mins = a.minutesToFirstArrival;
                return mins != null && mins <= 60;
              }).toList();

              return Expanded(
                child: _isLoadingArrivals && visibleArrivals.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0052FF)),
                        ),
                      )
                    : visibleArrivals.isEmpty
                        ? const Center(
                            child: Text(
                              'Нет данных о ближайших рейсах на этот час',
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 14,
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollUpdateNotification) {
                                if (_sheetExpandController.value < 1.0 && notification.scrollDelta != null) {
                                  final double range = expandedHeight - collapsedHeight;
                                  if (range > 0) {
                                    _sheetExpandController.value =
                                        (_sheetExpandController.value + (notification.scrollDelta! / range)).clamp(0.0, 1.0);
                                  }
                                }
                              } else if (notification is OverscrollNotification) {
                                if (notification.overscroll < 0) {
                                  final double range = expandedHeight - collapsedHeight;
                                  if (range > 0) {
                                    _sheetExpandController.value =
                                        (_sheetExpandController.value + (notification.overscroll / range)).clamp(0.0, 1.0);
                                  }
                                }
                              } else if (notification is ScrollEndNotification) {
                                if (_sheetExpandController.value > 0.0 && _sheetExpandController.value < 1.0) {
                                  if (_sheetExpandController.value > 0.45) {
                                    _sheetExpandController.animateTo(1.0,
                                        curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 200));
                                    setState(() => _isSheetExpanded = true);
                                  } else {
                                    _sheetExpandController.animateTo(0.0,
                                        curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 200));
                                    setState(() => _isSheetExpanded = false);
                                  }
                                }
                              }
                              return false;
                            },
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              physics: const ClampingScrollPhysics(),
                              itemCount: visibleArrivals.length,
                              separatorBuilder: (context, index) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 18),
                                child: Divider(color: Color(0xFFEDEDED), height: 1, thickness: 1),
                              ),
                              itemBuilder: (context, index) {
                                final item = visibleArrivals[index];
                                return _buildArrivalItem(item);
                              },
                            ),
                          ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalItem(StationArrivalModel item) {
    return InkWell(
      onTap: () => _onRouteSelectedFromStation(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Синий бейдж маршрута строго фиксированного размера (не растягивается)
            VolgaRouteBadge(
              routeName: item.routeName,
              width: 76,
              height: 31,
              fontSize: 16,
            ),

            // 2. Желтый значок доступности (аккуратный 24х24, только если есть активный автобус с госномером)
            if (item.hasWheelchair && item.licenseNumber != null && item.licenseNumber!.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC700),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.accessible, size: 16, color: Colors.black),
              ),
            ],

            // 3. Плашка госномера (аккуратная 24dp, только если есть активный автобус)
            if (item.licenseNumber != null && item.licenseNumber!.isNotEmpty) ...[
              SizedBox(width: item.hasWheelchair ? 10 : 12),
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.licenseNumber!,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],

            const Spacer(),

            // 4. Время прибытия
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.primaryTimeText,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 16.5,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF111111),
                    height: 1.15,
                  ),
                ),
                if (item.secondaryTimeText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.secondaryTimeText!,
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8E8E93),
                      height: 1.15,
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

  Widget _buildBusPanel(double collapsedHeight, double expandedHeight) {
    final vehicle = _selectedVehicle!;
    final List<StationModel> routeStations = _activeRouteDetails?.stations ?? [];

    final startStationName = _activeRouteDetails?.startStation.isNotEmpty == true
        ? _activeRouteDetails!.startStation
        : (routeStations.isNotEmpty ? routeStations.first.name : 'Автовокзал');
    final endStationName = _activeRouteDetails?.finalStation.isNotEmpty == true
        ? _activeRouteDetails!.finalStation
        : (routeStations.isNotEmpty ? routeStations.last.name : 'Васильевский Мох');
    final currentStationName = vehicle.nextStationName.isNotEmpty
        ? vehicle.nextStationName
        : (routeStations.length > 2 ? routeStations[routeStations.length ~/ 2].name : 'Поворот на аэропорт');

    List<StationModel> passedStations = [];
    List<StationModel> remainingStations = [];

    if (routeStations.length >= 3) {
      int curIdx = routeStations.indexWhere((s) => s.name == currentStationName);
      if (curIdx == -1 && vehicle.nextStationId != null) {
        curIdx = routeStations.indexWhere((s) => s.stationId == vehicle.nextStationId);
      }
      if (curIdx == -1) {
        curIdx = routeStations.indexWhere((s) =>
            s.name.toLowerCase().contains(currentStationName.toLowerCase()) ||
            currentStationName.toLowerCase().contains(s.name.toLowerCase()));
      }
      if (curIdx == -1) {
        curIdx = routeStations.length ~/ 2;
      }
      curIdx = curIdx.clamp(0, routeStations.length - 1);

      if (curIdx > 1) {
        passedStations = routeStations.sublist(1, curIdx);
      }
      if (curIdx < routeStations.length - 2) {
        remainingStations = routeStations.sublist(curIdx + 1, routeStations.length - 1);
      }
    } else {
      const samplePassed = [
        'Железнодорожный вокзал',
        'Площадь Капошвара',
        'Тверской проспект',
        'Речной вокзал',
        'Пожарная площадь',
        'Учебный комбинат',
        'Третьяковский переулок',
        'Исаевский ручей',
        'Автобусный парк',
        'Улица Шишкова дом №98А',
        'Дорожное ремонтно-строительное управление',
        'Поворот на Глазково',
        'Глазково-1',
        'Глазково-2',
      ];
      const sampleRemaining = [
        'Улица Дорожников',
        'Магазин',
        'Дачи',
        'Отрадное',
        'Садоводство',
        'Лесная',
        'Сосновый бор',
        'Озеро',
        'Посёлок',
        'Заводская',
        'Школьная',
        'Клуб',
        'Больница',
        'Центральная',
      ];
      passedStations = samplePassed
          .asMap()
          .entries
          .map((e) => StationModel(stationId: 1000 + e.key, name: e.value, lat: 0, lng: 0))
          .toList();
      remainingStations = sampleRemaining
          .asMap()
          .entries
          .map((e) => StationModel(stationId: 2000 + e.key, name: e.value, lat: 0, lng: 0))
          .toList();
    }

    final int passedCount = passedStations.length;
    final int remainingCount = remainingStations.length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 14,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ВЕРХНЯЯ ПЛАШКА: [ 🚌 107 ] [ ♿ ] [ H 263 CP 69 ] (БЕЗ КНОПКИ ЗАКРЫТИЯ!) ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) =>
                _handleVerticalDragUpdate(details, collapsedHeight, expandedHeight),
            onVerticalDragEnd: _handleVerticalDragEnd,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  VolgaRouteBadge(
                    routeName: vehicle.routeName,
                    width: 76,
                    height: 31,
                    fontSize: 17,
                  ),
                  if (vehicle.hasWheelchair) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC700),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.accessible, size: 16, color: Colors.black),
                    ),
                  ],
                  if (vehicle.formattedLicenseNumber.isNotEmpty) ...[
                    SizedBox(width: vehicle.hasWheelchair ? 10 : 12),
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        vehicle.formattedLicenseNumber,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Divider(
            indent: 22,
            endIndent: 20,
            color: Color(0xFFEDEDED),
            height: 1,
            thickness: 1,
          ),

          // ── ТАЙМЛАЙН ОСТАНОВОК (res/app/original.webp) ──
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  if (_sheetExpandController.value < 1.0 && notification.scrollDelta != null) {
                    final double range = expandedHeight - collapsedHeight;
                    if (range > 0) {
                      _sheetExpandController.value =
                          (_sheetExpandController.value + (notification.scrollDelta! / range)).clamp(0.0, 1.0);
                    }
                  }
                } else if (notification is OverscrollNotification) {
                  if (notification.overscroll < 0) {
                    final double range = expandedHeight - collapsedHeight;
                    if (range > 0) {
                      _sheetExpandController.value =
                          (_sheetExpandController.value + (notification.overscroll / range)).clamp(0.0, 1.0);
                    }
                  }
                } else if (notification is ScrollEndNotification) {
                  if (_sheetExpandController.value > 0.0 && _sheetExpandController.value < 1.0) {
                    if (_sheetExpandController.value > 0.45) {
                      _sheetExpandController.animateTo(1.0,
                          curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 200));
                      setState(() => _isSheetExpanded = true);
                    } else {
                      _sheetExpandController.animateTo(0.0,
                          curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 200));
                      setState(() => _isSheetExpanded = false);
                    }
                  }
                }
                return false;
              },
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    // 1. Начальная остановка (серая)
                    _buildTimelineStationRow(
                      lineType: TimelineLineType.start,
                      dotColor: const Color(0xFFBEBEBE),
                      lineColor: const Color(0xFFCCCCCC),
                      dotRadius: 3.75,
                      stationName: startStationName,
                      textColor: const Color(0xFF9E9E9E),
                      fontWeight: FontWeight.w400,
                      showDivider: true,
                    ),

                    // 2. Блок "N остановок" перед текущей (проехали)
                    if (passedCount > 0) ...[
                      _buildTimelineAccordionRow(
                        isExpanded: _isPassedStopsExpanded,
                        onTap: () {
                          setState(() {
                            _isPassedStopsExpanded = !_isPassedStopsExpanded;
                          });
                          if (_isPassedStopsExpanded && _sheetExpandController.value < 0.5) {
                            _sheetExpandController.animateTo(1.0,
                                curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 260));
                          }
                        },
                        lineType: TimelineLineType.full,
                        dotColor: const Color(0xFFBEBEBE),
                        lineColor: const Color(0xFFCCCCCC),
                        dotRadius: 2.75,
                        text: _formatStopsCount(passedCount),
                        showDivider: true,
                      ),

                      // Раскрытый список проехавших остановок (горят серым)
                      if (_isPassedStopsExpanded) ...[
                        for (final st in passedStations)
                          _buildTimelineSubStationRow(
                            name: st.name,
                            lineColor: const Color(0xFFCCCCCC),
                            dotColor: const Color(0xFFBEBEBE),
                            textColor: const Color(0xFF9E9E9E),
                          ),
                      ],
                    ],

                    // 3. Текущая остановка (красная, от нее линия становится красной)
                    _buildTimelineStationRow(
                      lineType: TimelineLineType.transition,
                      dotColor: const Color(0xFFF70000),
                      lineColor: const Color(0xFFF70000),
                      transitionTopColor: const Color(0xFFCCCCCC),
                      dotRadius: 3.75,
                      stationName: currentStationName,
                      textColor: const Color(0xFF111111),
                      fontWeight: FontWeight.w500,
                      showDivider: true,
                    ),

                    // 4. Блок "N остановок" после текущей (осталось)
                    if (remainingCount > 0) ...[
                      _buildTimelineAccordionRow(
                        isExpanded: _isRemainingStopsExpanded,
                        onTap: () {
                          setState(() {
                            _isRemainingStopsExpanded = !_isRemainingStopsExpanded;
                          });
                          if (_isRemainingStopsExpanded && _sheetExpandController.value < 0.5) {
                            _sheetExpandController.animateTo(1.0,
                                curve: Curves.easeOutCubic, duration: const Duration(milliseconds: 260));
                          }
                        },
                        lineType: TimelineLineType.full,
                        dotColor: const Color(0xFFF70000),
                        lineColor: const Color(0xFFF70000),
                        dotRadius: 2.75,
                        text: _formatStopsCount(remainingCount),
                        showDivider: true,
                      ),

                      // Раскрытый список оставшихся остановок
                      if (_isRemainingStopsExpanded) ...[
                        for (final st in remainingStations)
                          _buildTimelineSubStationRow(
                            name: st.name,
                            lineColor: const Color(0xFFF70000),
                            dotColor: const Color(0xFFF70000),
                            textColor: const Color(0xFF1E1E1E),
                          ),
                      ],
                    ],

                    // 5. Конечная остановка (красная точка)
                    _buildTimelineStationRow(
                      lineType: TimelineLineType.end,
                      dotColor: const Color(0xFFF70000),
                      lineColor: const Color(0xFFF70000),
                      dotRadius: 3.75,
                      stationName: endStationName,
                      textColor: const Color(0xFF111111),
                      fontWeight: FontWeight.w500,
                      showDivider: false,
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStationRow({
    required TimelineLineType lineType,
    required Color dotColor,
    required Color lineColor,
    Color? transitionTopColor,
    required double dotRadius,
    required String stationName,
    required Color textColor,
    required FontWeight fontWeight,
    required bool showDivider,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 54.0,
          child: Row(
            children: [
              SizedBox(
                width: 45.0,
                height: 54.0,
                child: CustomPaint(
                  painter: TimelineDotPainter(
                    lineType: lineType,
                    dotColor: dotColor,
                    lineColor: lineColor,
                    transitionTopColor: transitionTopColor,
                    dotRadius: dotRadius,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: Text(
                    stationName,
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 15.5,
                      fontWeight: fontWeight,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            indent: 45,
            endIndent: 20,
            color: Color(0xFFF2F2F2),
            height: 1,
            thickness: 1,
          ),
      ],
    );
  }

  Widget _buildTimelineAccordionRow({
    required bool isExpanded,
    required VoidCallback onTap,
    required TimelineLineType lineType,
    required Color dotColor,
    required Color lineColor,
    required double dotRadius,
    required String text,
    required bool showDivider,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 54.0,
            child: Row(
              children: [
                SizedBox(
                  width: 45.0,
                  height: 54.0,
                  child: CustomPaint(
                    painter: TimelineDotPainter(
                      lineType: lineType,
                      dotColor: dotColor,
                      lineColor: lineColor,
                      dotRadius: dotRadius,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          text,
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          size: 28,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            indent: 45,
            endIndent: 20,
            color: Color(0xFFF2F2F2),
            height: 1,
            thickness: 1,
          ),
      ],
    );
  }

  Widget _buildTimelineSubStationRow({
    required String name,
    required Color lineColor,
    required Color dotColor,
    required Color textColor,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 44.0,
          child: Row(
            children: [
              SizedBox(
                width: 45.0,
                height: 44.0,
                child: CustomPaint(
                  painter: TimelineDotPainter(
                    lineType: TimelineLineType.full,
                    dotColor: dotColor,
                    lineColor: lineColor,
                    dotRadius: 2.25,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(
          indent: 45,
          endIndent: 20,
          color: Color(0xFFF5F5F5),
          height: 1,
          thickness: 1,
        ),
      ],
    );
  }

  String _formatStopsCount(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 19) {
      return '$count остановок';
    }
    if (mod10 == 1) {
      return '$count остановка';
    }
    if (mod10 >= 2 && mod10 <= 4) {
      return '$count остановки';
    }
    return '$count остановок';
  }
}
