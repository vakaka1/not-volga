import 'package:flutter/material.dart';
import '../../models/transport/route_details_model.dart';
import '../../models/transport/vehicle_model.dart';
import 'volga_route_badge.dart';

class VolgaBusBottomSheet extends StatefulWidget {
  final VehicleModel vehicle;
  final RouteDetailsModel? routeDetails;
  final VoidCallback? onClose;

  const VolgaBusBottomSheet({
    super.key,
    required this.vehicle,
    this.routeDetails,
    this.onClose,
  });

  @override
  State<VolgaBusBottomSheet> createState() => _VolgaBusBottomSheetState();
}

class _VolgaBusBottomSheetState extends State<VolgaBusBottomSheet> {
  bool _isExpandedStations = false;

  @override
  Widget build(BuildContext context) {
    final startStationName = widget.routeDetails?.startStation.isNotEmpty == true
        ? widget.routeDetails!.startStation
        : 'Мигалово-конечная';
    final endStationName = widget.routeDetails?.finalStation.isNotEmpty == true
        ? widget.routeDetails!.finalStation
        : (widget.vehicle.nextStationName.isNotEmpty ? widget.vehicle.nextStationName : 'Улица Левитана');
    final totalStationsCount = widget.routeDetails?.stations.length ?? 33;

    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.20,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.35, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D8DE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 1. Верхняя плашка в точности по res/bus.webp:
              // [ 🚌  21 ]   [ ♿ ]   [ O 113 CP  69 ]
              Row(
                children: [
                  // Синий бейдж с сужением посередине
                  VolgaRouteBadge(
                    routeName: widget.vehicle.routeName,
                    height: 34,
                    fontSize: 17,
                  ),

                  const SizedBox(width: 8),

                  // Желтый значок инвалида
                  if (widget.vehicle.hasWheelchair) ...[
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

                  // Госномер в рамке
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F1F5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.vehicle.formattedLicenseNumber,
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

              const SizedBox(height: 22),

              // 2. Вертикальный таймлайн маршрута с красными точками (res/bus.webp)
              _buildTimeline(
                startStation: startStationName,
                endStation: endStationName,
                totalCount: totalStationsCount,
              ),

              // 3. Раскрывающийся список всех промежуточных остановок
              if (_isExpandedStations && widget.routeDetails != null && widget.routeDetails!.stations.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE8EAEF), height: 1, thickness: 1),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.routeDetails!.stations.length,
                  itemBuilder: (context, idx) {
                    final station = widget.routeDetails!.stations[idx];
                    final isCurrent = station.name == widget.vehicle.nextStationName;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            isCurrent ? Icons.directions_bus : Icons.circle,
                            size: isCurrent ? 16 : 8,
                            color: isCurrent ? const Color(0xFF0052FF) : const Color(0xFFE52929),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              station.name,
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 15,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                color: isCurrent ? const Color(0xFF0052FF) : const Color(0xFF1E1E1E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Вертикальный таймлайн маршрута:
  /// ●  Мигалово-конечная
  /// |
  /// ●  33 остановки ▼
  /// |
  /// ●  Улица Левитана
  Widget _buildTimeline({
    required String startStation,
    required String endStation,
    required int totalCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Начальная остановка
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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

        // 2. Линия и промежуточный блок
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 4.5),
              width: 3,
              height: 44,
              color: const Color(0xFFE52929),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isExpandedStations = !_isExpandedStations;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                        _isExpandedStations ? Icons.arrow_drop_up : Icons.arrow_drop_down,
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

        // 3. Конечная остановка
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
