import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../services/balance_service.dart';
import '../theme/app_colors.dart';
import '../widgets/service_card_icons.dart';
import 'balance_details_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  @override
  void initState() {
    super.initState();
    BalanceService.instance.init();
  }

  Future<void> _openBalanceDetails() async {
    final replenishedAmount = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) => const BalanceDetailsScreen(),
      ),
    );

    if (replenishedAmount != null && mounted) {
      _showSuccessDialog(replenishedAmount);
    }
  }

  void _showSuccessDialog(int amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.0),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppAssets.icOk,
                width: 56,
                height: 56,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              const Text(
                'Баланс успешно пополнен!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Сумма пополнения: $amount ₽',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF165AF0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Top horizontal services cards row (scrollable sideways)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: const [
                            _TopServiceCard(
                              gradient: LinearGradient(
                                colors: [Color(0xFF008CD7), Color(0xFF13CB10)],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                              icon: RubleIcon(size: 38),
                              title: 'Тарифы',
                            ),
                            SizedBox(width: 8),
                            _TopServiceCard(
                              gradient: LinearGradient(
                                colors: [Color(0xFF165AF0), Color(0xFF0934C7)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              icon: TelegramPlaneIcon(size: 38),
                              title: 'Новости\nрегиона',
                            ),
                            SizedBox(width: 8),
                            _TopServiceCard(
                              solidColor: Color(0xFF2D2F2E),
                              icon: GlassesIcon(size: 40),
                              title: 'Для слабо-\nвидящих',
                            ),
                            SizedBox(width: 8),
                            _TopServiceCard(
                              gradient: LinearGradient(
                                colors: [Color(0xFFE11C20), Color(0xFFB3070E)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              icon: RegionBusIcon(size: 38),
                              title: 'Билеты по\nрегиону',
                            ),
                            SizedBox(width: 4),
                          ],
                        ),
                      ),

                      // Expands space between top services and bottom cards
                      const Spacer(),
                      const SizedBox(height: 24),

                      // Card 1: "Транспортные карты"
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: Title + Info icon
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Транспортные карты',
                                    style: TextStyle(
                                      fontFamily: 'NotoSans',
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  _buildInfoCircle(),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Content: Text + Button
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'привязать банковскую\nили транспортную карту',
                                      style: TextStyle(
                                        fontFamily: 'NotoSans',
                                        fontSize: 14.5,
                                        color: AppColors.textPrimary,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF3B5CFE),
                                        width: 1.3,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      minimumSize: const Size(0, 38),
                                    ),
                                    child: const Text(
                                      'Привязать',
                                      style: TextStyle(
                                        fontFamily: 'NotoSans',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF3B5CFE),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Card 2: "Мобильное приложение"
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: Title + Info icon
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Мобильное приложение',
                                    style: TextStyle(
                                      fontFamily: 'NotoSans',
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  _buildInfoCircle(),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Content: Баланс + Абонемент + Пополнить button
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Баланс
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Баланс',
                                        style: TextStyle(
                                          fontFamily: 'NotoSans',
                                          fontSize: 13,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ListenableBuilder(
                                        listenable: BalanceService.instance,
                                        builder: (context, _) {
                                          return Text(
                                            '${BalanceService.instance.balance} ₽',
                                            style: const TextStyle(
                                              fontFamily: 'NotoSans',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 36),
                                  // Абонемент
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Абонемент',
                                        style: TextStyle(
                                          fontFamily: 'NotoSans',
                                          fontSize: 13,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Купить',
                                        style: TextStyle(
                                          fontFamily: 'NotoSans',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  // Button "Пополнить"
                                  OutlinedButton(
                                    onPressed: _openBalanceDetails,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF3B5CFE),
                                        width: 1.3,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      minimumSize: const Size(0, 38),
                                    ),
                                    child: const Text(
                                      'Пополнить',
                                      style: TextStyle(
                                        fontFamily: 'NotoSans',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF3B5CFE),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCircle() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFFD8DCE2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'i',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

class _TopServiceCard extends StatelessWidget {
  final Gradient? gradient;
  final Color? solidColor;
  final Widget icon;
  final String title;

  const _TopServiceCard({
    this.gradient,
    this.solidColor,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 106,
      height: 106,
      decoration: BoxDecoration(
        gradient: gradient,
        color: solidColor,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: icon,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
