import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HomeStubScreen extends StatelessWidget {
  const HomeStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Center(
        child: Text(
          'ЗАГЛУШКА',
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
