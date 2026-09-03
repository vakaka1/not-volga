import 'package:flutter_test/flutter_test.dart';
import 'package:not_volga/models/transport/route_details_model.dart';
import 'package:not_volga/models/transport/route_model.dart';
import 'package:not_volga/models/transport/route_path_point.dart';
import 'package:not_volga/models/transport/station_arrival_model.dart';
import 'package:not_volga/models/transport/station_model.dart';
import 'package:not_volga/models/transport/vehicle_model.dart';

void main() {
  group('Transport Models Test', () {
    test('StationModel deserializes correctly', () {
      final json = {
        'station_id': 11920,
        'name': 'Волоколамский путепровод',
        'address': 'Тверь, Волоколамский проспект, 45',
        'lat': 56.833641,
        'lng': 35.905041,
        'location_id': 1,
      };

      final station = StationModel.fromJson(json);
      expect(station.stationId, 11920);
      expect(station.name, 'Волоколамский путепровод');
      expect(station.address, 'Тверь, Волоколамский проспект, 45');
      expect(station.lat, 56.833641);
      expect(station.lng, 35.905041);
      expect(station.locationId, 1);
    });

    test('RouteModel parses start and end station', () {
      final json = {
        'route_id': 12423,
        'location_id': 1,
        'name': '33',
        'title': 'Мигалово - Гипермаркет Леруа-Мерлен',
        'start_end_stations': 'Мигалово - Гипермаркет Леруа-Мерлен',
        'end_station': 'Гипермаркет Леруа-Мерлен',
      };

      final route = RouteModel.fromJson(json);
      expect(route.routeId, 12423);
      expect(route.name, '33');
      expect(route.startStation, 'Мигалово');
      expect(route.endStation, 'Гипермаркет Леруа-Мерлен');
    });

    test('RouteDetailsModel parses ordered stations', () {
      final json = {
        'route_id': 12423,
        'name': '33',
        'title': 'Мигалово - Леруа',
        'stations': [
          {'station_id': 1, 'name': 'Мигалово', 'address': '', 'lat': 56.84, 'lng': 35.80},
          {'station_id': 2, 'name': 'Остановка 2', 'address': '', 'lat': 56.84, 'lng': 35.81},
          {'station_id': 3, 'name': 'Леруа Мерлен', 'address': '', 'lat': 56.84, 'lng': 35.82},
        ],
      };

      final details = RouteDetailsModel.fromJson(json);
      expect(details.stations.length, 3);
      expect(details.startStation, 'Мигалово');
      expect(details.finalStation, 'Леруа Мерлен');
    });

    test('VehicleModel formats license plate correctly', () {
      final json = {
        'vehicle_id': 'aef67824-8c92-45f9-8783-0440a1850960',
        'board_number': '10086',
        'license_number': 'H325CP69',
        'model': 'ЛиАЗ 429260',
        'route_id': 12423,
        'route_name': '33',
        'lat': 56.80915,
        'lng': 35.872718,
        'speed': 26,
        'course': 199.0,
      };

      final vehicle = VehicleModel.fromJson(json);
      expect(vehicle.boardNumber, '10086');
      expect(vehicle.formattedLicenseNumber, 'H 325 CP  69');
      expect(vehicle.speed, 26);
      expect(vehicle.course, 199.0);
      expect(vehicle.hasWheelchair, true);
    });

    test('RoutePathPoint parses lat/lng/order', () {
      final json = {
        'route_id': 12423,
        'order': 1,
        'lat': 56.835858,
        'lng': 35.894705,
        'distance': 0.0,
      };

      final point = RoutePathPoint.fromJson(json);
      expect(point.order, 1);
      expect(point.lat, 56.835858);
      expect(point.lng, 35.894705);
    });

    test('StationArrivalModel calculates arrival minutes', () {
      final now = DateTime.now();
      final arrival1 = now.add(const Duration(minutes: 7, seconds: 30));
      final arrival2 = now.add(const Duration(minutes: 15, seconds: 30));

      final json = {
        'route_id': 12423,
        'name': '20',
        'end_station': 'Мигалово',
        'estimated_arrival': [
          arrival1.toIso8601String(),
          arrival2.toIso8601String(),
        ],
      };

      final arrival = StationArrivalModel.fromJson(json, matchedLicense: 'Н 756 СР 69');
      expect(arrival.routeName, '20');
      expect(arrival.licenseNumber, 'Н 756 СР 69');
      expect(arrival.hasWheelchair, true);
      expect(arrival.primaryTimeText, '7 мин');
      expect(arrival.secondaryTimeText, '15 мин');
    });
  });
}
