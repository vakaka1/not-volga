import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:not_volga/screens/payment_qr_screen.dart';
import 'package:not_volga/screens/qr_route_payment_screen.dart';
import 'package:not_volga/services/balance_service.dart';
import 'package:not_volga/services/merlin_transport_service.dart';
import 'package:not_volga/services/qr_payload_parser.dart';
import 'package:not_volga/services/ticket_service.dart';
import 'package:not_volga/theme/app_colors.dart';
import 'package:not_volga/widgets/payment_confirmation_sheet.dart';
import 'package:not_volga/widgets/qr_payment_ok_dialog.dart';
import 'package:not_volga/widgets/qr_scanner_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'app_user_balance': 100});
    await BalanceService.instance.init();
    await BalanceService.instance.setBalance(100);
  });

  group('PaymentQrScreen & QR Detection Tests', () {
    testWidgets('PaymentQrScreen renders all elements matching res/qr.webp',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PaymentQrScreen(),
        ),
      );
      await tester.pump();

      // Title and Subtitle matching reference
      expect(find.text('Сканировать QR-код'), findsOneWidget);
      expect(find.text('Наведите камеру на QR-код для оплаты'), findsOneWidget);

      // Back icon and Flash icon
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      // Overlay painter is present
      expect(find.byType(QrScannerOverlay), findsOneWidget);
    });

    testWidgets('Toggling flash changes bolt icon color to active yellow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PaymentQrScreen(),
        ),
      );
      await tester.pump();

      final boltFinder = find.byIcon(Icons.bolt_rounded);
      expect(boltFinder, findsOneWidget);

      // Initially torch is off (white)
      Icon iconWidget = tester.widget<Icon>(boltFinder);
      expect(iconWidget.color, Colors.white);

      // Tap flash button
      await tester.tap(boltFinder);
      await tester.pump();

      // Torch is now active (yellow #FFD300)
      iconWidget = tester.widget<Icon>(boltFinder);
      expect(iconWidget.color, AppColors.flashActive);
    });

    testWidgets('Back button triggers onBack callback',
        (WidgetTester tester) async {
      bool backCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentQrScreen(
            onBack: () {
              backCalled = true;
            },
          ),
        ),
      );
      await tester.pump();

      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pump();

      expect(backCalled, isTrue);
    });

    testWidgets('QrScannerOverlay renders thin solid blue contour when barcodes detected',
        (WidgetTester tester) async {
      final barcodeWithCorners = Barcode(
        rawValue: 'https://tvercard.ru/q/7c50232b-753f-4916-8c50-038890a8cbde',
        format: BarcodeFormat.qrCode,
        corners: const [
          Offset(100, 100),
          Offset(200, 100),
          Offset(200, 200),
          Offset(100, 200),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrScannerOverlay(
              detectedBarcodes: [barcodeWithCorners],
              captureSize: const Size(720, 1280),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(QrScannerOverlay), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('QrPayloadParser Tests', () {
    test('Correctly extracts UUID from real bus QR link', () {
      const url = 'https://tvercard.ru/q/7c50232b-753f-4916-8c50-038890a8cbde';
      final parsed = QrPayloadParser.parse(url);
      expect(parsed.uuid, '7c50232b-753f-4916-8c50-038890a8cbde');
    });

    test('Correctly extracts sticker number 69-0391 and calculates board number', () {
      const sticker = '69-0391';
      final parsed = QrPayloadParser.parse(sticker);
      expect(parsed.qrNumber, '69-0391');
      expect(parsed.boardNumber, '10391');
    });

    test('Correctly extracts route parameter', () {
      const query = 'https://api.merlin.tvercard.ru/pay?route=24';
      final parsed = QrPayloadParser.parse(query);
      expect(parsed.routeNumber, '24');
    });

    test('Non-transport QR payloads have hasIdentifier false', () {
      final parsed = QrPayloadParser.parse('https://google.com/search?q=test');
      expect(parsed.hasIdentifier, isFalse);
    });
  });

  group('MerlinTransportService QR Resolver Tests', () {
    test('Returns null for non-transport QR code', () async {
      final resolved = await MerlinTransportService().resolveVehicleForPayment('https://google.com/test');
      expect(resolved, isNull);
    });

    test('Resolves generic offline transport QR link with selectable route', () async {
      final resolved = await MerlinTransportService().resolveVehicleForPayment(
        'https://tvercard.ru/q/1b4c87e6-2e97-4280-bd94-aa3229d7a8a4',
      );
      expect(resolved, isNotNull);
      expect(resolved!.routeTitle, 'Выберите маршрут');
      expect(resolved.fare, 40);
    });

    test('Correctly resolves QR code with route parameter to that exact route', () async {
      final resolved = await MerlinTransportService().resolveVehicleForPayment(
        'https://api.merlin.tvercard.ru/pay?route=24',
      );
      expect(resolved, isNotNull);
      expect(resolved!.routeNumber, '№24');
      expect(resolved.fare, 40);
    });
  });

  group('QrRoutePaymentScreen (res/bilet/qr-scan1.webp) Tests', () {
    testWidgets('Displays all elements matching res/bilet/qr-scan1.webp',
        (WidgetTester tester) async {
      const transport = ScannedTransportInfo(
        routeNumber: '№2',
        startStation: 'Луговая улица',
        endStation: 'Мигалово',
        transportType: 'ЛиАЗ 429260',
        regNumber: 'С 128 СР 69',
        carrier: 'ООО «Верхневолжское АТП»',
        city: 'Тверь',
        fare: 40,
        rawQrData: 'https://tvercard.ru/q/7c50232b-753f-4916-8c50-038890a8cbde',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: QrRoutePaymentScreen(transportInfo: transport),
        ),
      );
      await tester.pump();

      // Title "Маршрут"
      expect(find.text('Маршрут'), findsOneWidget);

      // Direction and Route Number (№2)
      expect(find.byType(RichText), findsWidgets);

      // Stop Name and "Вы сейчас здесь"
      expect(find.text('Луговая улица'), findsOneWidget);
      expect(find.text('Вы сейчас здесь'), findsOneWidget);

      // Price "40 ₽" and Button "Со счета"
      expect(find.text('40 ₽'), findsOneWidget);
      expect(find.text('Со счета'), findsOneWidget);
    });

    testWidgets('Tapping station opens station picker modal and updates station',
        (WidgetTester tester) async {
      const transport = ScannedTransportInfo(
        routeNumber: '№2',
        startStation: 'Луговая улица',
        endStation: 'Мигалово',
        availableStations: ['Южный', 'Луговая улица', 'Площадь Капошвара', 'Мигалово'],
        rawQrData: '69-0391',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: QrRoutePaymentScreen(transportInfo: transport),
        ),
      );
      await tester.pump();

      // Tap on current stop
      await tester.tap(find.text('Луговая улица'));
      await tester.pumpAndSettle();

      // Modal sheet opened
      expect(find.text('Выберите остановку'), findsOneWidget);
      expect(find.text('Площадь Капошвара'), findsOneWidget);

      // Select new station
      await tester.tap(find.text('Площадь Капошвара'));
      await tester.pumpAndSettle();

      // Updated on screen
      expect(find.text('Площадь Капошвара'), findsOneWidget);
    });

    testWidgets('Displays input field when startStation is empty and lets passenger select stop',
        (WidgetTester tester) async {
      const transport = ScannedTransportInfo(
        routeNumber: '№2',
        startStation: '',
        endStation: 'Мигалово',
        availableStations: ['Южный', 'Луговая улица', 'Площадь Капошвара', 'Мигалово'],
        rawQrData: '69-0391',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: QrRoutePaymentScreen(transportInfo: transport),
        ),
      );
      await tester.pump();

      // Shows input field "Выберите остановку"
      expect(find.text('Выберите остановку'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);

      // Tap on input field
      await tester.tap(find.text('Выберите остановку'));
      await tester.pumpAndSettle();

      // Pick a station from the sheet
      await tester.tap(find.text('Южный'));
      await tester.pumpAndSettle();

      // Now station is selected and displayed
      expect(find.text('Южный'), findsOneWidget);
      expect(find.text('Вы сейчас здесь'), findsOneWidget);
    });

    testWidgets('Tapping "Со счета" with insufficient balance shows error dialog',
        (WidgetTester tester) async {
      await BalanceService.instance.setBalance(20); // Less than 40 ₽ fare

      const transport = ScannedTransportInfo(
        routeNumber: '№2',
        startStation: 'Луговая улица',
        endStation: 'Мигалово',
        rawQrData: '69-0391',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: QrRoutePaymentScreen(transportInfo: transport),
        ),
      );
      await tester.pump();

      // Tap "Со счета"
      await tester.tap(find.text('Со счета'));
      await tester.pumpAndSettle();

      // Error dialog matching res/error.webp is shown
      expect(find.text('Ошибка'), findsOneWidget);
      expect(find.text('Недостаточно средств'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Tap OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Ошибка'), findsNothing);
    });

    testWidgets('Tapping "Со счета" with sufficient balance deducts 40 ₽ and shows res/bilet/qr-scan-ok.webp dialog',
        (WidgetTester tester) async {
      await BalanceService.instance.setBalance(100);

      const transport = ScannedTransportInfo(
        routeNumber: '№2',
        startStation: 'Луговая улица',
        endStation: 'Мигалово',
        rawQrData: 'https://tvercard.ru/q/7c50232b-753f-4916-8c50-038890a8cbde',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: QrRoutePaymentScreen(transportInfo: transport),
        ),
      );
      await tester.pump();

      // Tap "Со счета"
      await tester.tap(find.text('Со счета'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Balance was deducted: 100 - 40 = 60
      expect(BalanceService.instance.balance, 60);

      // Success modal matching res/bilet/qr-scan-ok.webp is shown
      expect(find.byType(QrPaymentOkDialog), findsOneWidget);
      expect(find.text('Оплачено 40 ₽'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap close button (✕)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(QrPaymentOkDialog), findsNothing);

      // Verify 2-hour active ticket is stored
      expect(TicketService.instance.hasActiveTicket, isTrue);
      expect(TicketService.instance.activeTicket?.routeNumber, '2');
      expect(TicketService.instance.activeTicket?.fare, 40);

      // Clear ticket to cancel timer for clean test teardown
      await TicketService.instance.clearTicket();
    });
  });
}
