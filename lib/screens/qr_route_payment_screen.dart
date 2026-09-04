import 'package:flutter/material.dart';
import '../models/transport/route_model.dart';
import '../services/balance_service.dart';
import '../services/merlin_transport_service.dart';
import '../services/tariff_service.dart';
import '../services/ticket_service.dart';
import '../widgets/insufficient_funds_dialog.dart';
import '../widgets/payment_confirmation_sheet.dart';
import '../widgets/qr_payment_ok_dialog.dart';

/// Экран оплаты проезда после сканирования QR-кода или из конструктора.
/// Поддерживает два режима:
/// - Городской (1-2 цифры в номере маршрута): текущая остановка + кнопка «Со счёта»
/// - Пригородный (3+ цифры): текущая остановка + выбор конечной остановки (обе красные точки, красная линия) + динамический расчёт цены
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
  late String _endStation;
  late String _routeTitle;
  late String _routeNumberOnly;
  late List<String> _availableStations;
  late String _regNumber;
  late bool _isSuburban;
  late int _fare;
  bool _isPaying = false;
  bool _isTransfer = false;

  @override
  void initState() {
    super.initState();
    _currentStation = widget.transportInfo.startStation;
    _endStation = widget.transportInfo.endStation;

    final rNum = widget.transportInfo.routeNumber.replaceAll('№', '').trim();
    _routeNumberOnly = rNum;
    _routeTitle = widget.transportInfo.routeTitle;
    _availableStations = List<String>.from(widget.transportInfo.availableStations);
    _regNumber = widget.transportInfo.regNumber;

    if (_regNumber.isEmpty) {
      final liveBus = MerlinTransportService().getLiveVehicleForRoute(rNum);
      if (liveBus != null && liveBus.licenseNumber.isNotEmpty) {
        _regNumber = liveBus.formattedLicenseNumber;
      }
    }

    // Если остановки не переданы — подгружаем из кэша деталей
    if (_availableStations.isEmpty && rNum.isNotEmpty) {
      final details = MerlinTransportService().getRouteDetailsByName(rNum);
      if (details != null && details.stations.isNotEmpty) {
        _availableStations = details.stations.map((s) => s.name).toList();
        if (_currentStation.isEmpty) {
          _currentStation = _availableStations.first;
        }
        if (_endStation.isEmpty) {
          _endStation = _availableStations.last;
        }
      }
    }

    // Определяем тип маршрута: пригородный = 3+ цифры или явный флаг
    final digits = int.tryParse(rNum.replaceAll(RegExp(r'\D'), ''));
    _isSuburban = widget.transportInfo.isIntercity ||
        (digits != null && digits >= 100) ||
        rNum.length >= 3;

    // Проверяем возможность пересадки
    _isTransfer = TicketService.instance.canMakeTransfer(
      transferDurationMinutes: TariffService.instance.getTransferDurationMinutes(),
    );

    _fare = _calculateFare();
  }

  int _calculateFare() {
    if (_isTransfer) {
      return TariffService.instance.getTransferFare();
    }
    if (!_isSuburban) {
      return TariffService.instance.getCityFare();
    }
    // Пригородный — расчёт по расстоянию между выбранными остановками
    if (_currentStation.isNotEmpty && _endStation.isNotEmpty) {
      final distanceKm = MerlinTransportService().computeDistanceBetweenStations(
        widget.transportInfo.routeId,
        _currentStation,
        _endStation,
      );
      if (distanceKm > 0) {
        return TariffService.instance.computeSuburbanFare(distanceKm);
      }
    }
    // Если в конструкторе передали цену
    if (widget.transportInfo.fare > 0) {
      return widget.transportInfo.fare;
    }
    return TariffService.instance.getCityFare();
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

    // Числовая сортировка по номерам
    final sortedRoutes = List<RouteModel>.from(allRoutes);
    sortedRoutes.sort((a, b) {
      final aNum = int.tryParse(a.name.replaceAll(RegExp(r'\D'), '')) ?? 999;
      final bNum = int.tryParse(b.name.replaceAll(RegExp(r'\D'), '')) ?? 999;
      return aNum.compareTo(bNum);
    });

    showModalBottomSheet<RouteModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RoutePickerSheet(
        routes: sortedRoutes,
        currentRoute: _routeNumberOnly,
      ),
    ).then((selectedRoute) async {
      if (selectedRoute != null && mounted) {
        final details = await MerlinTransportService().getRouteDetails(selectedRoute.routeId);
        final title = selectedRoute.title.isNotEmpty ? selectedRoute.title : selectedRoute.startEndStations;
        final stations = details?.stations.map((s) => s.name).toList() ?? [];

        final liveBus = MerlinTransportService().getLiveVehicleForRoute(selectedRoute.name);
        final newReg = (liveBus != null && liveBus.licenseNumber.isNotEmpty)
            ? liveBus.formattedLicenseNumber
            : _regNumber;

        final newDigits = int.tryParse(selectedRoute.name.replaceAll(RegExp(r'\D'), ''));
        final newIsSuburban = (newDigits != null && newDigits >= 100) || selectedRoute.name.length >= 3;

        setState(() {
          _routeTitle = title;
          _routeNumberOnly = selectedRoute.name;
          _availableStations = stations;
          _currentStation = stations.isNotEmpty ? stations.first : '';
          _endStation = stations.isNotEmpty ? stations.last : '';
          _regNumber = newReg;
          _isSuburban = newIsSuburban;
          _fare = _calculateFare();
        });
      }
    });
  }

  void _showStationPicker({required bool isStartStation}) {
    List<String> stations = _availableStations;
    if (stations.isEmpty) {
      final details = MerlinTransportService().getRouteDetailsByName(_routeNumberOnly);
      if (details != null && details.stations.isNotEmpty) {
        stations = details.stations.map((s) => s.name).toList();
      }
    }
    if (stations.isEmpty) {
      stations = MerlinTransportService().cachedStations.map((s) => s.name).toList();
    }

    final title = isStartStation ? 'Где вы сейчас?' : 'Куда выходите?';
    final currentSelection = isStartStation ? _currentStation : _endStation;

    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StationPickerSheet(
        stations: stations,
        currentStation: currentSelection,
        title: title,
      ),
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() {
          if (isStartStation) {
            _currentStation = selected;
          } else {
            _endStation = selected;
          }
          _fare = _calculateFare();
        });
      }
    });
  }

  void _handlePay() {
    final balance = BalanceService.instance.balance;

    if (balance < _fare) {
      InsufficientFundsDialog.show(context);
      return;
    }

    _processPayment(balance, _fare);
  }

  Future<void> _processPayment(int currentBalance, int fare) async {
    setState(() {
      _isPaying = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await BalanceService.instance.setBalance(currentBalance - fare);

    await TicketService.instance.createTicket(
      routeNumber: _routeNumberOnly,
      routeTitle: _routeTitle,
      station: _currentStation,
      endStation: _isSuburban ? _endStation : null,
      fare: fare,
      licenseNumber: _regNumber,
      boardNumber: widget.transportInfo.boardNumber,
      carrierName: widget.transportInfo.carrier.isNotEmpty
          ? widget.transportInfo.carrier
          : '',
      vehicleModel: widget.transportInfo.transportType,
      isTransfer: _isTransfer,
    );

    if (mounted) {
      setState(() {
        _isPaying = false;
      });

      await QrPaymentOkDialog.show(context, fare: fare);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя кнопка «Назад» (<)
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок «Маршрут»
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

                  // Выбор маршрута (без смайликов/картинок — только текст)
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

                  // Блок остановок
                  _buildStationsBlock(),
                ],
              ),
            ),

            const Spacer(),

            // Цена и кнопка «Со счёта»
            Center(
              child: Text(
                '$_fare ₽',
                style: const TextStyle(
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
                    backgroundColor: const Color(0xFF0052FF),
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

  /// Блок остановок: для городского — одна остановка, для пригородного — две с красной линией
  Widget _buildStationsBlock() {
    if (!_isSuburban) {
      return _buildSingleStationRow();
    }
    return _buildSuburbanStationsBlock();
  }

  /// Городской маршрут — одна остановка с красной точкой и вертикальной линией
  Widget _buildSingleStationRow() {
    if (_currentStation.isNotEmpty) {
      return InkWell(
        onTap: () => _showStationPicker(isStartStation: true),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomPaint(
                size: const Size(12, 50),
                painter: _SingleStationMarkerPainter(),
              ),
              const SizedBox(width: 14),
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
      );
    }

    // Остановка не определена
    return InkWell(
      onTap: () => _showStationPicker(isStartStation: true),
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
    );
  }

  /// Пригородный маршрут: ОБЕ точки КРАСНЫЕ, соединительная линия КРАСНАЯ
  Widget _buildSuburbanStationsBlock() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Красный маркер: красная точка сверху, красная линия, красная точка снизу
          CustomPaint(
            size: const Size(12, double.infinity),
            painter: _SuburbanStationsTimelinePainter(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Остановка посадки (Откуда)
                _buildSuburbanStationTile(
                  label: 'Откуда (посадка)',
                  value: _currentStation,
                  placeholder: 'Выберите остановку посадки',
                  onTap: () => _showStationPicker(isStartStation: true),
                ),
                const SizedBox(height: 20),
                // Остановка выхода (Куда выходите)
                _buildSuburbanStationTile(
                  label: 'Куда выходите',
                  value: _endStation,
                  placeholder: 'Выберите остановку выхода',
                  onTap: () => _showStationPicker(isStartStation: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuburbanStationTile({
    required String label,
    required String value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Expanded(
              child: value.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000000),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      placeholder,
                      style: const TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 16,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 22),
          ],
        ),
      ),
    );
  }
}

/// Красный маркер для одной остановки (городской)
class _SingleStationMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const redColor = Color(0xFFE52929);
    final dotPaint = Paint()
      ..color = redColor
      ..style = PaintingStyle.fill;

    const dotRadius = 4.2;
    const center = Offset(dotRadius, dotRadius + 3.0);
    canvas.drawCircle(center, dotRadius, dotPaint);

    final linePaint = Paint()
      ..color = redColor
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

/// Красный таймлайн для двух остановок (пригородный): ОБЕ точки КРАСНЫЕ, линия КРАСНАЯ
class _SuburbanStationsTimelinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const redColor = Color(0xFFE52929);
    final dotPaint = Paint()
      ..color = redColor
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = redColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    const dotRadius = 4.2;
    const topY = 11.0;
    final bottomY = size.height - 11.0;

    // Верхняя красная точка
    canvas.drawCircle(const Offset(dotRadius, topY), dotRadius, dotPaint);

    // Соединительная красная линия
    canvas.drawLine(
      const Offset(dotRadius, topY + dotRadius),
      Offset(dotRadius, bottomY - dotRadius),
      linePaint,
    );

    // Нижняя красная точка
    canvas.drawCircle(Offset(dotRadius, bottomY), dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Модальный экран выбора маршрута с поиском, сохраняющим состояние при скрытии клавиатуры
class _RoutePickerSheet extends StatefulWidget {
  final List<RouteModel> routes;
  final String currentRoute;

  const _RoutePickerSheet({
    required this.routes,
    required this.currentRoute,
  });

  @override
  State<_RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends State<_RoutePickerSheet> {
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
          // Поиск также по остановкам маршрута
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
                  color: Color(0xFF000000),
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
                      final isSelected = r.name == widget.currentRoute;
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
  }
}

/// Модальный экран выбора остановки с поиском, сохраняющим состояние при скрытии клавиатуры
class _StationPickerSheet extends StatefulWidget {
  final List<String> stations;
  final String currentStation;
  final String title;

  const _StationPickerSheet({
    required this.stations,
    required this.currentStation,
    required this.title,
  });

  @override
  State<_StationPickerSheet> createState() => _StationPickerSheetState();
}

class _StationPickerSheetState extends State<_StationPickerSheet> {
  late final TextEditingController _controller;
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _filtered = widget.stations;
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
        _filtered = widget.stations;
      } else {
        _filtered = widget.stations.where((s) => s.toLowerCase().contains(q)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: const TextStyle(
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
              controller: _controller,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск остановки...',
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
                    itemCount: _filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 20),
                    itemBuilder: (context, index) {
                      final st = _filtered[index];
                      final isSelected = st == widget.currentStation;
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
  }
}
