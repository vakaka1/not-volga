import 'package:flutter/material.dart';
import '../../models/transport/station_arrival_model.dart';
import '../../models/transport/station_model.dart';
import 'volga_route_badge.dart';

class VolgaStationBottomSheet extends StatefulWidget {
  final StationModel station;
  final List<StationArrivalModel> arrivals;
  final bool isLoadingArrivals;
  final VoidCallback? onScheduleTap;
  final ValueChanged<StationArrivalModel>? onRouteSelected;
  final VoidCallback? onClose;

  const VolgaStationBottomSheet({
    super.key,
    required this.station,
    this.arrivals = const [],
    this.isLoadingArrivals = false,
    this.onScheduleTap,
    this.onRouteSelected,
    this.onClose,
  });

  @override
  State<VolgaStationBottomSheet> createState() => _VolgaStationBottomSheetState();
}

class _VolgaStationBottomSheetState extends State<VolgaStationBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.20,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.38, 0.95],
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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

              // 1. Надпись "Остановка"
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

              // 2. Название остановки (аккуратный заголовок)
              Text(
                widget.station.name,
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

              // 3. Адрес
              Text(
                widget.station.address.isNotEmpty ? widget.station.address : 'Тверь, улица Дарвина',
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8E8E93),
                ),
              ),

              const SizedBox(height: 13),

              // 4. Большая синяя кнопка "Посмотреть расписание"
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: widget.onScheduleTap ?? () {},
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

              // 5. Список рейсов / прибывающего транспорта (только в течение часа)
              Builder(
                builder: (context) {
                  final visibleArrivals = widget.arrivals.where((a) {
                    final mins = a.minutesToFirstArrival;
                    return mins != null && mins <= 60;
                  }).toList();

                  if (widget.isLoadingArrivals && visibleArrivals.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0052FF)),
                        ),
                      ),
                    );
                  } else if (visibleArrivals.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Нет данных о ближайших рейсах на этот час',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 14,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    );
                  } else {
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: visibleArrivals.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Color(0xFFEDEDED), height: 1, thickness: 1),
                      itemBuilder: (context, index) {
                        final item = visibleArrivals[index];
                        return _buildArrivalItem(context, item);
                      },
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Строка рейса в точности как на res/ost.webp / res/app/original.webp:
  Widget _buildArrivalItem(BuildContext context, StationArrivalModel item) {
    return InkWell(
      onTap: () {
        if (widget.onRouteSelected != null) {
          widget.onRouteSelected!(item);
        } else {
          Navigator.of(context).pop(item);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Синий бейдж маршрута с фиксированным размером
            VolgaRouteBadge(
              routeName: item.routeName,
              width: 76,
              height: 31,
              fontSize: 16,
            ),

            // 2. Желтый значок доступности (инвалидная коляска)
            if (item.hasWheelchair && item.licenseNumber != null && item.licenseNumber!.isNotEmpty) ...[
              const SizedBox(width: 8),
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

            // 3. Плашка госномера
            if (item.licenseNumber != null && item.licenseNumber!.isNotEmpty) ...[
              const SizedBox(width: 6),
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

            // 4. Время прибытия (справа)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.primaryTimeText,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
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
}
