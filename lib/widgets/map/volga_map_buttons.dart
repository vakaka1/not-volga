import 'package:flutter/material.dart';
import '../../constants/app_assets.dart';
import '../../theme/app_colors.dart';

class VolgaMapButtons extends StatelessWidget {
  final VoidCallback onFilterTap;
  final VoidCallback onCenterLocationTap;
  final VoidCallback onBusModeTap;
  final VoidCallback onZoomInTap;
  final VoidCallback onZoomOutTap;
  final VoidCallback onCompassTap;
  final VoidCallback onBlindModeTap;
  final bool isBusModeActive;

  const VolgaMapButtons({
    super.key,
    required this.onFilterTap,
    required this.onCenterLocationTap,
    required this.onBusModeTap,
    required this.onZoomInTap,
    required this.onZoomOutTap,
    required this.onCompassTap,
    required this.onBlindModeTap,
    this.isBusModeActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Левая плавающая кнопка (режим для слабовидящих - очки)
        Positioned(
          left: 16,
          top: 100,
          child: _buildBlindModeButton(),
        ),

        // Правый стек кнопок управления картой
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Кнопка фильтра
              _buildSquareButton(
                icon: Icons.filter_alt,
                onTap: onFilterTap,
              ),
              const SizedBox(height: 10),

              // 2. Кнопка центрирования / прицела
              _buildSquareButton(
                icon: Icons.gps_fixed,
                onTap: onCenterLocationTap,
              ),
              const SizedBox(height: 10),

              // 3. Кнопка транспорта (красный автобус)
              _buildBusModeButton(),
              const SizedBox(height: 32),

              // 4. Блок масштабирования (+ / -)
              _buildZoomControls(),
              const SizedBox(height: 10),

              // 5. Кнопка компаса / навигационной стрелки
              _buildSquareButton(
                icon: Icons.navigation,
                onTap: onCompassTap,
                iconAngle: -0.5,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSquareButton({
    required IconData icon,
    required VoidCallback onTap,
    double iconAngle = 0.0,
    Color iconColor = AppColors.black,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Transform.rotate(
              angle: iconAngle,
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusModeButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onBusModeTap,
          child: Center(
            child: Image.asset(
              AppAssets.icBus,
              width: 24,
              height: 24,
              color: isBusModeActive ? const Color(0xFFE52929) : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              onTap: onZoomInTap,
              child: const SizedBox(
                width: 44,
                height: 42,
                child: Icon(Icons.add, color: AppColors.black, size: 24),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              onTap: onZoomOutTap,
              child: const SizedBox(
                width: 44,
                height: 42,
                child: Icon(Icons.remove, color: AppColors.black, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlindModeButton() {
    return Container(
      width: 48,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onBlindModeTap,
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle_outlined, color: AppColors.white, size: 14),
                SizedBox(
                  width: 6,
                  child: Divider(color: AppColors.white, thickness: 1.5),
                ),
                Icon(Icons.circle_outlined, color: AppColors.white, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
