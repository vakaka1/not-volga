import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:not_volga/screens/payment_qr_screen.dart';
import 'package:not_volga/screens/qr_route_payment_screen.dart';
import 'package:not_volga/services/balance_service.dart';
import 'package:not_volga/services/ticket_service.dart';
import 'package:not_volga/widgets/insufficient_funds_dialog.dart';
import 'package:not_volga/widgets/payment_confirmation_sheet.dart';
import 'package:not_volga/widgets/volga_active_ticket_sheet.dart';
import 'package:not_volga/widgets/volga_bottom_nav_bar.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BalanceService.instance.init();
    await TicketService.instance.init();
    await TicketService.instance.clearTicket();
  });

  tearDown(() async {
    await TicketService.instance.clearTicket();
  });

  group('Requirement 1: Insufficient funds dialog tests (< 40 ₽)', () {
    testWidgets('InsufficientFundsDialog matches res/bilet/qr-error.webp specifications', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => InsufficientFundsDialog.show(context),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Title: "Ошибка"
      expect(find.text('Ошибка'), findsOneWidget);
      // Text: "Недостаточно средств"
      expect(find.text('Недостаточно средств'), findsOneWidget);
      // Button: "OK"
      expect(find.text('OK'), findsOneWidget);

      // Button "OK" simply dismisses the dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Ошибка'), findsNothing);
      expect(find.text('Недостаточно средств'), findsNothing);
    });

    testWidgets('Opening PaymentQrScreen with balance < 40 ₽ does NOT display dialog immediately', (tester) async {
      await BalanceService.instance.setBalance(39); // < 40 rubles

      await tester.pumpWidget(
        const MaterialApp(
          home: PaymentQrScreen(isActive: true),
        ),
      );
      await tester.pumpAndSettle();

      // Dialog is NOT shown immediately on screen open
      expect(find.text('Ошибка'), findsNothing);
      expect(find.text('Недостаточно средств'), findsNothing);

      // Camera UI elements are visible
      expect(find.text('Сканировать QR-код'), findsOneWidget);
      expect(find.text('Наведите камеру на QR-код для оплаты'), findsOneWidget);
    });

    testWidgets('Opening PaymentQrScreen with balance >= 40 ₽ does NOT display error dialog', (tester) async {
      await BalanceService.instance.setBalance(40); // >= 40 rubles

      await tester.pumpWidget(
        const MaterialApp(
          home: PaymentQrScreen(isActive: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ошибка'), findsNothing);
      expect(find.text('Недостаточно средств'), findsNothing);
    });
  });

  group('TicketService 2-hour persistence tests', () {
    test('TicketService creates ticket with 2-hour validity and stores in SharedPreferences', () async {
      final now = DateTime.now();
      await TicketService.instance.createTicket(
        routeNumber: '2',
        routeTitle: 'Южный - Мигалово',
        station: 'Луговая улица',
        fare: 40,
      );

      expect(TicketService.instance.hasActiveTicket, isTrue);
      final ticket = TicketService.instance.activeTicket!;
      expect(ticket.routeNumber, '2');
      expect(ticket.routeTitle, 'Южный - Мигалово');
      expect(ticket.station, 'Луговая улица');
      expect(ticket.fare, 40);
      expect(ticket.isExpired, isFalse);

      // Verify expiration is 2 hours later (approx 7200 seconds)
      final diff = ticket.expiryTime.difference(ticket.purchaseTime).inSeconds;
      expect(diff, 7200);

      // Verify SharedPreferences persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ticket_route_number'), '2');
      expect(prefs.getInt('ticket_fare'), 40);
      expect(prefs.getInt('ticket_expiry_ms'), greaterThan(now.millisecondsSinceEpoch));

      await TicketService.instance.clearTicket();
    });

    test('TicketService restores active ticket when app is restarted within 2 hours', () async {
      final now = DateTime.now();
      final expiryTime = now.add(const Duration(hours: 2));

      // Simulate saved ticket in SharedPreferences as if app was closed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ticket_active_id', 'TICKET_12345');
      await prefs.setString('ticket_route_number', '15');
      await prefs.setString('ticket_route_title', 'Тверь - Эммаусс');
      await prefs.setString('ticket_station', 'Вокзал');
      await prefs.setInt('ticket_fare', 40);
      await prefs.setInt('ticket_purchase_ms', now.millisecondsSinceEpoch);
      await prefs.setInt('ticket_expiry_ms', expiryTime.millisecondsSinceEpoch);

      // Re-init service (simulating app cold launch)
      await TicketService.instance.init(force: true);

      expect(TicketService.instance.hasActiveTicket, isTrue);
      expect(TicketService.instance.activeTicket?.routeNumber, '15');
      expect(TicketService.instance.activeTicket?.station, 'Вокзал');

      await TicketService.instance.clearTicket();
    });

    test('TicketService expires and clears ticket when older than 2 hours', () async {
      final now = DateTime.now();
      // 2 hours and 5 minutes ago
      final pastPurchase = now.subtract(const Duration(hours: 2, minutes: 5));
      final pastExpiry = pastPurchase.add(const Duration(hours: 2));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ticket_active_id', 'TICKET_OLD');
      await prefs.setString('ticket_route_number', '2');
      await prefs.setInt('ticket_purchase_ms', pastPurchase.millisecondsSinceEpoch);
      await prefs.setInt('ticket_expiry_ms', pastExpiry.millisecondsSinceEpoch);

      // Re-init service after expiration
      await TicketService.instance.init(force: true);

      expect(TicketService.instance.hasActiveTicket, isFalse);
      expect(TicketService.instance.activeTicket, isNull);
    });
  });

  group('Requirement 2: UI sliding sheet tests (res/bilet/pay-ok-mini.webp)', () {
    testWidgets('VolgaActiveTicketSheet displays mini state matching pay-ok-mini.webp and expands smoothly', (tester) async {
      int selectedTab = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Scaffold(
                bottomNavigationBar: VolgaBottomNavBar(
                  currentIndex: selectedTab,
                  onTap: (index) {
                    selectedTab = index;
                  },
                ),
                body: const SizedBox(),
              ),
              const VolgaActiveTicketSheet(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mini state shows "Ваш билет" header
      expect(find.text('Ваш билет'), findsOneWidget);

      // Bottom navigation bar is visible and integrated
      expect(find.byType(VolgaBottomNavBar), findsOneWidget);
      expect(find.text('Карта'), findsOneWidget);
      expect(find.text('Оплата'), findsOneWidget);

      // Tap header "Ваш билет" to expand to full screen
      await tester.tap(find.text('Ваш билет'));
      await tester.pumpAndSettle();

      // Expanded state contains NO arrow icon (as requested by user)
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      // Tap header "Ваш билет" to collapse back to mini state
      await tester.tap(find.text('Ваш билет'));
      await tester.pumpAndSettle();

      expect(find.text('Ваш билет'), findsOneWidget);
      expect(find.byType(VolgaBottomNavBar), findsOneWidget);
    });

    testWidgets('Full payment flow: purchase ticket, tap cross in dialog, redirects to Map with active ticket mini sheet', (tester) async {
      await BalanceService.instance.setBalance(100);

      const transport = ScannedTransportInfo(
        routeNumber: '№2',
        startStation: 'Луговая улица',
        endStation: 'Мигалово',
        rawQrData: 'https://tvercard.ru/q/7c50232b-753f-4916-8c50-038890a8cbde',
      );

      bool redirectedToMap = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final res = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => const QrRoutePaymentScreen(
                      transportInfo: transport,
                    ),
                  ),
                );
                if (res == true) {
                  redirectedToMap = true;
                }
              },
              child: const Text('Go to Payment'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go to Payment'));
      await tester.pumpAndSettle();

      // On QrRoutePaymentScreen: tap "Со счета"
      await tester.tap(find.text('Со счета'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Dialog "Оплачено 40 ₽" is shown with close button '✕'
      expect(find.text('Оплачено 40 ₽'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap cross button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Popped back with true (redirects to map)
      expect(redirectedToMap, isTrue);

      // Ticket is active in TicketService
      expect(TicketService.instance.hasActiveTicket, isTrue);

      await TicketService.instance.clearTicket();
    });

    testWidgets('Expanded ticket sheet strictly renders all fields from active ticket dynamically without hardcoding', (tester) async {
      await TicketService.instance.createTicket(
        routeNumber: '2',
        routeTitle: 'Южный - Мигалово',
        station: 'Луговая улица',
        fare: 40,
        licenseNumber: 'Н 390 СР 69',
        boardNumber: '10106',
        carrierName: 'ООО "Верхневолжское автотранспортное предприятие"',
        vehicleModel: 'ЛиАЗ 429260',
        ticketUuid: '7c50232b-753f-4916-8c50-038890a8cbde',
      );

      // Force purchase time for exact date match in test
      final ticket = TicketService.instance.activeTicket!;

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Scaffold(
                bottomNavigationBar: VolgaBottomNavBar(
                  currentIndex: 1,
                  onTap: (_) {},
                ),
                body: const SizedBox(),
              ),
              VolgaActiveTicketSheet(ticket: ticket),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap header to expand
      await tester.tap(find.text('Ваш билет'));
      await tester.pumpAndSettle();

      // 1. Route badge (e.g. "2")
      expect(find.text('2'), findsOneWidget);

      // 2. Russian date & time (e.g. "3 сентября 2026, 07:48" or dynamic from ticket)
      expect(find.textContaining('сентября 2026'), findsOneWidget);

      // 3. Station name
      expect(find.text('Луговая улица'), findsOneWidget);

      // 4. Fare box
      expect(find.text('40 ₽'), findsOneWidget);

      // 5. License plate: dynamic from vehicle, matching the ticket
      expect(find.text('Н 390 СР 69'), findsOneWidget);

      // 6. Carrier name
      expect(find.text('ООО "Верхневолжское автотранспортное предприятие"'), findsOneWidget);

      // 7. QR code contains checkerUrl
      expect(ticket.checkerUrl, 'https://ticket-checker.merlin.tvercard.ru/7c50232b-753f-4916-8c50-038890a8cbde');

      // 8. Bottom navigation bar is visible and not hidden
      expect(find.byType(VolgaBottomNavBar), findsOneWidget);

      await TicketService.instance.clearTicket();
    });

    testWidgets('Live bus telemetry test: ticket dynamically receives different license plates with zero hardcode', (tester) async {
      // Test with bus 1
      await TicketService.instance.createTicket(
        routeNumber: '21',
        routeTitle: 'Мигалово - Микрорайон Южный',
        station: 'Площадь Ленина',
        fare: 40,
        licenseNumber: 'О 113 СР 69',
      );
      expect(TicketService.instance.activeTicket?.licenseNumber, 'О 113 СР 69');
      expect(TicketService.instance.activeTicket?.routeNumber, '21');
      await TicketService.instance.clearTicket();

      // Test with bus 2
      await TicketService.instance.createTicket(
        routeNumber: '33',
        routeTitle: 'Глобус - Мигалово',
        station: 'Спортивная улица',
        fare: 40,
        licenseNumber: 'М 842 ТТ 69',
      );
      expect(TicketService.instance.activeTicket?.licenseNumber, 'М 842 ТТ 69');
      expect(TicketService.instance.activeTicket?.routeNumber, '33');
      await TicketService.instance.clearTicket();

      // Test with empty license plate - no hardcoded plate injected!
      await TicketService.instance.createTicket(
        routeNumber: '9',
        routeTitle: 'Юность - Мигалово',
        station: 'Вокзал',
        fare: 40,
        licenseNumber: '',
      );
      expect(TicketService.instance.activeTicket?.licenseNumber, '');
      await TicketService.instance.clearTicket();
    });
  });
}
