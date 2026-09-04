import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_screen.dart';
import 'services/balance_service.dart';
import 'services/merlin_transport_service.dart';
import 'services/tariff_service.dart';
import 'services/ticket_service.dart';
import 'services/trip_history_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Отключаем принудительный растянутый режим: настраиваем статус-бар и нижнюю панель навигации
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: AppColors.rootbmDivider,
    ),
  );

  await BalanceService.instance.init();
  await TariffService.instance.init();
  await TripHistoryService.instance.init();
  await TicketService.instance.init();
  // Предзагрузка офлайн-данных маршрутов
  final transport = MerlinTransportService();
  await transport.initOfflineData();
  // Кэшируем детали маршрутов для офлайна (в фоне, не блокируя запуск)
  transport.preCacheAllRouteDetails();
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
      title: 'НЕ-Волга',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: AppScrollBehavior(),
      builder: (context, child) {
        return Container(
          color: Colors.white,
          child: SafeArea(
            top: true,
            bottom: true,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const MainScreen(),
    );
  }
}
