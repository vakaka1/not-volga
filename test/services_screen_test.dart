import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:not_volga/screens/balance_details_screen.dart';
import 'package:not_volga/screens/replenish_screen.dart';
import 'package:not_volga/screens/services_screen.dart';
import 'package:not_volga/services/balance_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BalanceService.instance.init();
    await BalanceService.instance.setBalance(0);
  });

  group('Services Screen & Flow Tests', () {
    testWidgets('Displays all services cards and sections properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ServicesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Top service cards
      expect(find.text('Тарифы'), findsOneWidget);
      expect(find.text('Новости\nрегиона'), findsOneWidget);
      expect(find.text('Для слабо-\nвидящих'), findsOneWidget);
      expect(find.text('Билеты по\nрегиону'), findsOneWidget);

      // Section 1: Transport cards
      expect(find.text('Транспортные карты'), findsOneWidget);
      expect(find.text('привязать банковскую\nили транспортную карту'), findsOneWidget);
      expect(find.text('Привязать'), findsOneWidget);

      // Section 2: Mobile application
      expect(find.text('Мобильное приложение'), findsOneWidget);
      expect(find.text('Баланс'), findsOneWidget);
      expect(find.text('0 ₽'), findsOneWidget);
      expect(find.text('Абонемент'), findsOneWidget);
      expect(find.text('Купить'), findsOneWidget);
      expect(find.text('Пополнить'), findsOneWidget);
    });

    testWidgets('Full flow: Services -> Balance details -> Replenish -> Success dialog -> Updated balance',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ServicesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial balance is 0
      expect(find.text('0 ₽'), findsOneWidget);

      // Tap "Пополнить" on Services screen
      await tester.tap(find.widgetWithText(OutlinedButton, 'Пополнить'));
      // BalanceDetailsScreen has an infinite spinner, so pump duration rather than pumpAndSettle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Now on BalanceDetailsScreen
      expect(find.byType(BalanceDetailsScreen), findsOneWidget);
      expect(find.text('Мобильное приложение'), findsOneWidget);
      expect(find.text('Абонементы'), findsOneWidget);
      expect(find.text('Купить абонемент'), findsOneWidget);
      expect(find.text('История'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tap "Пополнить" on BalanceDetailsScreen
      await tester.tap(find.widgetWithText(ElevatedButton, 'Пополнить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Now on ReplenishScreen
      expect(find.byType(ReplenishScreen), findsOneWidget);
      expect(find.text('Пополнить баланс'), findsOneWidget);
      expect(find.text('40 ₽'), findsOneWidget);
      expect(find.text('160 ₽'), findsOneWidget);
      expect(find.text('1 200 ₽'), findsOneWidget);
      expect(find.text('Комиссия 0.6%'), findsOneWidget);

      // Select preset 160 ₽
      await tester.tap(find.text('160 ₽'));
      await tester.pump();

      // Submit replenishment
      await tester.tap(find.widgetWithText(ElevatedButton, 'Пополнить'));
      await tester.pumpAndSettle();

      // Returned to ServicesScreen and success dialog is shown
      expect(find.byType(ServicesScreen), findsOneWidget);
      expect(find.text('Баланс успешно пополнен!'), findsOneWidget);
      expect(find.text('Сумма пополнения: 160 ₽'), findsOneWidget);
      expect(find.text('Ок'), findsOneWidget);

      // Dismiss success dialog
      await tester.tap(find.text('Ок'));
      await tester.pumpAndSettle();

      // Dialog is gone, updated balance 160 ₽ is displayed
      expect(find.text('Баланс успешно пополнен!'), findsNothing);
      expect(find.text('160 ₽'), findsOneWidget);
    });
  });
}
