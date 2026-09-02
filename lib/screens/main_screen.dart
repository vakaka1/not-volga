import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/volga_bottom_nav_bar.dart';
import 'news_screen.dart';
import 'payment_qr_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';
import 'tab_placeholder_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _previousIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      if (_currentIndex != index) {
        _previousIndex = _currentIndex;
      }
      _currentIndex = index;
    });
  }

  List<Widget> _buildPages() {
    return [
      const NewsScreen(),
      const TabPlaceholderScreen(title: 'ЗДЕСЬ БУДЕТ КАРТА'),
      PaymentQrScreen(
        isActive: _currentIndex == 2,
        onBack: () => _onTabSelected(_previousIndex == 2 ? 1 : _previousIndex),
      ),
      const ServicesScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: IndexedStack(
        index: _currentIndex,
        children: _buildPages(),
      ),
      bottomNavigationBar: VolgaBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
