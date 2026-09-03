import 'package:flutter/material.dart';

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

  const VolgaRouteBadge({
    super.key,
    required this.routeName,
    this.width = 76.0,
    this.height = 31.0,
    this.fontSize = 17.0,
  });

  @override
  Widget build(BuildContext context) {
    const double pointWidth = 9.0;
    const double radius = 4.5;

    return SizedBox(
      width: width,
      height: height,
      child: ClipPath(
        clipper: const VolgaRouteBadgeClipper(radius: radius, pointWidth: pointWidth),
        child: Container(
          color: const Color(0xFF0052FF),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Крупный значок автобуса, ровно 8dp от левого края (как в оригинале)
              Positioned(
                left: 8.0,
                child: Image.asset(
                  'assets/icons/ic_routes_bus_tight.png',
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
                left: 29.0,
                right: pointWidth + 2.0,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      routeName,
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
        ),
      ),
    );
  }
}
