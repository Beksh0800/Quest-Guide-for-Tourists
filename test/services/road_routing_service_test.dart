import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quest_guide/data/services/road_routing_service.dart';
import 'package:quest_guide/domain/models/navigation_route.dart';

void main() {
  group('GoogleDirectionsRoutingService routing', () {
    test('parses route and steps from successful Directions response',
        () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.queryParameters['mode'],
          'walking',
          reason: 'Route mode must be walking for in-app pedestrian nav',
        );
        expect(request.url.queryParameters['language'], 'ru');
        expect(request.url.queryParameters['key'], 'test-key');

        return http.Response(
          '''
{
  "status": "OK",
  "routes": [
    {
      "overview_polyline": {
        "points": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
      },
      "legs": [
        {
          "distance": {"value": 1250},
          "duration": {"value": 900},
          "steps": [
            {
              "html_instructions": "<b>Turn right</b> to the park",
              "maneuver": "turn-right",
              "distance": {"value": 300},
              "duration": {"value": 240},
              "start_location": {"lat": 43.2385, "lng": 76.8897},
              "end_location": {"lat": 43.2390, "lng": 76.8920},
              "polyline": {"points": ""}
            }
          ]
        }
      ]
    }
  ]
}
''',
          200,
        );
      });

      final service = GoogleDirectionsRoutingService(
        config: const GoogleDirectionsRoutingConfig(
          directionsApiKey: 'test-key',
          fallbackGoogleApiKey: '',
        ),
        httpClient: mockClient,
      );

      final route = await service.fetchWalkingRoute(
        origin: const NavigationPoint(latitude: 43.2380, longitude: 76.8850),
        destination:
            const NavigationPoint(latitude: 43.2400, longitude: 76.9000),
      );

      expect(route.distanceMeters, 1250);
      expect(route.durationSeconds, 900);
      expect(route.polylinePoints, isNotEmpty);
      expect(route.steps.length, 1);
      expect(route.steps.first.instruction, 'Turn right to the park');
      expect(route.steps.first.distanceMeters, 300);
      expect(route.steps.first.maneuver, 'turn-right');
    });

    test('fetchWalkingRoute sends selected travel mode', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['mode'], 'driving');

        return http.Response(
          '{"status":"OK","routes":[{"overview_polyline":{"points":"_p~iF~ps|U_ulLnnqC_mqNvxq`@"},"legs":[{"distance":{"value":500},"duration":{"value":120},"steps":[]}]}]}',
          200,
        );
      });

      final service = GoogleDirectionsRoutingService(
        config: const GoogleDirectionsRoutingConfig(
          directionsApiKey: 'test-key',
          fallbackGoogleApiKey: '',
        ),
        httpClient: mockClient,
      );

      final route = await service.fetchWalkingRoute(
        origin: const NavigationPoint(latitude: 43.2380, longitude: 76.8850),
        destination:
            const NavigationPoint(latitude: 43.2400, longitude: 76.9000),
        travelMode: 'driving',
      );

      expect(route.distanceMeters, 500);
      expect(route.durationSeconds, 120);
    });

    test('throws missingApiKey when config has no credentials', () async {
      final service = GoogleDirectionsRoutingService(
        config: const GoogleDirectionsRoutingConfig(
          directionsApiKey: '',
          fallbackGoogleApiKey: '',
        ),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        () => service.fetchWalkingRoute(
          origin: const NavigationPoint(latitude: 43.0, longitude: 76.0),
          destination: const NavigationPoint(latitude: 43.1, longitude: 76.1),
        ),
        throwsA(
          isA<RoutingServiceException>()
              .having((e) => e.code, 'code', RoutingErrorCode.missingApiKey),
        ),
      );
    });

    test('throws noRoutes when API responds with ZERO_RESULTS', () async {
      final service = GoogleDirectionsRoutingService(
        config: const GoogleDirectionsRoutingConfig(
          directionsApiKey: 'test-key',
          fallbackGoogleApiKey: '',
        ),
        httpClient: MockClient(
          (_) async => http.Response(
            '{"status":"ZERO_RESULTS","routes":[]}',
            200,
          ),
        ),
      );

      expect(
        () => service.fetchWalkingRoute(
          origin: const NavigationPoint(latitude: 43.0, longitude: 76.0),
          destination: const NavigationPoint(latitude: 44.0, longitude: 77.0),
        ),
        throwsA(
          isA<RoutingServiceException>()
              .having((e) => e.code, 'code', RoutingErrorCode.noRoutes),
        ),
      );
    });
  });
}
