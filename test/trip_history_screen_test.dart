import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:not_volga/constants/app_assets.dart';
import 'package:not_volga/models/trip_history_item.dart';
import 'package:not_volga/screens/profile_screen.dart';
import 'package:not_volga/screens/trip_history_screen.dart';
import 'package:not_volga/services/ticket_service.dart';
import 'package:not_volga/services/trip_history_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TicketService.instance.init();
    await TicketService.instance.clearTicket();
    await TripHistoryService.instance.clearForTest();
    await TripHistoryService.instance.init();
  });

  tearDown(() async {
    await TicketService.instance.clearTicket();
    await TripHistoryService.instance.clearForTest();
  });

  group('TripHistoryScreen Tests', () {
    testWidgets('Tapping "История поездок" in ProfileScreen opens TripHistoryScreen and back button pops back',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );

      // Verify button exists in ProfileScreen
      expect(find.text('История\nпоездок'), findsOneWidget);

      // Tap on "История поездок"
      await tester.tap(find.text('История\nпоездок'));
      await tester.pumpAndSettle();

      // TripHistoryScreen is now opened
      expect(find.byType(TripHistoryScreen), findsOneWidget);
      expect(find.text('История поездок'), findsOneWidget);

      // Back button exists with icToolbarBack
      final backFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == AppAssets.icToolbarBack,
      );
      expect(backFinder, findsOneWidget);

      // Tap back button
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Popped back to ProfileScreen
      expect(find.byType(TripHistoryScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('Displays baseline cards strictly matching res/pay-history.webp specifications',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TripHistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header is present
      expect(find.text('История поездок'), findsOneWidget);

      // Card 1: Сегодня, 07:48 | 40 ₽ | Южный - Мигалово, №2 | Луговая улица
      expect(find.textContaining('Сегодня', findRichText: true), findsAtLeastNWidgets(1));
      expect(find.text('40 ₽'), findsAtLeastNWidgets(1));
      expect(find.text('Луговая улица'), findsOneWidget);

      // Card 2: 31 августа, 07:48 | 46 ₽ | пос. Мамулино - пос. Заволжский, №204 | Заволжский-2 -> Улица Фрунзе
      expect(find.textContaining('31 августа', findRichText: true), findsOneWidget);
      expect(find.text('46 ₽'), findsOneWidget);
      expect(find.text('Заволжский-2'), findsOneWidget);
      expect(find.text('Улица Фрунзе'), findsOneWidget);

      // Card 3: 28 августа, 16:30 | 40 ₽ | завод Центросвар - улица Левитана, №30 | Гимназия №12
      expect(find.textContaining('28 августа', findRichText: true), findsOneWidget);
      expect(find.text('Гимназия №12'), findsOneWidget);

      // Pull-to-refresh exists and functions
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Content persists after refresh
      expect(find.text('История поездок'), findsOneWidget);
      expect(find.text('Луговая улица'), findsOneWidget);
    });

    testWidgets('Header does not scroll while cards list is scrollable',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TripHistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final headerPositionBefore = tester.getTopLeft(find.text('История поездок'));

      // Scroll the cards list down
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pump();

      final headerPositionAfter = tester.getTopLeft(find.text('История поездок'));

      // Header did not move at all
      expect(headerPositionBefore, equals(headerPositionAfter));
    });

    testWidgets('When a new ticket is purchased, it is displayed at the top with "Сегодня", current time, route, stop and fare',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TripHistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Purchase a new ticket via TicketService
      await TicketService.instance.createTicket(
        routeNumber: '24',
        routeTitle: 'ТЦ «Метро» - 1-я за линией',
        station: 'Бурашевский путепровод',
        fare: 40,
        licenseNumber: 'М 842 ТТ 69',
        boardNumber: '10391',
      );

      await tester.pumpAndSettle();

      // The new trip is now visible in the list
      expect(find.text('Бурашевский путепровод'), findsOneWidget);

      // Verify the first item in the list is the newly purchased ticket
      final items = TripHistoryService.instance.items;
      expect(items.first.routeNumber, equals('24'));
      expect(items.first.routeTitle, equals('ТЦ «Метро» - 1-я за линией'));
      expect(items.first.startStation, equals('Бурашевский путепровод'));
      expect(items.first.fare, equals(40));
      expect(items.first.formattedDate, equals('Сегодня'));

      await TicketService.instance.clearTicket();
    });

    testWidgets('Suburban trip with endStation displays both start and end stops with connecting line',
        (WidgetTester tester) async {
      await TripHistoryService.instance.addTrip(
        TripHistoryItem(
          id: 'test_suburban_trip',
          routeNumber: '108',
          routeTitle: 'Тверь - Конаково',
          startStation: 'Автовокзал (Тверь)',
          endStation: 'Конаково',
          fare: 120,
          purchaseTime: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TripHistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Автовокзал (Тверь)'), findsOneWidget);
      expect(find.text('Конаково'), findsOneWidget);
      expect(find.text('120 ₽'), findsOneWidget);
    });
  });
}
