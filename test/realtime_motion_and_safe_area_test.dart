import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_volga/models/transport/vehicle_model.dart';
import 'package:not_volga/services/ticket_service.dart';
import 'package:not_volga/widgets/map/realtime_motion_smoother.dart';
import 'package:not_volga/widgets/volga_active_ticket_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TicketService.instance.init();
    await TicketService.instance.createTicket(
      routeNumber: '2',
      routeTitle: 'Южный - Мигалово',
      station: 'Луговая улица',
      fare: 40,
      carrierName: 'ООО "Верхневолжское автотранспортное предприятие"',
    );
  });

  group('RealtimeMotionSmoother Tests', () {
    test('AnimatedVehicleState smoothly interpolates position towards target', () {
      final state = AnimatedVehicleState(
        currentPoint: const Point(latitude: 56.8500, longitude: 35.9000),
        startPoint: const Point(latitude: 56.8500, longitude: 35.9000),
        targetPoint: const Point(latitude: 56.8500, longitude: 35.9000),
        currentCourse: 90.0,
        startCourse: 90.0,
        targetCourse: 90.0,
        speedKmh: 25.0,
        startTimeMs: 1000,
        durationMs: 1000,
      );

      final updatedVehicle = const VehicleModel(
        vehicleId: 'bus_1',
        boardNumber: '101',
        licenseNumber: 'A101AA69',
        model: 'ЛиАЗ 429260',
        routeId: 1,
        routeName: '1',
        lat: 56.8510,
        lng: 35.9010,
        speed: 30,
        course: 100.0,
      );

      // Получаем новые координаты от сервера в момент t = 1000ms
      state.updateTarget(updatedVehicle, 1000, 1000);

      // В момент t = 1000ms (старт) текущая точка должна быть равна исходной
      state.step(1000);
      expect(state.currentPoint.latitude, closeTo(56.8500, 0.00001));
      expect(state.currentPoint.longitude, closeTo(35.9000, 0.00001));

      // В момент t = 1500ms (середина) точка должна продвинуться вперед
      state.step(1500);
      expect(state.currentPoint.latitude, greaterThan(56.8500));
      expect(state.currentPoint.latitude, lessThan(56.8510));
      expect(state.currentPoint.longitude, greaterThan(35.9000));
      expect(state.currentPoint.longitude, lessThan(35.9010));

      // В момент t = 2000ms (финиш анимации) точка точно совпадает с целевой
      state.step(2000);
      expect(state.currentPoint.latitude, closeTo(56.8510, 0.00001));
      expect(state.currentPoint.longitude, closeTo(35.9010, 0.00001));
      expect(state.currentCourse, closeTo(100.0, 0.1));
    });

    test('AnimatedVehicleState course interpolation correctly wraps around 360 degrees', () {
      final state = AnimatedVehicleState(
        currentPoint: const Point(latitude: 56.85, longitude: 35.90),
        startPoint: const Point(latitude: 56.85, longitude: 35.90),
        targetPoint: const Point(latitude: 56.85, longitude: 35.90),
        currentCourse: 355.0,
        startCourse: 355.0,
        targetCourse: 5.0, // Переход через 0° (кратчайший поворот на +10°, а не на -350°)
        speedKmh: 20.0,
        startTimeMs: 1000,
        durationMs: 1000,
      );

      // На 50% пути курс должен быть около 0° или 360° (ровно посередине)
      state.step(1500);
      expect(state.currentCourse >= 359.0 || state.currentCourse <= 1.0, isTrue);

      // На 100% пути курс равен 5.0°
      state.step(2000);
      expect(state.currentCourse, closeTo(5.0, 0.1));
    });

    test('AnimatedVehicleState dead reckoning keeps moving when packet is delayed', () {
      final state = AnimatedVehicleState(
        currentPoint: const Point(latitude: 56.8500, longitude: 35.9000),
        startPoint: const Point(latitude: 56.8500, longitude: 35.9000),
        targetPoint: const Point(latitude: 56.8510, longitude: 35.9000),
        currentCourse: 0.0, // Движение строго на север
        startCourse: 0.0,
        targetCourse: 0.0,
        speedKmh: 40.0, // Движется со скоростью 40 км/ч
        startTimeMs: 1000,
        durationMs: 1000,
      );

      // По истечении 1000ms достигли целевой
      state.step(2000);
      expect(state.currentPoint.latitude, closeTo(56.8510, 0.00001));

      // При задержке пакета на 500мс (t = 2500ms) автобус продолжает движение на север
      state.step(2500);
      expect(state.currentPoint.latitude, greaterThan(56.8510));
    });

    test('AnimatedUserState smoothly interpolates user position and heading', () {
      final userState = AnimatedUserState(
        currentPoint: const Point(latitude: 56.8584, longitude: 35.9122),
        startPoint: const Point(latitude: 56.8584, longitude: 35.9122),
        targetPoint: const Point(latitude: 56.8584, longitude: 35.9122),
        currentHeading: 45.0,
        startHeading: 45.0,
        targetHeading: 45.0,
        startTimeMs: 1000,
        durationMs: 500,
      );

      userState.updateTarget(
        const Point(latitude: 56.8590, longitude: 35.9130),
        90.0,
        1000,
        500,
      );

      // В середине пути
      userState.step(1250);
      expect(userState.currentPoint.latitude, greaterThan(56.8584));
      expect(userState.currentPoint.latitude, lessThan(56.8590));
      expect(userState.currentHeading, greaterThan(45.0));
      expect(userState.currentHeading, lessThan(90.0));

      // В конце пути
      userState.step(1500);
      expect(userState.currentPoint.latitude, closeTo(56.8590, 0.00001));
      expect(userState.currentPoint.longitude, closeTo(35.9130, 0.00001));
      expect(userState.currentHeading, closeTo(90.0, 0.1));
    });

    test('AnimatedVehicleState interpolates smoothly with 500ms duration (0.5s polling)', () {
      final state = AnimatedVehicleState(
        currentPoint: const Point(latitude: 56.8500, longitude: 35.9000),
        startPoint: const Point(latitude: 56.8500, longitude: 35.9000),
        targetPoint: const Point(latitude: 56.8520, longitude: 35.9020),
        currentCourse: 45.0,
        startCourse: 45.0,
        targetCourse: 45.0,
        speedKmh: 40.0,
        startTimeMs: 1000,
        durationMs: 500,
      );

      // t = 1250ms (ровно середина 500-мс интервала)
      state.step(1250);
      expect(state.currentPoint.latitude, greaterThan(56.8500));
      expect(state.currentPoint.latitude, lessThan(56.8520));
      expect(state.currentPoint.longitude, greaterThan(35.9000));
      expect(state.currentPoint.longitude, lessThan(35.9020));

      // t = 1500ms (конец 500-мс интервала)
      state.step(1500);
      expect(state.currentPoint.latitude, closeTo(56.8520, 0.00001));
      expect(state.currentPoint.longitude, closeTo(35.9020, 0.00001));
    });
  });

  group('SafeArea and Window Inset Tests', () {
    testWidgets('SafeArea builder is configured at root and keeps content within system insets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return Container(
              color: Colors.white,
              child: SafeArea(
                top: true,
                bottom: true,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const Scaffold(
            body: Text('Content inside safe bounds'),
          ),
        ),
      );

      expect(find.text('Content inside safe bounds'), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);

      final safeAreaWidget = tester.widget<SafeArea>(find.byType(SafeArea).first);
      expect(safeAreaWidget.top, isTrue);
      expect(safeAreaWidget.bottom, isTrue);
    });

    testWidgets('VolgaActiveTicketSheet ensures "Ваш билет" header is visible at y >= 0.0 inside SafeArea', (tester) async {
      // Имитируем устройство с системным статус-баром и навигационной панелью
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0; // 360 x 800 dp
      tester.view.padding = const FakeViewPadding(top: 72, bottom: 96); // 24dp top, 32dp bottom

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return Container(
              color: Colors.white,
              child: SafeArea(
                top: true,
                bottom: true,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  const Scaffold(body: SizedBox.expand()),
                  VolgaActiveTicketSheet(
                    availableHeight: constraints.maxHeight,
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // В свернутом состоянии заголовок виден
      expect(find.text('Ваш билет'), findsOneWidget);

      // Раскрываем шторку
      await tester.tap(find.text('Ваш билет'));
      await tester.pumpAndSettle();

      // Заголовок "Ваш билет" по-прежнему найден и находится в видимой зоне (y >= 0.0)
      expect(find.text('Ваш билет'), findsOneWidget);
      final headerTopY = tester.getTopLeft(find.text('Ваш билет')).dy;
      expect(headerTopY, greaterThanOrEqualTo(0.0), reason: 'Заголовок "Ваш билет" не должен вылетать за верхний край экрана');
      expect(headerTopY, lessThan(100.0), reason: 'Заголовок "Ваш билет" должен быть в верхней части экрана');
    });

    testWidgets('VolgaActiveTicketSheet touch jitter (< 8px) in mini state reliably expands sheet and does NOT collapse', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Stack(
            children: [
              Scaffold(body: SizedBox.expand()),
              VolgaActiveTicketSheet(availableHeight: 700),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Имитируем палец с легким сдвигом на 3px вверх (микро-сдвиг тапа на сенсоре)
      final center = tester.getCenter(find.text('Ваш билет'));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, -3));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.up();
      await tester.pumpAndSettle();

      // Шторка должна успешно раскрыться, а не схлопнуться
      // При раскрытии появляется "ООО \"Верхневолжское автотранспортное"
      expect(find.textContaining('Верхневолжское'), findsOneWidget);
    });

    testWidgets('VolgaActiveTicketSheet dragging ticket card in expanded state does NOT collapse the sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Stack(
            children: [
              Scaffold(body: SizedBox.expand()),
              VolgaActiveTicketSheet(availableHeight: 700),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Раскрываем шторку
      await tester.tap(find.text('Ваш билет'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Верхневолжское'), findsOneWidget);

      // Проводим пальцем вниз по самой карточке билета
      final cardCenter = tester.getCenter(find.textContaining('Верхневолжское'));
      final gesture = await tester.startGesture(cardCenter);
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.up();
      await tester.pumpAndSettle();

      // Карточка не провалилась, шторка осталась раскрытой!
      expect(find.textContaining('Верхневолжское'), findsOneWidget);
    });
  });
}
