import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_volga/screens/settings_screen.dart';

void main() {
  group('SettingsScreen Tests', () {
    testWidgets('Displays all elements according to spec',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(
            initialPhoneNumber: '+7 999 789-53-71',
          ),
        ),
      );

      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Номер телефона'), findsOneWidget);
      expect(find.text('+7 999 789-53-71'), findsOneWidget);

      expect(find.text('Виджет Саквояж'), findsOneWidget);
      expect(find.text('Отображать Саквояж\nна экране Сервисы'), findsOneWidget);
      expect(find.byType(CupertinoSwitch), findsOneWidget);

      expect(find.text('Политика конфиденциальности'), findsOneWidget);
      expect(find.text('Условия использования сервиса\nЯндекс.Карты'), findsOneWidget);
      expect(find.text('Новые функции'), findsOneWidget);
      expect(find.text('Выйти из приложения'), findsOneWidget);
      expect(find.text('Версия 3.4.0'), findsOneWidget);
      expect(find.text('Удалить аккаунт'), findsOneWidget);
    });

    testWidgets('Random phone number generates formatted string',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );

      // Verify that phone number starts with +7 9
      final phoneFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.startsWith('+7 9') ?? false),
      );
      expect(phoneFinder, findsOneWidget);
    });

    testWidgets('Sakvoyazh switch toggles properly without affecting other states',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );

      final switchFinder = find.byType(CupertinoSwitch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<CupertinoSwitch>(switchFinder).value, isFalse);

      // Toggle on
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoSwitch>(switchFinder).value, isTrue);

      // Toggle off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoSwitch>(switchFinder).value, isFalse);
    });
  });
}
