import 'package:flutter_test/flutter_test.dart';
import 'package:quest_guide/data/services/navigation_monitor_service.dart';
import 'package:quest_guide/domain/models/navigation_route.dart';

void main() {
  const config = NavigationMonitorConfig(
    maxAcceptedAccuracyMeters: 40,
    targetStabilityMinDuration: Duration(seconds: 4),
    targetStabilityMinSamples: 2,
    gpsSignalLostAfter: Duration(seconds: 6),
  );

  NavigationPoint point(double lat, double lng) =>
      NavigationPoint(latitude: lat, longitude: lng);

  group('NavigationMonitorService GPS quality', () {
    const service = NavigationMonitorService(config: config);

    test('accepts good accuracy', () {
      expect(service.isAccuracyAcceptable(15), isTrue);
      expect(service.isAccuracyAcceptable(45), isFalse);
    });

    test('marks lost when no accepted fix for threshold', () {
      final now = DateTime(2026, 1, 1, 10, 0, 10);
      final quality = service.resolveGpsQuality(
        latestAccuracyMeters: 10,
        lastAcceptedFixAt: DateTime(2026, 1, 1, 10, 0, 0),
        now: now,
      );
      expect(quality, GpsQuality.lost);
    });
  });

  group('TargetArrivalTracker', () {
    test('moves outside -> candidate -> stable and back', () {
      final tracker = TargetArrivalTracker(config: config);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      final e1 = tracker.evaluate(
        distanceMeters: 20,
        radiusMeters: 25,
        now: t0,
      );
      expect(e1.state, ArrivalState.candidate);
      expect(e1.isReadyToStart, isFalse);

      final e2 = tracker.evaluate(
        distanceMeters: 18,
        radiusMeters: 25,
        now: t0.add(const Duration(seconds: 5)),
      );
      expect(e2.state, ArrivalState.stableArrived);
      expect(e2.isReadyToStart, isTrue);
      expect(e2.becameStable, isTrue);

      final e3 = tracker.evaluate(
        distanceMeters: 80,
        radiusMeters: 25,
        now: t0.add(const Duration(seconds: 7)),
      );
      expect(e3.state, ArrivalState.outside);
      expect(e3.isReadyToStart, isFalse);
    });
  });

  group('NavigationMonitorService reroute', () {
    const service = NavigationMonitorService();
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    test('initial forces reroute', () {
      final decision = service.evaluate(
        currentPosition: point(43.0, 76.0),
        destination: point(43.01, 76.01),
        activeRoute: null,
        lastRouteOrigin: null,
        lastRouteRequestedAt: null,
        now: now,
        force: true,
      );

      expect(decision.shouldReroute, isTrue);
      expect(decision.reason, 'initial');
    });

    test('off-route triggers reroute', () {
      final route = NavigationRoute(
        polylinePoints: [point(43.0, 76.0), point(43.0001, 76.0001)],
        steps: const [],
        distanceMeters: 100,
        durationSeconds: 100,
      );

      final decision = service.evaluate(
        currentPosition: point(43.02, 76.02),
        destination: point(43.0001, 76.0001),
        activeRoute: route,
        lastRouteOrigin: point(43.0, 76.0),
        lastRouteRequestedAt: now.subtract(const Duration(minutes: 1)),
        now: now,
      );

      expect(decision.shouldReroute, isTrue);
      expect(decision.isOffRoute, isTrue);
      expect(decision.reason, 'off-route');
    });
  });
}
