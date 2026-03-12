import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:quest_guide/domain/models/navigation_route.dart';

class NavigationMonitorConfig {
  final Duration rerouteCooldown;
  final double minRerouteShiftMeters;
  final double offRouteThresholdMeters;
  final double stepArrivalThresholdMeters;
  final int voiceSoonDistanceMeters;
  final int voiceNowDistanceMeters;

  const NavigationMonitorConfig({
    this.rerouteCooldown = const Duration(seconds: 12),
    this.minRerouteShiftMeters = 28,
    this.offRouteThresholdMeters = 45,
    this.stepArrivalThresholdMeters = 24,
    this.voiceSoonDistanceMeters = 120,
    this.voiceNowDistanceMeters = 40,
  });
}

class RerouteDecision {
  final bool shouldReroute;
  final bool isOffRoute;
  final double? offRouteDistanceMeters;
  final String reason;

  const RerouteDecision({
    required this.shouldReroute,
    required this.isOffRoute,
    required this.offRouteDistanceMeters,
    required this.reason,
  });

  factory RerouteDecision.skip({
    required bool isOffRoute,
    required double? offRouteDistanceMeters,
    required String reason,
  }) {
    return RerouteDecision(
      shouldReroute: false,
      isOffRoute: isOffRoute,
      offRouteDistanceMeters: offRouteDistanceMeters,
      reason: reason,
    );
  }

  factory RerouteDecision.trigger({
    required bool isOffRoute,
    required double? offRouteDistanceMeters,
    required String reason,
  }) {
    return RerouteDecision(
      shouldReroute: true,
      isOffRoute: isOffRoute,
      offRouteDistanceMeters: offRouteDistanceMeters,
      reason: reason,
    );
  }
}

class NavigationMonitorService {
  final NavigationMonitorConfig config;

  const NavigationMonitorService(
      {this.config = const NavigationMonitorConfig()});

  RerouteDecision evaluate({
    required NavigationPoint currentPosition,
    required NavigationPoint destination,
    required NavigationRoute? activeRoute,
    required NavigationPoint? lastRouteOrigin,
    required DateTime? lastRouteRequestedAt,
    required DateTime now,
    bool force = false,
  }) {
    final route = activeRoute;

    if (force || route == null || route.polylinePoints.isEmpty) {
      return RerouteDecision.trigger(
        isOffRoute: false,
        offRouteDistanceMeters: null,
        reason: 'initial',
      );
    }

    final distanceToRoute = distanceToPolylineMeters(
      currentPosition: currentPosition,
      polyline: route.polylinePoints,
    );
    final isOffRoute = distanceToRoute > config.offRouteThresholdMeters;

    if (isOffRoute) {
      if (!_cooldownExpired(lastRouteRequestedAt, now)) {
        return RerouteDecision.skip(
          isOffRoute: true,
          offRouteDistanceMeters: distanceToRoute,
          reason: 'off-route-cooldown',
        );
      }

      return RerouteDecision.trigger(
        isOffRoute: true,
        offRouteDistanceMeters: distanceToRoute,
        reason: 'off-route',
      );
    }

    if (!_cooldownExpired(lastRouteRequestedAt, now)) {
      return RerouteDecision.skip(
        isOffRoute: false,
        offRouteDistanceMeters: distanceToRoute,
        reason: 'cooldown',
      );
    }

    if (lastRouteOrigin == null) {
      return RerouteDecision.trigger(
        isOffRoute: false,
        offRouteDistanceMeters: distanceToRoute,
        reason: 'no-origin',
      );
    }

    final movedSinceLastRequest = Geolocator.distanceBetween(
      lastRouteOrigin.latitude,
      lastRouteOrigin.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    if (movedSinceLastRequest >= config.minRerouteShiftMeters) {
      return RerouteDecision.trigger(
        isOffRoute: false,
        offRouteDistanceMeters: distanceToRoute,
        reason: 'shifted',
      );
    }

    final distanceToDestination = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (distanceToDestination <= config.offRouteThresholdMeters) {
      return RerouteDecision.skip(
        isOffRoute: false,
        offRouteDistanceMeters: distanceToRoute,
        reason: 'near-destination',
      );
    }

    return RerouteDecision.skip(
      isOffRoute: false,
      offRouteDistanceMeters: distanceToRoute,
      reason: 'stable',
    );
  }

  bool _cooldownExpired(DateTime? lastRouteRequestedAt, DateTime now) {
    if (lastRouteRequestedAt == null) return true;
    return now.difference(lastRouteRequestedAt) >= config.rerouteCooldown;
  }

  double distanceToPolylineMeters({
    required NavigationPoint currentPosition,
    required List<NavigationPoint> polyline,
  }) {
    if (polyline.isEmpty) {
      return double.infinity;
    }

    if (polyline.length == 1) {
      return Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        polyline.first.latitude,
        polyline.first.longitude,
      );
    }

    double minDistance = double.infinity;
    for (var i = 0; i < polyline.length - 1; i++) {
      final candidate = _distancePointToSegmentMeters(
        point: currentPosition,
        segmentStart: polyline[i],
        segmentEnd: polyline[i + 1],
      );
      if (candidate < minDistance) {
        minDistance = candidate;
      }
    }

    return minDistance;
  }

  double _distancePointToSegmentMeters({
    required NavigationPoint point,
    required NavigationPoint segmentStart,
    required NavigationPoint segmentEnd,
  }) {
    final refLatRadians = point.latitude * math.pi / 180.0;
    const earthRadius = 6371000.0;

    final startX = _toLocalX(
        segmentStart.longitude, point.longitude, refLatRadians, earthRadius);
    final startY =
        _toLocalY(segmentStart.latitude, point.latitude, earthRadius);

    final endX = _toLocalX(
        segmentEnd.longitude, point.longitude, refLatRadians, earthRadius);
    final endY = _toLocalY(segmentEnd.latitude, point.latitude, earthRadius);

    final dx = endX - startX;
    final dy = endY - startY;

    if (dx == 0 && dy == 0) {
      return math.sqrt(startX * startX + startY * startY);
    }

    final t =
        (-(startX * dx + startY * dy) / (dx * dx + dy * dy)).clamp(0.0, 1.0);
    final projX = startX + dx * t;
    final projY = startY + dy * t;

    return math.sqrt(projX * projX + projY * projY);
  }

  double _toLocalX(
    double lon,
    double originLon,
    double refLatRadians,
    double earthRadius,
  ) {
    final deltaLonRadians = (lon - originLon) * math.pi / 180.0;
    return deltaLonRadians * earthRadius * math.cos(refLatRadians);
  }

  double _toLocalY(double lat, double originLat, double earthRadius) {
    final deltaLatRadians = (lat - originLat) * math.pi / 180.0;
    return deltaLatRadians * earthRadius;
  }
}
