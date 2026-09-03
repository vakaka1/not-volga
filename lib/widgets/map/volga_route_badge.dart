import 'package:flutter/material.dart';

class VolgaRouteBadgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double radius = 8.0;
    const double pointWidth = 14.0; // Ширина выступающей стрелки справа (в точности по res/bus.webp и res/ost.webp)
    final path = Path();

    // Верхний левый угол со скруглением
    path.moveTo(radius, 0);
    // Верхняя горизонтальная грань
    path.lineTo(size.width - pointWidth, 0);
    // Скос вниз-вправо к острию стрелки на середине высоты (size.width, size.height / 2)
    path.lineTo(size.width, size.height / 2);
    // Скос вниз-влево к нижней грани
    path.lineTo(size.width - pointWidth, size.height);
    // Нижняя грань
    path.lineTo(radius, size.height);
    // Скругление нижнего левого угла
    path.arcToPoint(Offset(0, size.height - radius), radius: const Radius.circular(radius));
    // Левая грань
    path.lineTo(0, radius);
    // Скругление верхнего левого угла
    path.arcToPoint(const Offset(radius, 0), radius: const Radius.circular(radius));
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class VolgaRouteBadge extends StatelessWidget {
  final String routeName;
  final double height;
  final double fontSize;

  const VolgaRouteBadge({
    super.key,
    required this.routeName,
    this.height = 36.0,
    this.fontSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: VolgaRouteBadgeClipper(),
      child: Container(
        height: height,
        color: const Color(0xFF0052FF),
        padding: const EdgeInsets.only(left: 10, right: 18),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              routeName,
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
