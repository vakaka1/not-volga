import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_volga/models/transport/route_details_model.dart';
import 'package:not_volga/models/transport/station_arrival_model.dart';
import 'package:not_volga/models/transport/station_model.dart';
import 'package:not_volga/models/transport/vehicle_model.dart';
import 'package:not_volga/theme/app_colors.dart';
import 'package:not_volga/widgets/map/volga_bus_bottom_sheet.dart';
import 'package:not_volga/widgets/map/volga_map_buttons.dart';
import 'package:not_volga/widgets/map/volga_station_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VolgaMapButtons Widget Tests', () {
    testWidgets('Tapping arrow button invokes onCenterLocationTap', (WidgetTester tester) async {
      bool centerTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolgaMapButtons(
              onFilterTap: () {},
              onStationsModeTap: () {},
              onBusModeTap: () {},
              onZoomInTap: () {},
              onZoomOutTap: () {},
              onCenterLocationTap: () {
                centerTapped = true;
              },
              onBlindModeTap: () {},
              isBusModeActive: true,
              isStationsModeActive: true,
            ),
          ),
        ),
      );

      final arrowFinder = find.byIcon(Icons.navigation);
      expect(arrowFinder, findsOneWidget);

      await tester.tap(arrowFinder);
      await tester.pump();

      expect(centerTapped, isTrue);
    });

    testWidgets('Tapping round button (stops) invokes onStationsModeTap and does not change color',
        (WidgetTester tester) async {
      bool stationsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolgaMapButtons(
              onFilterTap: () {},
              onStationsModeTap: () {
                stationsTapped = true;
              },
              onBusModeTap: () {},
              onZoomInTap: () {},
              onZoomOutTap: () {},
              onCenterLocationTap: () {},
              onBlindModeTap: () {},
              isBusModeActive: true,
              isStationsModeActive: true,
            ),
          ),
        ),
      );

      final stationsFinder = find.byIcon(Icons.gps_fixed);
      expect(stationsFinder, findsOneWidget);

      final Icon iconWidget = tester.widget(stationsFinder);
      expect(iconWidget.color, equals(AppColors.black));

      await tester.tap(stationsFinder);
      await tester.pump();

      expect(stationsTapped, isTrue);
    });

    testWidgets('Bus button toggles and changes color (red when active, black when inactive)',
        (WidgetTester tester) async {
      bool busTapped = false;

      // Active state: red
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolgaMapButtons(
              onFilterTap: () {},
              onStationsModeTap: () {},
              onBusModeTap: () {
                busTapped = true;
              },
              onZoomInTap: () {},
              onZoomOutTap: () {},
              onCenterLocationTap: () {},
              onBlindModeTap: () {},
              isBusModeActive: true,
              isStationsModeActive: true,
            ),
          ),
        ),
      );

      final busImageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.color == const Color(0xFFE52929),
      );
      expect(busImageFinder, findsOneWidget);

      await tester.tap(busImageFinder);
      await tester.pump();
      expect(busTapped, isTrue);

      // Inactive state: black
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolgaMapButtons(
              onFilterTap: () {},
              onStationsModeTap: () {},
              onBusModeTap: () {},
              onZoomInTap: () {},
              onZoomOutTap: () {},
              onCenterLocationTap: () {},
              onBlindModeTap: () {},
              isBusModeActive: false,
              isStationsModeActive: true,
            ),
          ),
        ),
      );

      final inactiveBusFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.color == AppColors.black,
      );
      expect(inactiveBusFinder, findsOneWidget);
    });
  });

  group('VolgaStationBottomSheet 1-hour filtering test', () {
    testWidgets('Only buses arriving within 60 minutes are shown', (WidgetTester tester) async {
      const station = StationModel(
        stationId: 10,
        name: 'Площадь Капошвара',
        address: 'Тверь, улица Дарвина',
        lat: 56.845,
        lng: 35.912,
      );

      final now = DateTime.now();
      final arrivals = [
        StationArrivalModel(
          routeId: 42,
          routeName: '42',
          endStation: 'Конечная 1',
          estimatedArrivals: [now.add(const Duration(minutes: 25))], // <= 60 mins -> SHOWN
        ),
        StationArrivalModel(
          routeId: 227,
          routeName: '227',
          endStation: 'Конечная 2',
          estimatedArrivals: [now.add(const Duration(minutes: 55))], // <= 60 mins -> SHOWN
        ),
        StationArrivalModel(
          routeId: 2,
          routeName: '2',
          endStation: 'Конечная 3',
          estimatedArrivals: [now.add(const Duration(minutes: 75))], // > 60 mins -> HIDDEN
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolgaStationBottomSheet(
              station: station,
              arrivals: arrivals,
            ),
          ),
        ),
      );

      // 42 and 227 should be visible
      expect(find.text('42'), findsOneWidget);
      expect(find.text('227'), findsOneWidget);

      // Route 2 (> 60 mins) should NOT be visible
      expect(find.text('2'), findsNothing);
    });
  });

  group('VolgaBusBottomSheet Timeline and Accordion Tests', () {
    testWidgets('Renders top bar without close button and 5 timeline sections matching original.webp',
        (WidgetTester tester) async {
      const vehicle = VehicleModel(
        vehicleId: '1071',
        boardNumber: '107',
        licenseNumber: 'H 263 CP 69',
        model: 'ЛиАЗ 429260',
        routeId: 107,
        routeName: '107',
        lat: 56.85,
        lng: 35.91,
        nextStationName: 'Поворот на аэропорт',
        hasWheelchair: true,
      );

      final stations = [
        const StationModel(stationId: 1, name: 'Автовокзал', lat: 0, lng: 0),
        const StationModel(stationId: 2, name: 'Железнодорожный вокзал', lat: 0, lng: 0),
        const StationModel(stationId: 3, name: 'Площадь Капошвара', lat: 0, lng: 0),
        const StationModel(stationId: 4, name: 'Поворот на аэропорт', lat: 0, lng: 0),
        const StationModel(stationId: 5, name: 'Улица Дорожников', lat: 0, lng: 0),
        const StationModel(stationId: 6, name: 'Васильевский Мох', lat: 0, lng: 0),
      ];

      final routeDetails = RouteDetailsModel(
        routeId: 107,
        name: '107',
        title: 'Тверь - Васильевский Мох',
        stations: stations,
      );

      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolgaBusBottomSheet(
              vehicle: vehicle,
              routeDetails: routeDetails,
            ),
          ),
        ),
      );

      // Drag sheet up to fully expand it
      await tester.drag(find.byType(DraggableScrollableSheet), const Offset(0, -400), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Top bar items
      expect(find.text('107'), findsOneWidget);
      expect(find.text(vehicle.formattedLicenseNumber), findsOneWidget);
      expect(find.byIcon(Icons.accessible), findsOneWidget);

      // NO close button [X]
      expect(find.byIcon(Icons.close), findsNothing);

      // 5 Timeline sections
      expect(find.text('Автовокзал'), findsOneWidget); // Start station
      expect(find.text('2 остановки'), findsOneWidget); // Passed accordion (Железнодорожный вокзал, Площадь Капошвара)
      expect(find.text('Поворот на аэропорт'), findsOneWidget); // Current station
      expect(find.text('1 остановка'), findsOneWidget); // Remaining accordion (Улица Дорожников)
      expect(find.text('Васильевский Мох'), findsOneWidget); // End station

      // Sub-stations are collapsed initially
      expect(find.text('Железнодорожный вокзал'), findsNothing);
      expect(find.text('Улица Дорожников'), findsNothing);

      // Tap passed stops accordion
      await tester.tap(find.text('2 остановки'));
      await tester.pumpAndSettle();

      // Passed stops are now visible
      expect(find.text('Железнодорожный вокзал'), findsOneWidget);
      expect(find.text('Площадь Капошвара'), findsOneWidget);

      // Scroll ListView up to bring the remaining accordion into view
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Tap remaining stops accordion
      await tester.tap(find.text('1 остановка'));
      await tester.pumpAndSettle();

      // Scroll ListView up to bring the sub-station into view
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      // Remaining stop is now visible
      expect(find.text('Улица Дорожников'), findsOneWidget);
    });
  });
}
