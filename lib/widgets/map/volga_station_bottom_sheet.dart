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
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF707070),
                ),
              ),

              const SizedBox(height: 2),

              // 2. Название остановки (жирный крупный заголовок)
              Text(
                widget.station.name,
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 4),

              // 3. Адрес
              Text(
                widget.station.address.isNotEmpty ? widget.station.address : 'Тверь, Советская улица',
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 15,
                  color: Color(0xFF707070),
                ),
              ),

              const SizedBox(height: 14),

              // 4. Большая синяя кнопка "Посмотреть расписание"
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.onScheduleTap ?? () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Посмотреть расписание',
                    style: TextStyle(
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

              // 5. Список рейсов / прибывающего транспорта
              if (widget.isLoadingArrivals && widget.arrivals.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0052FF)),
                    ),
                  ),
                ),
              ] else if (widget.arrivals.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Нет данных о ближайших рейсах',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 14,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.arrivals.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFFE8EAEF), height: 1, thickness: 1),
                  itemBuilder: (context, index) {
                    final item = widget.arrivals[index];
                    return _buildArrivalItem(context, item);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Строка рейса в точности как на res/ost.webp:
  /// [ 🚌 20 ► ]  [ ♿ ]  [ Н 756 СР  69 ]      7 мин
  ///                                          15 мин
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // 1. Синий бейдж маршрута с острием наружу
            VolgaRouteBadge(
              routeName: item.routeName,
              height: 36,
              fontSize: 18,
            ),

            const SizedBox(width: 8),

            // 2. Желтый значок доступности (инвалидная коляска)
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

            // 3. Плашка госномера
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

            // 4. Время прибытия (справа)
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
}
