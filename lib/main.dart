import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'services/balance_service.dart';
import 'services/ticket_service.dart';
import 'services/trip_history_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BalanceService.instance.init();
  await TripHistoryService.instance.init();
  await TicketService.instance.init();
  runApp(const NotVolgaApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class NotVolgaApp extends StatelessWidget {
  const NotVolgaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOT-Volga',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: AppScrollBehavior(),
      home: const MainScreen(),
    );
  }
}
