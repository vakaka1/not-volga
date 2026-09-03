import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../widgets/volga_bottom_nav_bar.dart';
import 'map_screen.dart';
import 'news_screen.dart';
import 'payment_qr_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';
import 'splash_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 1, // По умолчанию выбрана «Карта» (индекс 1)
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  int _previousIndex = 1;
  bool _isMapSheetVisible = false;
  late final List<Widget> _pages;

  // Состояние загрузки карты при старте приложения
  bool _isMapReady = false;
  bool _isSplashAnimationDone = false;
  bool _isSplashVisible = true;
  bool _showSplashOverlay = true;

  Timer? _safetyTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _previousIndex = widget.initialIndex;

    _pages = [
      const NewsScreen(),
      MapScreen(
        onSheetVisibilityChanged: (visible) {
          if (_isMapSheetVisible != visible && mounted) {
            setState(() {
              _isMapSheetVisible = visible;
            });
          }
        },
        onMapReady: _onMapReady,
      ),
      PaymentQrScreen(
        isActive: _currentIndex == 2,
        onBack: () => _onTabSelected(_previousIndex == 2 ? 1 : _previousIndex),
      ),
      const ServicesScreen(),
      const ProfileScreen(),
    ];

    // Страховочный тайм-аут на случай задержек платформенного MapKit
    _safetyTimeoutTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _showSplashOverlay) {
        _isMapReady = true;
        _isSplashAnimationDone = true;
        _checkAndDismissSplash();
      }
    });
  }

  void _onMapReady() {
    if (mounted && !_isMapReady) {
      _isMapReady = true;
      _checkAndDismissSplash();
    }
  }

  void _onSplashAnimationDone() {
    if (mounted && !_isSplashAnimationDone) {
      _isSplashAnimationDone = true;
      _checkAndDismissSplash();
    }
  }

  void _checkAndDismissSplash() {
    if (_isMapReady && _isSplashAnimationDone && _isSplashVisible && mounted) {
      _safetyTimeoutTimer?.cancel();
      setState(() {
        _isSplashVisible = false;
      });

      // Переключаем системные панели на тему приложения
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    }
  }

  @override
  void dispose() {
    _safetyTimeoutTimer?.cancel();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      if (_currentIndex != index) {
        _previousIndex = _currentIndex;
      }
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showBottomNav = !(_currentIndex == 1 && _isMapSheetVisible);

    return Stack(
      children: [
        // 1. Основное приложение с картой и нижней панелью
        Scaffold(
          backgroundColor: AppColors.bgMain,
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: showBottomNav
              ? VolgaBottomNavBar(
                  currentIndex: _currentIndex,
                  onTap: _onTabSelected,
                )
              : null,
        ),

        // 2. Страница загрузки (сплэш), поверх приложения во время старта
        if (_showSplashOverlay)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _isSplashVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              onEnd: () {
                if (!_isSplashVisible && mounted) {
                  setState(() {
                    _showSplashOverlay = false;
                  });
                }
              },
              child: SplashScreen(
                onAnimationComplete: _onSplashAnimationDone,
              ),
            ),
          ),
      ],
    );
  }
}
