import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_volga/screens/profile_screen.dart';
import 'package:not_volga/screens/settings_screen.dart';

void main() {
  group('ProfileScreen Tests', () {
    testWidgets('Displays all 3 buttons correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );

      expect(find.text('История\nпоездок'), findsOneWidget);
      expect(find.text('Поддержка'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('Tapping "Поддержка" opens bottom sheet with "Поддержка"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );

      await tester.tap(find.text('Поддержка'));
      await tester.pumpAndSettle();

      // The bottom sheet is shown with "Поддержка" text (total 2 texts: button + sheet title)
      expect(find.text('Поддержка'), findsNWidgets(2));
    });

    testWidgets('Tapping "Настройки" pushes SettingsScreen and back button pops',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );

      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Номер телефона'), findsOneWidget);
      expect(find.text('Виджет Саквояж'), findsOneWidget);
      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      expect(find.text('Условия использования сервиса\nЯндекс.Карты'), findsOneWidget);
      expect(find.text('Новые функции'), findsOneWidget);
      expect(find.text('Выйти из приложения'), findsOneWidget);
      expect(find.text('Версия 3.4.0'), findsOneWidget);
      expect(find.text('Удалить аккаунт'), findsOneWidget);

      // Tap back button in SettingsScreen
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}
