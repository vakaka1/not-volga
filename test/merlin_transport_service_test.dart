import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:not_volga/services/merlin_transport_service.dart';

void main() {
  group('MerlinTransportService Test', () {
    test('getStations parses remote JSON response', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/stations')) {
          final sampleData = [
            {
              'station_id': 101,
              'name': 'Площадь Ленина',
              'address': 'Тверь, Советская',
              'lat': 56.85,
              'lng': 35.91,
              'location_id': 1,
            },
            {
              'station_id': 102,
              'name': 'Ржев-1',
              'address': 'Ржев',
              'lat': 56.26,
              'lng': 34.33,
              'location_id': 2,
            },
          ];
          return http.Response(jsonEncode(sampleData), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('Not Found', 404);
      });

      final service = MerlinTransportService(client: mockClient);
      final stations = await service.getStations(locationId: 1, forceRefresh: true);

      expect(stations.length, 1);
      expect(stations.first.name, 'Площадь Ленина');
      expect(stations.first.stationId, 101);
    });

    test('getVehicles sends bbox query parameters and parses vehicles', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/vehicles')) {
          expect(request.url.queryParameters['top_lat'], '56.93423');
          final sampleVehicles = [
            {
              'vehicle_id': 'bus-1',
              'board_number': '101',
              'license_number': 'О113СР69',
              'model': 'ЛиАЗ 429260',
              'route_id': 13031,
              'route_name': '21',
              'lat': 56.85,
              'lng': 35.90,
              'speed': 25,
              'course': 90.0,
            }
          ];
          return http.Response(jsonEncode(sampleVehicles), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('Not Found', 404);
      });

      final service = MerlinTransportService(client: mockClient);
      final vehicles = await service.getVehicles(
        topLat: 56.93423,
        bottomLat: 56.785747,
        leftLng: 35.737569,
        rightLng: 36.039364,
      );

      expect(vehicles.length, 1);
      expect(vehicles.first.routeName, '21');
      expect(vehicles.first.licenseNumber, 'О113СР69');
      expect(vehicles.first.formattedLicenseNumber, 'О 113 СР  69');
    });

    test('getStationArrivals parses ETA list', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/stations/101/routes')) {
          final sampleArrivals = [
            {
              'route_id': 13031,
              'name': '20',
              'end_station': 'Мигалово',
              'estimated_arrival': ['2026-09-02T15:40:00+03:00'],
            }
          ];
          return http.Response(jsonEncode(sampleArrivals), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('Not Found', 404);
      });

      final service = MerlinTransportService(client: mockClient);
      final arrivals = await service.getStationArrivals(101, vehicleLicenseByRoute: {'20': 'H 756 CP 69'});

      expect(arrivals.length, 1);
      expect(arrivals.first.routeName, '20');
      expect(arrivals.first.licenseNumber, 'H 756 CP 69');
      expect(arrivals.first.hasWheelchair, true);
    });
  });
}
