import 'package:flutter/material.dart';
import '../models/transport/route_model.dart';
import '../services/merlin_transport_service.dart';
import '../theme/app_colors.dart';
import 'select_stop_screen.dart';

/// Screen for constructing a ticket offline when the API is unreachable.
/// Allows the user to enter:
/// 1. Route number (Маршрут (№))
/// 2. License plate (Гос номер)
/// Followed by a "Далее" button that navigates to the stop selection screen.
class TicketConstructorScreen extends StatefulWidget {
  final String? initialRouteNumber;
  final String? initialLicensePlate;

  const TicketConstructorScreen({
    super.key,
    this.initialRouteNumber,
    this.initialLicensePlate,
  });

  @override
  State<TicketConstructorScreen> createState() => _TicketConstructorScreenState();
}

class _TicketConstructorScreenState extends State<TicketConstructorScreen> {
  final TextEditingController _routeController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  List<RouteModel> _availableRoutes = [];
  bool _isLoadingRoutes = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialRouteNumber != null && widget.initialRouteNumber!.isNotEmpty) {
      _routeController.text = widget.initialRouteNumber!.replaceAll('№', '').trim();
    }
    if (widget.initialLicensePlate != null && widget.initialLicensePlate!.isNotEmpty) {
      _plateController.text = widget.initialLicensePlate!.trim();
    }
    _loadRoutes();
    _routeController.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _routeController.removeListener(_onRouteChanged);
    _routeController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    final service = MerlinTransportService();
    await service.initOfflineData();
    if (mounted) {
      setState(() {
        _availableRoutes = service.cachedRoutes;
        _isLoadingRoutes = false;
      });
      _onRouteChanged();
    }
  }

  void _onRouteChanged() {
    setState(() {});
    // If user typed a route and plate is empty, suggest the real vehicle license plate
    final routeText = _routeController.text.trim();
    if (routeText.isNotEmpty && _plateController.text.isEmpty) {
      final liveBus = MerlinTransportService().getLiveVehicleForRoute(routeText);
      if (liveBus != null && liveBus.licenseNumber.isNotEmpty) {
        _plateController.text = liveBus.formattedLicenseNumber;
      }
    }
  }

  void _handleNext() async {
    final routeText = _routeController.text.trim();
    if (routeText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, укажите номер маршрута')),
      );
      return;
    }

    String plateText = _plateController.text.trim();
    if (plateText.isEmpty) {
      final liveBus = MerlinTransportService().getLiveVehicleForRoute(routeText);
      plateText = liveBus?.formattedLicenseNumber ?? 'Н 744 СР 69';
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SelectStopScreen(
          routeNumber: routeText,
          licensePlate: plateText,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = _routeController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111217), size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Конструктор билета',
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111217),
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label: "Маршрут (№)"
                    const Text(
                      'Маршрут (№)',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111217),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Route Input field
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Text(
                            '№ ',
                            style: TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B5CFE),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _routeController,
                              keyboardType: TextInputType.text,
                              style: const TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111217),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Введите номер (например, 24)',
                                hintStyle: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 14,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_routeController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () => _routeController.clear(),
                            ),
                        ],
                      ),
                    ),

                    // Quick Route Suggestions Chips
                    if (!_isLoadingRoutes && _availableRoutes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            for (final r in _availableRoutes.take(12))
                              Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ActionChip(
                                  label: Text(
                                    '№${r.name}',
                                    style: TextStyle(
                                      fontFamily: 'NotoSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _routeController.text.trim() == r.name
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  backgroundColor: _routeController.text.trim() == r.name
                                      ? const Color(0xFF3B5CFE)
                                      : const Color(0xFFF1F5F9),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onPressed: () {
                                    _routeController.text = r.name;
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Label: "Гос номер"
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

                    // Plate Input field
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(Icons.directions_bus_rounded, color: Color(0xFF64748B), size: 20),
                          const SizedBox(width: 10),
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
                                hintText: 'Например, Н 744 СР 69',
                                hintStyle: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 14,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_plateController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () => _plateController.clear(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Укажите регистрационный номер транспортного средства (можно посмотреть в салоне)',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action button: "Далее"
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
                    backgroundColor: const Color(0xFF3B5CFE),
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
