import 'package:flutter_test/flutter_test.dart';
import 'package:not_volga/main.dart';
import 'package:not_volga/screens/main_screen.dart';
import 'package:not_volga/screens/splash_screen.dart';
import 'package:not_volga/widgets/volga_bottom_nav_bar.dart';

void main() {
  testWidgets('Splash screen loads and transitions to MainScreen with Map default tab', (WidgetTester tester) async {
    await tester.pumpWidget(const NotVolgaApp());

    // Splash screen is displayed first
    expect(find.byType(SplashScreen), findsOneWidget);

    // Wait for transition animation and delay
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // MainScreen is displayed
    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(VolgaBottomNavBar), findsOneWidget);

    // Default tab is "Карта"
    expect(find.text('ЗДЕСЬ БУДЕТ КАРТА'), findsOneWidget);

    // All bottom bar items exist
    expect(find.text('Новости'), findsOneWidget);
    expect(find.text('Карта'), findsOneWidget);
    expect(find.text('Оплата'), findsOneWidget);
    expect(find.text('Сервисы'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);

    // Tap "Новости"
    await tester.tap(find.text('Новости'));
    await tester.pumpAndSettle();
    expect(find.text('ЗДЕСЬ БУДУТ НОВОСТИ'), findsOneWidget);

    // Tap "Оплата"
    await tester.tap(find.text('Оплата'));
    await tester.pumpAndSettle();
    expect(find.text('ЗДЕСЬ БУДЕТ ОПЛАТА'), findsOneWidget);

    // Tap "Сервисы"
    await tester.tap(find.text('Сервисы'));
    await tester.pumpAndSettle();
    expect(find.text('ЗДЕСЬ БУДУТ СЕРВИСЫ'), findsOneWidget);

    // Tap "Профиль"
    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('ЗДЕСЬ БУДЕТ ПРОФИЛЬ'), findsOneWidget);

    // Tap "Карта" back
    await tester.tap(find.text('Карта'));
    await tester.pumpAndSettle();
    expect(find.text('ЗДЕСЬ БУДЕТ КАРТА'), findsOneWidget);
  });
}
