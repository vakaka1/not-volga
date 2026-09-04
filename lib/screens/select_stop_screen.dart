import 'package:flutter/material.dart';
import '../models/transport/route_model.dart';
import '../services/balance_service.dart';
import '../services/merlin_transport_service.dart';
import '../services/tariff_service.dart';
import '../services/ticket_service.dart';
import '../theme/app_colors.dart';
import '../widgets/insufficient_funds_dialog.dart';
import '../widgets/qr_payment_ok_dialog.dart';

/// Экран выбора остановки для конструктора/офлайн-режима.
/// Используется как fallback, если QrRoutePaymentScreen не может быть показан напрямую.
class SelectStopScreen extends StatefulWidget {
  final String routeNumber;
  final String licensePlate;
  final String? initialStation;

  const SelectStopScreen({
    super.key,
    required this.routeNumber,
    required this.licensePlate,
    this.initialStation,
  });

  @override
  State<SelectStopScreen> createState() => _SelectStopScreenState();
}

class _SelectStopScreenState extends State<SelectStopScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _routeStations = [];
  List<String> _filteredStations = [];
  String _selectedStation = '';
  String _routeTitle = '';
  bool _isLoading = true;
  bool _isPaying = false;
  int _fare = 0;

  @override
  void initState() {
    super.initState();
    _selectedStation = widget.initialStation ?? '';
    _loadStations();
    _searchController.addListener(_filterStations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    final service = MerlinTransportService();
    await service.initOfflineData();

    final cleanRoute = widget.routeNumber.replaceAll('№', '').trim();
    final allRoutes = service.cachedRoutes;

    RouteModel? matchedRoute;
    for (final r in allRoutes) {
      if (r.name.toLowerCase() == cleanRoute.toLowerCase()) {
        matchedRoute = r;
        break;
      }
    }

    List<String> stations = [];
    String title = 'Маршрут №$cleanRoute';

    if (matchedRoute != null) {
      title = matchedRoute.title.isNotEmpty
          ? matchedRoute.title
          : (matchedRoute.startEndStations.isNotEmpty
              ? matchedRoute.startEndStations
              : 'Маршрут №$cleanRoute');

      final details = await service.getRouteDetails(matchedRoute.routeId, preferOffline: true);
      if (details != null && details.stations.isNotEmpty) {
        stations = details.stations.map((s) => s.name).toList();
      }
    }

    // Fallback: все остановки из кэша (без привязки к маршруту)
    if (stations.isEmpty && service.cachedStations.isNotEmpty) {
      stations = service.cachedStations.map((s) => s.name).toList();
    }

    // Определяем стоимость
    final isTransfer = TicketService.instance.canMakeTransfer(
      transferDurationMinutes: TariffService.instance.getTransferDurationMinutes(),
    );
    int fare;
    if (isTransfer) {
      fare = TariffService.instance.getTransferFare();
    } else {
      fare = TariffService.instance.getCityFare();
    }

    if (mounted) {
      setState(() {
        _routeTitle = title;
        _routeStations = stations;
        _filteredStations = stations;
        _fare = fare;
        if (_selectedStation.isEmpty && stations.isNotEmpty) {
          _selectedStation = stations.first;
        }
        _isLoading = false;
      });
    }
  }

  void _filterStations() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredStations = _routeStations;
      } else {
        _filteredStations = _routeStations
            .where((s) => s.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _handlePay() async {
    if (_selectedStation.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите остановку')),
      );
      return;
    }

    final balance = BalanceService.instance.balance;

    if (balance < _fare) {
      InsufficientFundsDialog.show(context);
      return;
    }

    setState(() {
      _isPaying = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await BalanceService.instance.setBalance(balance - _fare);

    final cleanRoute = widget.routeNumber.replaceAll('№', '').trim();
    final formattedPlate = formatRussianLicensePlate(widget.licensePlate);

    final isTransfer = TicketService.instance.canMakeTransfer(
      transferDurationMinutes: TariffService.instance.getTransferDurationMinutes(),
    );

    await TicketService.instance.createTicket(
      routeNumber: cleanRoute,
      routeTitle: _routeTitle,
      station: _selectedStation,
      fare: _fare,
      licenseNumber: formattedPlate.isNotEmpty ? formattedPlate : '',
      boardNumber: '',
      carrierName: '',
      vehicleModel: '',
      isTransfer: isTransfer,
    );

    if (mounted) {
      setState(() {
        _isPaying = false;
      });

      await QrPaymentOkDialog.show(context, fare: _fare);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanRoute = widget.routeNumber.replaceAll('№', '').trim();

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
          'Выбор остановки',
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
            // Карточка маршрута
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B5CFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '№$cleanRoute',
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _routeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111217),
                            ),
                          ),
                          if (widget.licensePlate.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Гос номер: ${formatRussianLicensePlate(widget.licensePlate)}',
                              style: const TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Поиск
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search, color: Color(0xFF94A3B8), size: 22),
                    hintText: 'Поиск остановки...',
                    hintStyle: TextStyle(
                      fontFamily: 'NotoSans',
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),

            // Список остановок
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B5CFE)))
                  : _filteredStations.isEmpty
                      ? const Center(
                          child: Text(
                            'Остановка не найдена',
                            style: TextStyle(
                              fontFamily: 'NotoSans',
                              color: Color(0xFF94A3B8),
                              fontSize: 15,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          itemCount: _filteredStations.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final station = _filteredStations[index];
                            final isSelected = station == _selectedStation;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedStation = station;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    // Точка вместо иконки
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF3B5CFE) : const Color(0xFF94A3B8),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        station,
                                        style: TextStyle(
                                          fontFamily: 'NotoSans',
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? const Color(0xFF3B5CFE) : const Color(0xFF111217),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF3B5CFE),
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Стоимость и кнопка оплаты
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Стоимость поездки:',
                        style: TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 15,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '$_fare ₽',
                        style: const TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111217),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_selectedStation.isNotEmpty && !_isPaying) ? _handlePay : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B5CFE),
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isPaying
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Со счета',
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
