import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:not_volga/screens/payment_qr_screen.dart';
import 'package:not_volga/services/balance_service.dart';
import 'package:not_volga/theme/app_colors.dart';
import 'package:not_volga/widgets/payment_confirmation_sheet.dart';
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

    testWidgets('QrScannerOverlay renders yellow contour when barcodes detected',
        (WidgetTester tester) async {
      final barcodeWithCorners = Barcode(
        rawValue: 'https://api.merlin.tvercard.ru/pay?route=24',
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

    testWidgets('Payment confirmation sheet displays correctly and processes trip payment',
        (WidgetTester tester) async {
      final transport = ScannedTransportInfo.fromRawData('https://api.merlin.tvercard.ru/pay?route=24');
      expect(transport.routeNumber, '№24');
      expect(transport.fare, 40);

      await BalanceService.instance.setBalance(100);

      bool paymentSuccessCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PaymentConfirmationSheet.show(
                    context,
                    transportInfo: transport,
                    onPaymentSuccess: () {
                      paymentSuccessCalled = true;
                    },
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open payment sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Check contents
      expect(find.text('Купить билет'), findsOneWidget);
      expect(find.textContaining('№24'), findsOneWidget);
      expect(find.text('Стоимость проезда:'), findsOneWidget);
      expect(find.text('40 ₽'), findsOneWidget);
      expect(find.text('Баланс кошелька:'), findsOneWidget);
      expect(find.text('100 ₽'), findsOneWidget);
      expect(find.text('Купить 40 ₽'), findsOneWidget);

      // Tap Pay button
      await tester.tap(find.text('Купить 40 ₽'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Balance was deducted 100 - 40 = 60
      expect(BalanceService.instance.balance, 60);
      expect(paymentSuccessCalled, isTrue);
    });

    testWidgets('PaymentConfirmationSheet shows error dialog when balance is insufficient',
        (WidgetTester tester) async {
      final transport = ScannedTransportInfo.fromRawData('route=15');
      await BalanceService.instance.setBalance(20); // Not enough for 40 ₽ fare

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PaymentConfirmationSheet.show(
                    context,
                    transportInfo: transport,
                    onPaymentSuccess: () {},
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('20 ₽'), findsOneWidget);
      expect(find.text('Купить 40 ₽'), findsOneWidget);

      // Attempt payment with insufficient funds
      await tester.tap(find.text('Купить 40 ₽'));
      await tester.pumpAndSettle();

      // Error dialog matching res/error.webp is displayed
      expect(find.text('Ошибка'), findsOneWidget);
      expect(find.text('Недостаточно средств'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Tap OK to dismiss error dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Ошибка'), findsNothing);
      expect(find.text('Недостаточно средств'), findsNothing);
    });

    testWidgets('PaymentSuccessDialog displays digital ticket correctly',
        (WidgetTester tester) async {
      final transport = ScannedTransportInfo.fromRawData('route=24');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PaymentSuccessDialog.show(context, transport);
                },
                child: const Text('Show Ticket'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Ticket'));
      await tester.pumpAndSettle();

      expect(find.text('Билет успешно оплачен!'), findsOneWidget);
      expect(find.text('Счастливого пути!'), findsOneWidget);
      expect(find.text('Маршрут'), findsOneWidget);
      expect(find.text('Госномер'), findsOneWidget);
      expect(find.text('Номер билета'), findsOneWidget);
      expect(find.text('Готово'), findsOneWidget);

      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();

      expect(find.text('Билет успешно оплачен!'), findsNothing);
    });
  });
}
