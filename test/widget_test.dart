import 'package:flutter_test/flutter_test.dart';
import 'package:not_volga/main.dart';
import 'package:not_volga/screens/home_stub_screen.dart';
import 'package:not_volga/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen loads and transitions to HomeStubScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const NotVolgaApp());

    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byType(HomeStubScreen), findsOneWidget);
    expect(find.text('ЗАГЛУШКА'), findsOneWidget);
  });
}
