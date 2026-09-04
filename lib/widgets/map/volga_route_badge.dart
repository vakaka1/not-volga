import 'package:flutter/material.dart';
import '../../constants/app_assets.dart';

class VolgaRouteBadgeClipper extends CustomClipper<Path> {
  final double radius;
  final double pointWidth;

  const VolgaRouteBadgeClipper({
    this.radius = 4.5,
    this.pointWidth = 9.0,
  });

  @override
  Path getClip(Size size) {
    final path = Path();

    // Верхний левый угол со скруглением
    path.moveTo(radius, 0);
    // Верхняя горизонтальная грань
    path.lineTo(size.width - pointWidth, 0);
    // Скос вниз-вправо к острию стрелки на середине высоты
    path.lineTo(size.width, size.height / 2);
    // Скос вниз-влево к нижней грани
    path.lineTo(size.width - pointWidth, size.height);
    // Нижняя грань
    path.lineTo(radius, size.height);
    // Скругление нижнего левого угла
    path.arcToPoint(Offset(0, size.height - radius), radius: Radius.circular(radius));
    // Левая грань
    path.lineTo(0, radius);
    // Скругление верхнего левого угла
    path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));
    path.close();

    return path;
  }

  @override
  bool shouldReclip(VolgaRouteBadgeClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.pointWidth != pointWidth;
}

class VolgaRouteBadge extends StatelessWidget {
  final String routeName;
  final double width;
  final double height;
  final double fontSize;
  final Color color;

  const VolgaRouteBadge({
    super.key,
    required this.routeName,
    this.width = 76.0,
    this.height = 31.0,
    this.fontSize = 17.0,
    this.color = const Color(0xFF0052FF),
  });

  @override
  Widget build(BuildContext context) {
    final cleanRoute = routeName.replaceAll('№', '').trim();
    final displayRoute = cleanRoute.isNotEmpty ? cleanRoute : routeName;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Оригинальная плашка маршрута со сглаженными краями (assets/images/bg_bus_plate.png),
          // окрашенная в нужный цвет через colorBlendMode
          Positioned.fill(
            child: Image.asset(
              AppAssets.bgBusPlate,
              color: color,
              colorBlendMode: BlendMode.srcIn,
              fit: BoxFit.fill,
            ),
          ),

          // Значок автобуса, аккуратно спозиционированный слева (как в оригинале)
          Positioned(
            left: 7.0,
            child: Image.asset(
              AppAssets.icRoutesBusTight,
              width: 17.0,
              height: 20.0,
              color: Colors.white,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 20.0,
              ),
            ),
          ),

          // Номер маршрута, отцентрированный в полезной области плашки
          Positioned(
            left: 28.0,
            right: 12.0,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  displayRoute,
                  style: TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
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
