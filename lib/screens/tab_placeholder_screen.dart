import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TabPlaceholderScreen extends StatelessWidget {
  final String title;

  const TabPlaceholderScreen({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NotoSans',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
