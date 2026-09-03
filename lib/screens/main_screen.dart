import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/volga_bottom_nav_bar.dart';
import 'map_screen.dart';
import 'news_screen.dart';
import 'payment_qr_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';

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
      ),
      PaymentQrScreen(
        isActive: _currentIndex == 2,
        onBack: () => _onTabSelected(_previousIndex == 2 ? 1 : _previousIndex),
      ),
      const ServicesScreen(),
      const ProfileScreen(),
    ];
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

    return Scaffold(
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
    );
  }
}
