import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:not_volga/screens/ticket_constructor_screen.dart';
import 'package:not_volga/services/balance_service.dart';
import 'package:not_volga/services/merlin_transport_service.dart';
import 'package:not_volga/services/ticket_service.dart';
import 'package:not_volga/widgets/qr_payment_ok_dialog.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BalanceService.instance.init();
    await BalanceService.instance.setBalance(100);
    await TicketService.instance.init();
    await TicketService.instance.clearTicket();
    await MerlinTransportService().initOfflineData();
  });

  tearDown(() async {
    await TicketService.instance.clearTicket();
  });

  testWidgets('TicketConstructorScreen displays route, plate and Next button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TicketConstructorScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Конструктор билета'), findsOneWidget);
    expect(find.text('Маршрут (№)'), findsOneWidget);
    expect(find.text('Гос номер'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
  });

  testWidgets('Constructor flow: enter route -> Next -> Select Stop -> "Со счета" forms ticket', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TicketConstructorScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Enter route
    await tester.enterText(find.byType(TextField).first, '24');
    await tester.pumpAndSettle();

    // Tap "Далее"
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    // Should now be on SelectStopScreen
    expect(find.text('Выбор остановки'), findsOneWidget);
    expect(find.text('№24'), findsOneWidget);
    expect(find.text('Со счета'), findsOneWidget);
    expect(find.text('40 ₽'), findsOneWidget);

    // Tap "Со счета"
    await tester.tap(find.text('Со счета'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Verification: QrPaymentOkDialog shown ("Оплачено 40 ₽")
    expect(find.byType(QrPaymentOkDialog), findsOneWidget);
    expect(find.text('Оплачено 40 ₽'), findsOneWidget);

    // Verification: Balance was deducted
    expect(BalanceService.instance.balance, 60);

    // Verification: Active ticket was created in TicketService
    expect(TicketService.instance.hasActiveTicket, isTrue);
    expect(TicketService.instance.activeTicket?.routeNumber, '24');

    await TicketService.instance.clearTicket();
  });
}
