import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../services/balance_service.dart';
import '../theme/app_colors.dart';
import 'replenish_screen.dart';

class BalanceDetailsScreen extends StatefulWidget {
  final String? phoneNumber;

  const BalanceDetailsScreen({
    super.key,
    this.phoneNumber,
  });

  @override
  State<BalanceDetailsScreen> createState() => _BalanceDetailsScreenState();
}

class _BalanceDetailsScreenState extends State<BalanceDetailsScreen> {
  late final String _phoneNumber;

  @override
  void initState() {
    super.initState();
    _phoneNumber = widget.phoneNumber ?? _generateRandomPhoneNumber();
  }

  static String _generateRandomPhoneNumber() {
    final random = Random();
    final p1 = 900 + random.nextInt(100); // 900-999
    final p2 = 100 + random.nextInt(900); // 100-999
    final p3 = (10 + random.nextInt(90)).toString().padLeft(2, '0'); // 10-99
    final p4 = (10 + random.nextInt(90)).toString().padLeft(2, '0'); // 10-99
    return '+7 $p1 $p2-$p3-$p4';
  }

  Future<void> _openReplenish() async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) => const ReplenishScreen(),
      ),
    );

    if (result != null && mounted) {
      // Return to services screen to show the success dialog
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color headerBg = Color(0xFF556077);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Column(
        children: [
          // Top dark header
          Container(
            color: headerBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    const Text(
                      'Мобильное приложение',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone row with avatar
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Image.asset(
                              AppAssets.logoRound,
                              width: 32,
                              height: 32,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _phoneNumber,
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Balance row
                    ListenableBuilder(
                      listenable: BalanceService.instance,
                      builder: (context, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Баланс',
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 17,
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '${BalanceService.instance.balance} ₽',
                              style: const TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // "Пополнить" button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _openReplenish,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Пополнить',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // "Абонементы" title
                    const Text(
                      'Абонементы',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // "Купить абонемент" button (non-clickable)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Купить абонемент',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // "История" title
                    const Text(
                      'История',
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),

          // Lower light section with infinite loading
          Expanded(
            child: Container(
              color: AppColors.bgMain,
              child: const Center(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF094C99)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
