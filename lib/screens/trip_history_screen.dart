import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../models/trip_history_item.dart';
import '../services/trip_history_service.dart';
import '../theme/app_colors.dart';

/// Trip history screen displaying past and active ticket purchases strictly matching `res/pay-history.webp`.
///
/// Top app bar (back chevron and title "История поездок") is fixed and does not scroll.
/// The card list is scrollable and supports pull-to-refresh.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  @override
  void initState() {
    super.initState();
    TripHistoryService.instance.init();
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      TripHistoryService.instance.reload(),
      Future.delayed(const Duration(milliseconds: 600)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed top header (Back button and "История поездок") - pinned, does NOT scroll
            _buildFixedHeader(context),

            // Scrollable cards list with pull-to-refresh
            Expanded(
              child: AnimatedBuilder(
                animation: TripHistoryService.instance,
                builder: (context, _) {
                  final items = TripHistoryService.instance.items;
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppColors.primary,
                    backgroundColor: AppColors.white,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        return _TripHistoryCard(item: items[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back Chevron with hit area and precise placement
        Padding(
          padding: const EdgeInsets.only(left: 6.0, top: 8.0),
          child: IconButton(
            splashRadius: 24,
            icon: Image.asset(
              AppAssets.icToolbarBack,
              width: 22,
              height: 22,
              color: AppColors.black,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 22,
                color: AppColors.black,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),

        const SizedBox(height: 12),

        // Screen Title: "История поездок"
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.0),
          child: Text(
            'История поездок',
            style: TextStyle(
              fontFamily: 'NotoSans',
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
              letterSpacing: -0.4,
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

/// Single trip history card strictly matching cards in `res/pay-history.webp`.
class _TripHistoryCard extends StatelessWidget {
  final TripHistoryItem item;

  const _TripHistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          // Ambient shadow around all sides (top, left, right, bottom)
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 6,
            offset: Offset(0, 1),
            spreadRadius: 0,
          ),
          // Key drop shadow downwards
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18.0, 20.0, 20.0, 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Date, Time and Fare
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 17,
                      color: AppColors.black,
                      letterSpacing: -0.2,
                    ),
                    children: [
                      TextSpan(
                        text: item.formattedDate,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ', ${item.formattedTime}',
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.fare} ₽',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontFamilyFallback: ['NotoSans'],
                  fontSize: 19.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // 2. Route title and bold route number
          _buildRouteInfo(),
          const SizedBox(height: 20),

          // 3. Boarding stop (single stop or two stops connected by vertical red line)
          _buildStops(),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    String title = item.routeTitle.trim();
    if (title.endsWith(',')) {
      title = title.substring(0, title.length - 1).trim();
    }
    final cleanNum = item.cleanRouteNumber;

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 16,
          color: AppColors.black,
          height: 1.35,
          letterSpacing: -0.2,
        ),
        children: [
          TextSpan(
            text: '$title, ',
            style: const TextStyle(fontWeight: FontWeight.normal),
          ),
          TextSpan(
            text: '№$cleanNum',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStops() {
    final hasEndStation = item.endStation != null && item.endStation!.trim().isNotEmpty;

    if (!hasEndStation) {
      // Single stop (as in Card 1 & Card 3)
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildStopMarker(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.startStation,
              style: const TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 15.5,
                color: AppColors.black,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      );
    }

    // Two stops connected with a continuous red line (as in Card 2)
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: _buildStopMarker(),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 2.2,
                    color: const Color(0xFFEF0000),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: _buildStopMarker(),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.startStation,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 15.5,
                    color: AppColors.black,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 38),
                Text(
                  item.endStation!,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 15.5,
                    color: AppColors.black,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopMarker() {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        border: Border.all(
          color: const Color(0xFFEF0000),
          width: 2.8,
        ),
      ),
    );
  }
}
