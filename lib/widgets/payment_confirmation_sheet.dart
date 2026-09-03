import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../services/balance_service.dart';
import '../theme/app_colors.dart';

/// Parsed or simulated information from a scanned transport QR code.
class ScannedTransportInfo {
  final String routeNumber;
  final String transportType;
  final String regNumber;
  final String carrier;
  final String city;
  final int fare;
  final String rawQrData;

  const ScannedTransportInfo({
    required this.routeNumber,
    this.transportType = 'Автобус',
    this.regNumber = 'Е 456 КХ 69',
    this.carrier = 'ООО «Верхневолжское АТП»',
    this.city = 'Тверь',
    this.fare = 40,
    required this.rawQrData,
  });

  factory ScannedTransportInfo.fromRawData(String rawData) {
    // Check if rawData has a specific pattern (e.g. route, vehicle ID or URL)
    String route = '№24';
    String reg = 'Е 456 КХ 69';
    String type = 'Автобус';

    final clean = rawData.trim();
    final lower = clean.toLowerCase();

    if (lower.contains('route=') || lower.contains('marshrut=')) {
      final match = RegExp(r'(?:route|marshrut)=([a-zA-Z0-9а-яА-Я]+)').firstMatch(clean);
      if (match != null && match.group(1) != null) {
        route = '№${match.group(1)}';
      }
    } else if (RegExp(r'^\d{1,3}[а-яА-Я]?$').hasMatch(clean)) {
      route = '№$clean';
    } else if (lower.contains('tram') || lower.contains('трамвай')) {
      type = 'Трамвай';
      route = '№5';
      reg = 'Т 102 ТВ 69';
    } else if (lower.contains('trolley') || lower.contains('троллейбус')) {
      type = 'Троллейбус';
      route = '№3';
      reg = 'Т 345 ТВ 69';
    } else {
      // Generate a deterministic or realistic route based on rawData
      final hash = clean.hashCode.abs();
      final routes = ['№1', '№3', '№6', '№9', '№15', '№21', '№24', '№30', '№33', '№43', '№108', '№208'];
      final regNumbers = ['Е 456 КХ 69', 'В 789 АА 69', 'К 123 ОО 69', 'М 842 ТТ 69', 'О 911 РР 69'];
      route = routes[hash % routes.length];
      reg = regNumbers[hash % regNumbers.length];
    }

    return ScannedTransportInfo(
      routeNumber: route,
      transportType: type,
      regNumber: reg,
      rawQrData: rawData,
    );
  }
}

/// Modal bottom sheet shown upon detecting a QR code for trip payment.
class PaymentConfirmationSheet extends StatefulWidget {
  final ScannedTransportInfo transportInfo;
  final VoidCallback onPaymentSuccess;
  final VoidCallback onCancel;

  const PaymentConfirmationSheet({
    super.key,
    required this.transportInfo,
    required this.onPaymentSuccess,
    required this.onCancel,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ScannedTransportInfo transportInfo,
    required VoidCallback onPaymentSuccess,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentConfirmationSheet(
        transportInfo: transportInfo,
        onPaymentSuccess: () {
          Navigator.of(context).pop(true);
          onPaymentSuccess();
        },
        onCancel: () {
          Navigator.of(context).pop(false);
        },
      ),
    );
  }

  @override
  State<PaymentConfirmationSheet> createState() => _PaymentConfirmationSheetState();
}

class _PaymentConfirmationSheetState extends State<PaymentConfirmationSheet> {
  bool _isPaying = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BalanceService.instance,
      builder: (context, _) {
        final currentBalance = BalanceService.instance.balance;
        final fare = widget.transportInfo.fare;
        final hasSufficientBalance = currentBalance >= fare;

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Оплата проезда',
                    style: TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onCancel,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vehicle & Route Info Card
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.bgPlateStart, AppColors.bgPlateEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                AppAssets.icBus,
                                width: 22,
                                height: 22,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.transportInfo.transportType} ${widget.transportInfo.routeNumber}',
                                  style: const TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  widget.transportInfo.city,
                                  style: TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Reg Number Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black54, width: 1),
                          ),
                          child: Text(
                            widget.transportInfo.regNumber,
                            style: const TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                    const SizedBox(height: 10),
                    Text(
                      widget.transportInfo.carrier,
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Fare & Balance Info
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgGray,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Стоимость проезда:',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$fare ₽',
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(color: Colors.grey.withValues(alpha: 0.2), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFF3B5CFE)),
                            SizedBox(width: 6),
                            Text(
                              'Баланс кошелька:',
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$currentBalance ₽',
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: hasSufficientBalance ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Pay Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isPaying ? null : () => _handlePay(currentBalance, fare),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B5CFE),
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                      : Text(
                          'Оплатить $fare ₽',
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handlePay(int currentBalance, int fare) {
    if (currentBalance < fare) {
      InsufficientFundsDialog.show(context);
      return;
    }
    _processPayment(currentBalance, fare);
  }

  Future<void> _processPayment(int currentBalance, int fare) async {
    setState(() {
      _isPaying = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    await BalanceService.instance.setBalance(currentBalance - fare);

    if (mounted) {
      widget.onPaymentSuccess();
    }
  }
}

/// Dialog presenting the issued digital ticket after successful payment.
class PaymentSuccessDialog extends StatelessWidget {
  final ScannedTransportInfo transportInfo;

  const PaymentSuccessDialog({
    super.key,
    required this.transportInfo,
  });

  static void show(BuildContext context, ScannedTransportInfo transportInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentSuccessDialog(transportInfo: transportInfo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final ticketNumber =
        '№ ${math.Random().nextInt(900000) + 100000}';

    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.icOk,
              width: 58,
              height: 58,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            const Text(
              'Билет успешно оплачен!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Счастливого пути!',
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgGray,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _buildTicketRow('Маршрут', '${transportInfo.transportType} ${transportInfo.routeNumber}'),
                  const SizedBox(height: 8),
                  _buildTicketRow('Госномер', transportInfo.regNumber),
                  const SizedBox(height: 8),
                  _buildTicketRow('Дата и время', '$dateStr $timeStr'),
                  const SizedBox(height: 8),
                  _buildTicketRow('Номер билета', ticketNumber),
                  const SizedBox(height: 8),
                  _buildTicketRow('Стоимость', '${transportInfo.fare} ₽', isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B5CFE),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Готово',
                  style: TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 13.5,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Dialog shown when attempting payment with insufficient balance.
/// Reproduces res/error.webp with exact title, message, shape (BorderRadius.circular(4.0)), and flat "OK" button.
class InsufficientFundsDialog extends StatelessWidget {
  const InsufficientFundsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const InsufficientFundsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
      title: const Text(
        'Ошибка',
        style: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      content: const Text(
        'Недостаточно средств',
        style: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
  }
}

