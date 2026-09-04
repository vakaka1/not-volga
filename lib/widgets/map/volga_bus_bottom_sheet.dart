import 'package:flutter/material.dart';
import '../../models/transport/route_details_model.dart';
import '../../models/transport/station_model.dart';
import '../../models/transport/vehicle_model.dart';
import 'volga_route_badge.dart';

enum TimelineLineType {
  none,
  start,
  full,
  transition,
  end,
}

class TimelineDotPainter extends CustomPainter {
  final TimelineLineType lineType;
  final Color dotColor;
  final Color lineColor;
  final Color? transitionTopColor;
  final double dotRadius;

  const TimelineDotPainter({
    required this.lineType,
    required this.dotColor,
    required this.lineColor,
    this.transitionTopColor,
    this.dotRadius = 3.75,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    const double lineWidth = 2.5;

    final linePaint = Paint()
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    switch (lineType) {
      case TimelineLineType.none:
        break;
      case TimelineLineType.start:
        linePaint.color = lineColor;
        canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), linePaint);
        break;
      case TimelineLineType.full:
        linePaint.color = lineColor;
        canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), linePaint);
        break;
      case TimelineLineType.transition:
        linePaint.color = transitionTopColor ?? lineColor;
        canvas.drawLine(Offset(cx, 0), Offset(cx, cy), linePaint);
        linePaint.color = lineColor;
        canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), linePaint);
        break;
      case TimelineLineType.end:
        linePaint.color = lineColor;
        canvas.drawLine(Offset(cx, 0), Offset(cx, cy), linePaint);
        break;
    }

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant TimelineDotPainter oldDelegate) =>
      oldDelegate.lineType != lineType ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.transitionTopColor != transitionTopColor ||
      oldDelegate.dotRadius != dotRadius;
}

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
  bool _isPassedStopsExpanded = false;
  bool _isRemainingStopsExpanded = false;

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

  @override
  Widget build(BuildContext context) {
    final List<StationModel> routeStations = widget.routeDetails?.stations ?? [];

    final startStationName = widget.routeDetails?.startStation.isNotEmpty == true
        ? widget.routeDetails!.startStation
        : (routeStations.isNotEmpty ? routeStations.first.name : 'Автовокзал');
    final endStationName = widget.routeDetails?.finalStation.isNotEmpty == true
        ? widget.routeDetails!.finalStation
        : (routeStations.isNotEmpty ? routeStations.last.name : 'Васильевский Мох');
    final currentStationName = widget.vehicle.nextStationName.isNotEmpty
        ? widget.vehicle.nextStationName
        : (routeStations.length > 2 ? routeStations[routeStations.length ~/ 2].name : 'Поворот на аэропорт');

    List<StationModel> passedStations = [];
    List<StationModel> remainingStations = [];

    if (routeStations.length >= 3) {
      int curIdx = routeStations.indexWhere((s) => s.name == currentStationName);
      if (curIdx == -1 && widget.vehicle.nextStationId != null) {
        curIdx = routeStations.indexWhere((s) => s.stationId == widget.vehicle.nextStationId);
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

    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.25,
      maxChildSize: 0.90,
      snap: true,
      snapSizes: const [0.42, 0.90],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D8DE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 1. Верхняя плашка (БЕЗ кнопки закрытия): [ 🚌 107 ] [ ♿ ] [ H 263 CP 69 ]
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    VolgaRouteBadge(
                      routeName: widget.vehicle.routeName,
                      width: 76,
                      height: 31,
                      fontSize: 17,
                    ),
                    if (widget.vehicle.hasWheelchair) ...[
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
                    if (widget.vehicle.licenseNumber.isNotEmpty) ...[
                      SizedBox(width: widget.vehicle.hasWheelchair ? 10 : 12),
                      Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F1F5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.vehicle.formattedLicenseNumber,
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

              const Divider(
                indent: 22,
                endIndent: 20,
                color: Color(0xFFEDEDED),
                height: 1,
                thickness: 1,
              ),

              // 2. Таймлайн остановок
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Начальная остановка (серая)
                    _buildStationRow(
                      lineType: TimelineLineType.start,
                      dotColor: const Color(0xFFBEBEBE),
                      lineColor: const Color(0xFFCCCCCC),
                      dotRadius: 3.75,
                      stationName: startStationName,
                      textColor: const Color(0xFF9E9E9E),
                      fontWeight: FontWeight.w400,
                      showDivider: true,
                    ),

                    // Блок "N остановок" перед текущей (проехали)
                    if (passedCount > 0) ...[
                      _buildAccordionRow(
                        isExpanded: _isPassedStopsExpanded,
                        onTap: () {
                          setState(() {
                            _isPassedStopsExpanded = !_isPassedStopsExpanded;
                          });
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
                          _buildSubStationRow(
                            name: st.name,
                            lineColor: const Color(0xFFCCCCCC),
                            dotColor: const Color(0xFFBEBEBE),
                            textColor: const Color(0xFF9E9E9E),
                          ),
                      ],
                    ],

                    // Текущая остановка (красная)
                    _buildStationRow(
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

                    // Блок "N остановок" после текущей (осталось)
                    if (remainingCount > 0) ...[
                      _buildAccordionRow(
                        isExpanded: _isRemainingStopsExpanded,
                        onTap: () {
                          setState(() {
                            _isRemainingStopsExpanded = !_isRemainingStopsExpanded;
                          });
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
                          _buildSubStationRow(
                            name: st.name,
                            lineColor: const Color(0xFFF70000),
                            dotColor: const Color(0xFFF70000),
                            textColor: const Color(0xFF1E1E1E),
                          ),
                      ],
                    ],

                    // Конечная остановка (красная)
                    _buildStationRow(
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildStationRow({
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

  Widget _buildAccordionRow({
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

  Widget _buildSubStationRow({
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
}
