import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_assets.dart';
import '../services/balance_service.dart';
import '../theme/app_colors.dart';

class ReplenishScreen extends StatefulWidget {
  const ReplenishScreen({super.key});

  @override
  State<ReplenishScreen> createState() => _ReplenishScreenState();
}

class _ReplenishScreenState extends State<ReplenishScreen> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int? _selectedPreset;
  bool _isProcessing = false;

  final List<int> _presetAmounts = const [
    40,
    80,
    160,
    240,
    400,
    800,
    1200,
    1600,
  ];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onTextChanged);
    _amountController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _amountController.text.replaceAll(' ', '');
    final val = int.tryParse(text);
    setState(() {
      if (val != null && _presetAmounts.contains(val)) {
        _selectedPreset = val;
      } else {
        _selectedPreset = null;
      }
    });
  }

  void _selectPreset(int amount) {
    if (_isProcessing) return;
    setState(() {
      _selectedPreset = amount;
      _amountController.text = amount.toString();
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountController.text.length),
      );
    });
  }

  int get _currentAmount {
    final text = _amountController.text.replaceAll(' ', '');
    return int.tryParse(text) ?? 0;
  }

  Future<void> _submitReplenish() async {
    final amount = _currentAmount;
    if (amount <= 0 || _isProcessing) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isProcessing = true;
    });

    // Random duration between 3 and 5 seconds (3000 to 5000 ms)
    final delayMs = 3000 + Random().nextInt(2001);
    await Future.delayed(Duration(milliseconds: delayMs));

    if (!mounted) return;

    // Add to balance service
    BalanceService.instance.addBalance(amount);

    // Return amount to previous screens
    Navigator.of(context).pop(amount);
  }

  String _formatPresetLabel(int val) {
    if (val >= 1000) {
      final thousands = val ~/ 1000;
      final remainder = val % 1000;
      return '$thousands ${remainder.toString().padLeft(3, '0')} ₽';
    }
    return '$val ₽';
  }

  @override
  Widget build(BuildContext context) {
    final hasAmount = _currentAmount > 0;

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        backgroundColor: AppColors.bgMain,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 4.0),
                            child: IconButton(
                              icon: Image.asset(
                                AppAssets.icToolbarBack,
                                width: 22,
                                height: 22,
                                color: AppColors.black,
                              ),
                              splashRadius: 24,
                              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                            ),
                          ),

                    // Title
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 24.0),
                      child: Text(
                        'Пополнить баланс',
                        style: TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),

                    // Preset buttons grid: 2 rows of 4 columns
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          // Row 1: 40, 80, 160, 240
                          Row(
                            children: [
                              for (int i = 0; i < 4; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: _buildPresetCard(_presetAmounts[i]),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Row 2: 400, 800, 1200, 1600
                          Row(
                            children: [
                              for (int i = 4; i < 8; i++) ...[
                                if (i > 4) const SizedBox(width: 8),
                                Expanded(
                                  child: _buildPresetCard(_presetAmounts[i]),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Custom input field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE2E5E9),
                            width: 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _amountController,
                          focusNode: _focusNode,
                          enabled: !_isProcessing,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: const TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Сумма пополнения',
                            hintStyle: TextStyle(
                              fontFamily: 'NotoSans',
                              fontSize: 16,
                              color: Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),

                    // Fee text
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18.0, 10.0, 18.0, 20.0),
                      child: Text(
                        'Комиссия 0.6%',
                        style: TextStyle(
                          fontFamily: 'NotoSans',
                          fontSize: 14,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action button: "Пополнить"
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 20.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (hasAmount && !_isProcessing) ? _submitReplenish : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasAmount
                        ? const Color(0xFF3B5CFE)
                        : const Color(0xFFD1D5DB),
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
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
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Loading overlay matching QR scanner connecting animation
            if (_isProcessing) _buildConnectingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: const Color(0x33000000),
          alignment: Alignment.center,
          child: Container(
            width: 68,
            height: 68,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xB3000000),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3.5,
              color: AppColors.qrContourYellow,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetCard(int amount) {
    final isSelected = _selectedPreset == amount;
    return Material(
      color: isSelected ? const Color(0xFFE5E9EE) : const Color(0xFFF1F3F5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _selectPreset(amount),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFF3B5CFE), width: 1.5)
                : null,
          ),
          child: Text(
            _formatPresetLabel(amount),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSans',
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
