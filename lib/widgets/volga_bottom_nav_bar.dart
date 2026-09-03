import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../theme/app_colors.dart';

class VolgaBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const VolgaBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<({String title, String icon, bool isAction})> _items = [
    (title: 'Новости', icon: AppAssets.icRootbmNews, isAction: false),
    (title: 'Карта', icon: AppAssets.icRootbmMap, isAction: false),
    (title: 'Оплата', icon: AppAssets.icRootbmActionQr, isAction: true),
    (title: 'Сервисы', icon: AppAssets.icRootbmServices, isAction: false),
    (title: 'Профиль', icon: AppAssets.icRootbmProfile, isAction: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.rootbmBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.rootbmDivider,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = currentIndex == index;

              if (item.isAction) {
                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(index),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: -16,
                            child: Image.asset(
                              item.icon,
                              width: 72,
                              height: 72,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.rootbmElementSelected
                                    : AppColors.rootbmElementTitle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          item.icon,
                          height: 27,
                          fit: BoxFit.contain,
                          color: isSelected
                              ? AppColors.rootbmElementSelected
                              : AppColors.rootbmElementIcon,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.rootbmElementSelected
                                : AppColors.rootbmElementTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
