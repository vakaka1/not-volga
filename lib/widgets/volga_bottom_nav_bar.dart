import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../theme/app_colors.dart';

class VolgaBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showTopBorder;
  final Color? backgroundColor;

  const VolgaBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showTopBorder = true,
    this.backgroundColor,
  });

  static const List<({String title, String icon, double iconHeight, bool isAction})> _items = [
    (title: 'Новости', icon: AppAssets.icRootbmNews, iconHeight: 25.0, isAction: false),
    (title: 'Карта', icon: AppAssets.icRootbmMap, iconHeight: 20.0, isAction: false),
    (title: 'Оплата', icon: AppAssets.icRootbmActionQr, iconHeight: 72.0, isAction: true),
    (title: 'Сервисы', icon: AppAssets.icRootbmServices, iconHeight: 23.0, isAction: false),
    (title: 'Профиль', icon: AppAssets.icRootbmProfile, iconHeight: 23.0, isAction: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.rootbmBackground,
        border: showTopBorder
            ? const Border(
                top: BorderSide(
                  color: AppColors.rootbmDivider,
                  width: 0.5,
                ),
              )
            : null,
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
                            top: -30,
                            child: Image.asset(
                              item.icon,
                              width: 76,
                              height: 76,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontFamily: 'NotoSans',
                                fontSize: 10.0,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.rootbmElementSelected
                                    : AppColors.rootbmElementTitle,
                                height: 1.1,
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
                        Container(
                          height: 26,
                          alignment: Alignment.center,
                          child: Image.asset(
                            item.icon,
                            height: item.iconHeight,
                            fit: BoxFit.contain,
                            color: isSelected
                                ? AppColors.rootbmElementSelected
                                : AppColors.rootbmElementIcon,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontFamily: 'NotoSans',
                            fontSize: 10.0,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.rootbmElementSelected
                                : AppColors.rootbmElementTitle,
                            height: 1.1,
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
