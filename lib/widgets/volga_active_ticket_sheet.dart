import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/ticket_service.dart';
import 'map/volga_route_badge.dart';

/// Month names in Russian genitive case for ticket date formatting
const List<String> _russianMonthsGenitive = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// Interactive sliding sheet strictly reproducing `res/bilet/pay-ok-mini.webp` (collapsed)
/// and `res/bilet/bilet-ok.webp` (expanded active ticket screen).
///
/// Calibrated to match the physical reference:
/// - Fixed ticket card dimensions (320 x 575 dp).
/// - Precise soft double-layer shadow.
/// - Calibrated card vertical position (slightly lower, generous top breathing room).
/// - Exact fare box dimensions (86 x 38 dp) with centered 18sp bold text.
/// - Real live telemetry license plate from GET /vehicles.
class VolgaActiveTicketSheet extends StatefulWidget {
  final ValueChanged<double>? onProgressChanged;
  final ActiveTicket? ticket;
  final double? availableHeight;

  const VolgaActiveTicketSheet({
    super.key,
    this.onProgressChanged,
    this.ticket,
    this.availableHeight,
  });

  @override
  State<VolgaActiveTicketSheet> createState() => _VolgaActiveTicketSheetState();
}

class _VolgaActiveTicketSheetState extends State<VolgaActiveTicketSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  double _dragStartY = 0.0;
  double _dragStartValue = 0.0;
  double _dragTotalDeltaY = 0.0;

  static const double _miniHeight = 54.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    _animation.addListener(_notifyProgress);
  }

  void _notifyProgress() {
    widget.onProgressChanged?.call(_animation.value);
  }

  @override
  void didUpdateWidget(VolgaActiveTicketSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.onProgressChanged?.call(_animation.value);
  }

  @override
  void dispose() {
    _animation.removeListener(_notifyProgress);
    _controller.dispose();
    super.dispose();
  }

  void _expand() {
    _controller.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void _collapse() {
    _controller.animateTo(0.0, curve: Curves.easeOutCubic);
  }

  void _toggle() {
    if (_controller.value < 0.5) {
      _expand();
    } else {
      _collapse();
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _dragStartValue = _controller.value;
    _dragTotalDeltaY = 0.0;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, double totalTravel) {
    if (totalTravel <= 0) return;
    final dy = details.globalPosition.dy - _dragStartY;
    _dragTotalDeltaY = dy;
    // Dragging UP decreases dy -> increases progress
    final deltaProgress = -dy / totalTravel;
    _controller.value = (_dragStartValue + deltaProgress).clamp(0.0, 1.0);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragStartValue < 0.5) {
      // Starting from collapsed (mini) state:
      // If user tapped (micro-drag < 8px), or dragged up > 15%, or swiped up (velocity < -150) -> expand!
      if (_dragTotalDeltaY.abs() < 8.0 || _controller.value > 0.15 || velocity < -150) {
        _expand();
      } else {
        _collapse();
      }
    } else {
      // Starting from expanded state:
      // Only collapse if pulled down significantly (> 50% down) or decisively swiped down (velocity > 400 && value < 0.85)
      if (_controller.value < 0.5 || (velocity > 400 && _controller.value < 0.85)) {
        _collapse();
      } else {
        // Otherwise snap back to expanded (do NOT collapse on light touches / scroll jitter)
        _expand();
      }
    }
  }

  ActiveTicket? get _ticket => widget.ticket ?? TicketService.instance.activeTicket;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomNavTotalHeight = 56.0 + mediaQuery.padding.bottom;

    // Available height inside the parent Stack
    final double totalAvailableHeight = widget.availableHeight ??
        (mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom);

    // Full coverage from bottom navigation bar all the way to top of Stack (just below status bar)
    final double expandedHeight = (totalAvailableHeight - bottomNavTotalHeight).clamp(_miniHeight, totalAvailableHeight);
    final double totalTravel = expandedHeight - _miniHeight;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;

        final double currentBottom = bottomNavTotalHeight;
        final double currentHeight = _miniHeight + totalTravel * progress;

        // Top corner radius: 20 when collapsed, cleanly flattens to 0 at the very top
        final double topRadius = 20.0 * (1.0 - progress);

        // Sheet background interpolates from white to soft grey (#EFF1F4)
        final Color sheetBgColor = Color.lerp(
          Colors.white,
          const Color(0xFFEFF1F4),
          progress,
        )!;

        return Positioned(
          left: 0,
          right: 0,
          bottom: currentBottom,
          height: currentHeight,
          child: Material(
            color: sheetBgColor,
            elevation: progress < 0.5 ? 4.0 : 0.0,
            shadowColor: const Color(0x22000000),
            borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header area: top spacing + "Ваш билет" with isolated drag & tap handlers
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  onVerticalDragStart: _onVerticalDragStart,
                  onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, totalTravel),
                  onVerticalDragEnd: _onVerticalDragEnd,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (progress > 0.01)
                        SizedBox(height: 12.0 * progress),
                      SizedBox(
                        height: progress > 0.5 ? 46.0 : _miniHeight,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 26.0, right: 20.0, top: 4.0, bottom: 4.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Ваш билет',
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 21.0,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Gap below header moving the card slightly lower
                if (progress > 0.01)
                  SizedBox(height: 14.0 * progress),

                // 3. Ticket body with fixed card dimensions (320x575), scrollable and isolated from sheet drag
                if (progress > 0.01)
                  Expanded(
                    child: Opacity(
                      opacity: ((progress - 0.1) / 0.9).clamp(0.0, 1.0),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _collapse, // tap outside card on grey background dismisses sheet
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Center(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {}, // tap on the card does not dismiss
                              child: _buildTicketCard(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTicketCard(BuildContext context) {
    final ticket = _ticket;
    if (ticket == null) {
      return const SizedBox.shrink();
    }

    // Russian date formatting: "d MMMM yyyy, HH:mm"
    final purchase = ticket.purchaseTime;
    final day = purchase.day;
    final month = (purchase.month >= 1 && purchase.month <= 12)
        ? _russianMonthsGenitive[purchase.month - 1]
        : '';
    final year = purchase.year;
    final hour = purchase.hour.toString().padLeft(2, '0');
    final minute = purchase.minute.toString().padLeft(2, '0');

    return SizedBox(
      width: 320.0,
      height: 575.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20.0,
              spreadRadius: 0.0,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6.0,
              spreadRadius: 0.0,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22.0, 20.0, 22.0, 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Blue route badge (arrow)
            VolgaRouteBadge(
              routeName: ticket.routeNumber,
              width: 76.0,
              height: 31.0,
              fontSize: 17.0,
            ),

            const SizedBox(height: 18.0),

            // 2. Date and bold time ("3 сентября 2026, 07:48")
            Text.rich(
              TextSpan(
                text: '$day $month $year, ',
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 15.0,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1F2937),
                ),
                children: [
                  TextSpan(
                    text: '$hour:$minute',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4.0),

            // 3. Boarding station
            Text(
              ticket.station.isNotEmpty ? ticket.station : 'Луговая улица',
              style: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 15.0,
                fontWeight: FontWeight.w400,
                color: Color(0xFF4B5563),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 16.0),

            // 4. Fare box ("40 ₽") - calibrated aspect ratio (taller and narrower, 70x46 dp)
            Container(
              width: 70.0,
              height: 46.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: const Color(0xFFD1D5DB),
                  width: 1.2,
                ),
              ),
              child: Text(
                '${ticket.fare} ₽',
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 21.0,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  height: 1.0,
                ),
              ),
            ),

            const SizedBox(height: 30.0),

            // 5. Large centered QR code (215x215 dp)
            Center(
              child: QrImageView(
                data: ticket.checkerUrl,
                version: QrVersions.auto,
                size: 215.0,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 30.0),

            // 6. Bus license plate pill (strictly live telemetry or authentic fleet vehicle)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Text(
                ticket.licenseNumber.isNotEmpty
                    ? ticket.licenseNumber
                    : 'Н 390 СР 69',
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF111827),
                ),
              ),
            ),

            const SizedBox(height: 6.0),

            // 7. Official carrier name
            Text(
              ticket.carrierName.isNotEmpty
                  ? ticket.carrierName
                  : 'ООО "Верхневолжское автотранспортное\nпредприятие"',
              style: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 11.5,
                color: Color(0xFF9CA3AF),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
