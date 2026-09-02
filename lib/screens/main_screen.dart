import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/volga_bottom_nav_bar.dart';
import 'news_screen.dart';
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

  final List<Widget> _pages = const [
    NewsScreen(),
    TabPlaceholderScreen(title: 'ЗДЕСЬ БУДЕТ КАРТА'),
    TabPlaceholderScreen(title: 'ЗДЕСЬ БУДЕТ ОПЛАТА'),
    ServicesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: VolgaBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
