import 'package:flutter/material.dart';
import '../models/transport/route_model.dart';
import '../services/balance_service.dart';
import '../services/merlin_transport_service.dart';
import '../services/ticket_service.dart';
import '../widgets/insufficient_funds_dialog.dart';
import '../widgets/payment_confirmation_sheet.dart';
import '../widgets/qr_payment_ok_dialog.dart';

/// Screen strictly reproducing `res/bilet/qr-scan1.webp`.
/// Displays the route header, direction, current stop with a red pin/line marker,
/// interactive stop selector (or input field when stop is unknown), price "40 ₽",
/// and the "Со счета" payment button.
class QrRoutePaymentScreen extends StatefulWidget {
  final ScannedTransportInfo transportInfo;
  final VoidCallback? onBack;

  const QrRoutePaymentScreen({
    super.key,
    required this.transportInfo,
    this.onBack,
  });

  @override
  State<QrRoutePaymentScreen> createState() => _QrRoutePaymentScreenState();
}

class _QrRoutePaymentScreenState extends State<QrRoutePaymentScreen> {
  late String _currentStation;
  late String _routeTitle;
  late String _routeNumberOnly;
  late List<String> _availableStations;
  late String _regNumber;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    // Use real live station if available, otherwise empty so passenger can pick
    _currentStation = widget.transportInfo.startStation;

    // Clean route number (e.g. "№24" -> "24")
    final rNum = widget.transportInfo.routeNumber.replaceAll('№', '').trim();
    _routeNumberOnly = rNum;

    // Route title (e.g. "Южный – микрорайон Радужный")
    _routeTitle = widget.transportInfo.routeTitle;

    _availableStations = List<String>.from(widget.transportInfo.availableStations);

    _regNumber = widget.transportInfo.regNumber;
    if (_regNumber.isEmpty) {
      final liveBus = MerlinTransportService().getLiveVehicleForRoute(rNum);
      if (liveBus != null && liveBus.licenseNumber.isNotEmpty) {
        _regNumber = liveBus.formattedLicenseNumber;
      }
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _showRoutePicker() {
    final allRoutes = MerlinTransportService().cachedRoutes;
    if (allRoutes.isEmpty) return;

    showModalBottomSheet<RouteModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allRoutes.where((r) {
              final query = searchQuery.toLowerCase();
              return r.name.toLowerCase().contains(query) ||
                  r.title.toLowerCase().contains(query) ||
                  r.startEndStations.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
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
                          color: Color(0xFF000000),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Поиск маршрута (№ или направление)...',
                        hintStyle: const TextStyle(
                          fontFamily: 'NotoSans',
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 20),
                      itemBuilder: (context, index) {
                        final r = filtered[index];
                        final isSelected = r.name == _routeNumberOnly;
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
                              color: Color(0xFF000000),
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
          },
        );
      },
    ).then((selectedRoute) async {
      if (selectedRoute != null && mounted) {
        final details = await MerlinTransportService().getRouteDetails(selectedRoute.routeId);
        final title = selectedRoute.title.isNotEmpty ? selectedRoute.title : selectedRoute.startEndStations;
        final stations = details?.stations.map((s) => s.name).toList() ?? [];

        final liveBus = MerlinTransportService().getLiveVehicleForRoute(selectedRoute.name);
        final newReg = (liveBus != null && liveBus.licenseNumber.isNotEmpty)
            ? liveBus.formattedLicenseNumber
            : _regNumber;

        setState(() {
          _routeTitle = title;
          _routeNumberOnly = selectedRoute.name;
          _availableStations = stations;
          _currentStation = '';
          _regNumber = newReg;
        });
      }
    });
  }

