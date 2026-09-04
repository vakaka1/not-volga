import 'package:flutter/material.dart';
import '../models/transport/route_model.dart';
import '../services/merlin_transport_service.dart';
import '../services/ticket_service.dart';
import '../theme/app_colors.dart';
import '../widgets/payment_confirmation_sheet.dart';
import 'qr_route_payment_screen.dart';

/// Экран ручного выбора параметров поездки.
/// Вызывается при отсутствии интернета или если QR-код не определил автобус.
class TicketConstructorScreen extends StatefulWidget {
  final String? initialRouteNumber;
  final String? initialLicensePlate;
  final bool isOfflineMode;

  const TicketConstructorScreen({
    super.key,
    this.initialRouteNumber,
    this.initialLicensePlate,
    this.isOfflineMode = false,
  });

  @override
  State<TicketConstructorScreen> createState() => _TicketConstructorScreenState();
}

class _TicketConstructorScreenState extends State<TicketConstructorScreen> {
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _fareController = TextEditingController();
  List<RouteModel> _availableRoutes = [];
  bool _isLoadingRoutes = true;
  RouteModel? _selectedRoute;
  String _routeNumberText = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialLicensePlate != null && widget.initialLicensePlate!.isNotEmpty) {
      _plateController.text = widget.initialLicensePlate!.trim();
    }
    if (widget.initialRouteNumber != null && widget.initialRouteNumber!.isNotEmpty) {
      _routeNumberText = widget.initialRouteNumber!.replaceAll('№', '').trim();
    }
    _loadRoutes();
  }

  @override
  void dispose() {
    _plateController.dispose();
    _fareController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    final service = MerlinTransportService();
    await service.initOfflineData();
    if (mounted) {
      final routes = List<RouteModel>.from(service.cachedRoutes);
      // Числовая сортировка маршрутов: от меньшего к большему
      routes.sort((a, b) {
        final aNum = int.tryParse(a.name.replaceAll(RegExp(r'\D'), '')) ?? 999;
        final bNum = int.tryParse(b.name.replaceAll(RegExp(r'\D'), '')) ?? 999;
        return aNum.compareTo(bNum);
      });

      RouteModel? preselected;
      if (_routeNumberText.isNotEmpty) {
        for (final r in routes) {
          if (r.name.toLowerCase() == _routeNumberText.toLowerCase()) {
            preselected = r;
            break;
          }
        }
      }

      setState(() {
        _availableRoutes = routes;
        _selectedRoute = preselected;
        _isLoadingRoutes = false;
      });

      if (preselected != null && _plateController.text.isEmpty) {
        _tryFillPlate(preselected.name);
      }
    }
  }

  void _tryFillPlate(String routeName) {
    final liveBus = MerlinTransportService().getLiveVehicleForRoute(routeName);
    if (liveBus != null && liveBus.licenseNumber.isNotEmpty) {
      _plateController.text = liveBus.formattedLicenseNumber;
    }
  }

  void _showRoutePicker() {
    showModalBottomSheet<RouteModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ConstructorRoutePickerSheet(
        routes: _availableRoutes,
        currentRouteId: _selectedRoute?.routeId,
      ),
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() {
          _selectedRoute = selected;
          _routeNumberText = selected.name;
        });
        if (_plateController.text.isEmpty) {
          _tryFillPlate(selected.name);
        }
      }
    });
  }

  void _handleNext() async {
    if (_selectedRoute == null && _routeNumberText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите маршрут')),
      );
      return;
    }

    final plateText = _plateController.text.trim();
    final formattedPlate = formatRussianLicensePlate(plateText);

    final routeName = _routeNumberText;
    final digits = int.tryParse(routeName.replaceAll(RegExp(r'\D'), ''));
    final isSuburban = (digits != null && digits >= 100) || routeName.length >= 3;

    String routeTitle = '';
    List<String> stations = [];
    int routeId = 0;
    String startStation = '';
    String endStation = '';

    if (_selectedRoute != null) {
      routeId = _selectedRoute!.routeId;
      routeTitle = _selectedRoute!.title.isNotEmpty
          ? _selectedRoute!.title
          : _selectedRoute!.startEndStations;
      final details = await MerlinTransportService().getRouteDetails(routeId, preferOffline: true);
      if (details != null && details.stations.isNotEmpty) {
        stations = details.stations.map((s) => s.name).toList();
        startStation = stations.first;
        endStation = details.finalStation.isNotEmpty ? details.finalStation : stations.last;
      }
    } else {
      // Ищем по названию
      final details = MerlinTransportService().getRouteDetailsByName(routeName);
      if (details != null && details.stations.isNotEmpty) {
        routeId = details.routeId;
        routeTitle = details.title.isNotEmpty ? details.title : details.startEndStations;
        stations = details.stations.map((s) => s.name).toList();
        startStation = stations.first;
        endStation = details.finalStation.isNotEmpty ? details.finalStation : stations.last;
      }
    }

    if (!mounted) return;

    // Пользовательская стоимость в офлайне (если введена)
    int offlineFare = 0;
    if (widget.isOfflineMode) {
      final fareText = _fareController.text.trim();
      if (fareText.isNotEmpty) {
        offlineFare = int.tryParse(fareText) ?? 0;
      }
    }

    final transportInfo = ScannedTransportInfo(
      routeNumber: '№$routeName',
      routeTitle: routeTitle,
      transportType: '',
      regNumber: formattedPlate,
      carrier: '',
      city: 'Тверь',
      fare: offlineFare,
      rawQrData: '',
      isIntercity: isSuburban,
      startStation: startStation,
      endStation: endStation,
      availableStations: stations,
      routeId: routeId,
      isLiveVehicle: false,
      boardNumber: '',
    );

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => QrRoutePaymentScreen(
          transportInfo: transportInfo,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = _selectedRoute != null || _routeNumberText.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      // Без огромного текста «Конструктор билета» в AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111217), size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок в едином стиле
                    const Text(
                      'Маршрут',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111217),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Поле выбора маршрута (только текст, без картинок и смайликов)
                    InkWell(
                      onTap: _isLoadingRoutes ? null : _showRoutePicker,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _selectedRoute != null
                                  ? Text(
                                      '№${_selectedRoute!.name} — ${_selectedRoute!.title.isNotEmpty ? _selectedRoute!.title : _selectedRoute!.startEndStations}',
                                      style: const TextStyle(
                                        fontFamily: 'NotoSans',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111217),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : Text(
                                      _routeNumberText.isNotEmpty
                                          ? '№$_routeNumberText'
                                          : 'Выберите маршрут',
                                      style: TextStyle(
                                        fontFamily: 'NotoSans',
                                        fontSize: 16,
                                        color: _routeNumberText.isNotEmpty
                                            ? const Color(0xFF111217)
                                            : const Color(0xFF64748B),
                                        fontWeight: _routeNumberText.isNotEmpty
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                            ),
                            if (_isLoadingRoutes)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                              )
                            else
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 22),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Поле гос. номера (без иконок и смайликов)
                    const Text(
                      'Гос номер',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111217),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _plateController,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111217),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'о039ср69 или Н 744 СР 69',
                                hintStyle: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 14,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_plateController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _plateController.clear();
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),

                    // Поле стоимости (только для офлайн-режима)
                    if (widget.isOfflineMode) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Стоимость (₽)',
                        style: TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111217),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        ),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _fareController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111217),
                          ),
                          decoration: const InputDecoration(
                            hintText: '40 (не обязательно)',
                            hintStyle: TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.normal,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Кнопка «Далее»
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: hasRoute ? _handleNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Далее',
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Модальный экран выбора маршрута в конструкторе
class _ConstructorRoutePickerSheet extends StatefulWidget {
  final List<RouteModel> routes;
  final int? currentRouteId;

  const _ConstructorRoutePickerSheet({
    required this.routes,
    this.currentRouteId,
  });

  @override
  State<_ConstructorRoutePickerSheet> createState() => _ConstructorRoutePickerSheetState();
}

class _ConstructorRoutePickerSheetState extends State<_ConstructorRoutePickerSheet> {
  late final TextEditingController _controller;
  late List<RouteModel> _filtered;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _filtered = widget.routes;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.routes;
      } else {
        _filtered = widget.routes.where((r) {
          if (r.name.toLowerCase().contains(q)) return true;
          if (r.title.toLowerCase().contains(q)) return true;
          if (r.startEndStations.toLowerCase().contains(q)) return true;
          if (r.endStation.toLowerCase().contains(q)) return true;
          // Поиск по остановкам маршрута
          final details = MerlinTransportService().getRouteDetailsByName(r.name);
          if (details != null) {
            for (final s in details.stations) {
              if (s.name.toLowerCase().contains(q)) return true;
            }
          }
          return false;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Выберите маршрут',
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111217),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _controller,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск по номеру или остановке...',
                hintStyle: const TextStyle(
                  fontFamily: 'NotoSans',
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                        onPressed: () {
                          _controller.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Маршрут не найден',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 20),
                    itemBuilder: (context, index) {
                      final r = _filtered[index];
                      final isSelected = widget.currentRouteId == r.routeId;
                      final displayTitle = r.title.isNotEmpty ? r.title : r.startEndStations;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0052FF) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '№${r.name}',
                            style: TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        title: Text(
                          displayTitle,
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111217),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded, color: Color(0xFF0052FF), size: 22)
                            : null,
                        onTap: () => Navigator.of(context).pop(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
