import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_assets.dart';
import '../services/merlin_transport_service.dart';
import '../theme/app_colors.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.primaryDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // Предзагрузка офлайн карты и геопозиции во время сплэш-скрина
    _preWarmMapData();
  }

  Future<void> _preWarmMapData() async {
    // Параллельно инициализируем офлайн базу данных Твери
    try {
      MerlinTransportService().initOfflineData();
      Geolocator.checkPermission().then((perm) async {
        if (perm == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
      }).catchError((_) {});
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Оригинальный фирменный фон Volga
          Image.asset(
            AppAssets.bgLauncher,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.expand(),
          ),

          // 2. Оригинальный белый логотип «Волга» строго по центру
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset(
                AppAssets.logoWhite,
                width: 230,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