  void _showStationPicker() {
    if (_availableStations.isEmpty) {
      _showRoutePicker();
      return;
    }

    final stations = _availableStations;

    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = stations
                .where((s) => s.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Выберите остановку',
                        style: TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Search box
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Поиск остановки...',
                        hintStyle: const TextStyle(
                          fontFamily: 'NotoSans',
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),

                  // Stations List
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Остановка не найдена',
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 20),
                            itemBuilder: (context, index) {
                              final st = filtered[index];
                              final isSelected = st == _currentStation;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                                title: Text(
                                  st,
                                  style: TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF0052FF) : const Color(0xFF000000),
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_rounded, color: Color(0xFF0052FF), size: 22)
                                    : null,
                                onTap: () => Navigator.of(context).pop(st),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() {
          _currentStation = selected;
        });
      }
    });
  }

  void _handlePay() {
    final balance = BalanceService.instance.balance;
    const fare = 40;

    if (balance < fare) {
      InsufficientFundsDialog.show(context);
      return;
    }

    _processPayment(balance, fare);
  }

  Future<void> _processPayment(int currentBalance, int fare) async {
    setState(() {
      _isPaying = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await BalanceService.instance.setBalance(currentBalance - fare);

    // Create active 2-hour ticket with live bus telemetry
    await TicketService.instance.createTicket(
      routeNumber: _routeNumberOnly,
      routeTitle: _routeTitle,
      station: _currentStation,
      fare: fare,
      licenseNumber: _regNumber,
      boardNumber: widget.transportInfo.boardNumber,
      carrierName: widget.transportInfo.carrier.isNotEmpty
          ? widget.transportInfo.carrier
          : 'ООО "Верхневолжское автотранспортное предприятие"',
      vehicleModel: widget.transportInfo.transportType.isNotEmpty
          ? widget.transportInfo.transportType
          : 'ЛиАЗ 429260',
    );

    if (mounted) {
      setState(() {
        _isPaying = false;
      });

      // Show payment success dialog strictly matching res/bilet/qr-scan-ok.webp
      await QrPaymentOkDialog.show(context, fare: fare);

      if (mounted) {
        // Return true to redirect directly to the map screen
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9), // Subtle off-white matching reference
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top back button (<) matching res/bilet/qr-scan1.webp
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0),
              child: InkWell(
                onTap: _handleBack,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF000000),
                    size: 22,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Main Content Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title: "Маршрут"
                  const Text(
                    'Маршрут',
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000000),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Direction and Route Number (e.g. "Южный - Мигалово, №2" or "Выберите маршрут")
                  InkWell(
                    onTap: _showRoutePicker,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: _routeNumberOnly.isNotEmpty
                          ? RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 18,
                                  color: Color(0xFF000000),
                                  letterSpacing: -0.2,
                                ),
                                children: [
                                  TextSpan(
                                    text: '$_routeTitle, ',
                                    style: const TextStyle(fontWeight: FontWeight.w400),
                                  ),
                                  TextSpan(
                                    text: '№$_routeNumberOnly',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.directions_bus_outlined, color: Color(0xFF0052FF), size: 22),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Выберите маршрут',
                                      style: TextStyle(
                                        fontFamily: 'NotoSans',
                                        fontSize: 16,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 22),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Station block: either red pin stop indicator or input field when unknown
                  if (_currentStation.isNotEmpty)
                    InkWell(
                      onTap: _showStationPicker,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Red dot & vertical line marker
                            CustomPaint(
                              size: const Size(12, 50),
                              painter: _RedStationMarkerPainter(),
                            ),
                            const SizedBox(width: 14),

                            // Station name and "Вы сейчас здесь"
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentStation,
                                    style: const TextStyle(
                                      fontFamily: 'NotoSans',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF000000),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Вы сейчас здесь',
                                    style: TextStyle(
                                      fontFamily: 'NotoSans',
                                      fontSize: 14,
                                      color: Color(0xFF8E8E93),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Input field when stop is unknown as requested
                    InkWell(
                      onTap: _showStationPicker,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: Color(0xFFE52929), size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Выберите остановку',
                                style: TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 16,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 22),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const Spacer(),

            // Bottom Section: Centered Price "40 ₽" and Button "Со счета"
            Center(
              child: const Text(
                '40 ₽',
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000000),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 18.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isPaying ? null : _handlePay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF), // Vibrant royal blue
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18.0),
                    ),
                  ),
                  child: _isPaying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Со счета',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
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

class _RedStationMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Red dot on top
    final dotPaint = Paint()
      ..color = const Color(0xFFE52929)
      ..style = PaintingStyle.fill;

    const dotRadius = 4.2;
    const center = Offset(dotRadius, dotRadius + 3.0);
    canvas.drawCircle(center, dotRadius, dotPaint);

    // Red vertical line going down
    final linePaint = Paint()
      ..color = const Color(0xFFE52929)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      const Offset(dotRadius, dotRadius * 2 + 3.0),
      Offset(dotRadius, size.height),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
