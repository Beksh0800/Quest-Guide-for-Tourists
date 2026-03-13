import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quest_guide/domain/models/navigation_route.dart';

class RoutingErrorCode {
  static const String missingApiKey = 'missing-api-key';
  static const String httpError = 'http-error';
  static const String decodeError = 'decode-error';
  static const String noRoutes = 'no-routes';
  static const String apiError = 'api-error';
}

class RoutingServiceException implements Exception {
  final String code;
  final String message;

  const RoutingServiceException({required this.code, required this.message});

  @override
  String toString() => 'RoutingServiceException(code=$code, message=$message)';
}

/// Контракт сервиса маршрутизации по дорогам.
abstract class RoadRoutingService {
  Future<NavigationRoute> fetchWalkingRoute({
    required NavigationPoint origin,
    required NavigationPoint destination,
  });
}

/// Runtime-конфиг для Google Directions API.
///
/// Значения читаются из --dart-define:
/// - GOOGLE_DIRECTIONS_API_KEY (приоритет)
/// - GOOGLE_API_KEY (fallback)
class GoogleDirectionsRoutingConfig {
  static const String directionsApiKeyDefineKey = 'GOOGLE_DIRECTIONS_API_KEY';
  static const String googleApiKeyDefineKey = 'GOOGLE_API_KEY';

  final String directionsApiKey;
  final String fallbackGoogleApiKey;
  final String languageCode;
  final String travelMode;

  const GoogleDirectionsRoutingConfig({
    required this.directionsApiKey,
    required this.fallbackGoogleApiKey,
    this.languageCode = 'ru',
    this.travelMode = 'walking',
  });

  factory GoogleDirectionsRoutingConfig.fromEnvironment() {
    return const GoogleDirectionsRoutingConfig(
      directionsApiKey: String.fromEnvironment(directionsApiKeyDefineKey),
      fallbackGoogleApiKey: String.fromEnvironment(googleApiKeyDefineKey),
    );
  }

  String get resolvedApiKey {
    final primary = directionsApiKey.trim();
    if (primary.isNotEmpty) return primary;
    return fallbackGoogleApiKey.trim();
  }

  bool get hasApiKey => resolvedApiKey.isNotEmpty;
}

class GoogleDirectionsRoutingService implements RoadRoutingService {
  final GoogleDirectionsRoutingConfig _config;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Uri _endpoint;

  GoogleDirectionsRoutingService({
    GoogleDirectionsRoutingConfig? config,
    http.Client? httpClient,
    Uri? endpoint,
  })  : _config = config ?? GoogleDirectionsRoutingConfig.fromEnvironment(),
        _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _endpoint = endpoint ??
            Uri.parse('https://maps.googleapis.com/maps/api/directions/json');

  @override
  Future<NavigationRoute> fetchWalkingRoute({
    required NavigationPoint origin,
    required NavigationPoint destination,
    String travelMode = 'walking',
  }) async {
    if (!_config.hasApiKey) {
      throw const RoutingServiceException(
        code: RoutingErrorCode.missingApiKey,
        message:
            'Google Directions API key is missing. Provide GOOGLE_DIRECTIONS_API_KEY or GOOGLE_API_KEY via --dart-define.',
      );
    }

    final uri = _endpoint.replace(
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': travelMode,
        'language': _config.languageCode,
        'key': _config.resolvedApiKey,
      },
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw RoutingServiceException(
        code: RoutingErrorCode.httpError,
        message: 'Directions API HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const RoutingServiceException(
        code: RoutingErrorCode.decodeError,
        message: 'Failed to parse Directions API response.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const RoutingServiceException(
        code: RoutingErrorCode.decodeError,
        message: 'Directions API returned unexpected payload format.',
      );
    }

    final status = (decoded['status'] as String? ?? '').trim();
    if (status != 'OK') {
      if (status == 'ZERO_RESULTS') {
        throw const RoutingServiceException(
          code: RoutingErrorCode.noRoutes,
          message: 'No walking route found for selected destination.',
        );
      }

      final details = (decoded['error_message'] as String? ?? '').trim();
      throw RoutingServiceException(
        code: RoutingErrorCode.apiError,
        message: details.isNotEmpty
            ? 'Directions API error: $status ($details)'
            : 'Directions API error: $status',
      );
    }

    return _parseRoute(decoded);
  }

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  NavigationRoute _parseRoute(Map<String, dynamic> payload) {
    final rawRoutes = payload['routes'];
    if (rawRoutes is! List || rawRoutes.isEmpty) {
      throw const RoutingServiceException(
        code: RoutingErrorCode.noRoutes,
        message: 'Directions API returned no routes.',
      );
    }

    final firstRoute = rawRoutes.first;
    if (firstRoute is! Map) {
      throw const RoutingServiceException(
        code: RoutingErrorCode.decodeError,
        message: 'Directions API route payload has invalid format.',
      );
    }

    final routeMap = Map<String, dynamic>.from(firstRoute);
    final rawLegs = routeMap['legs'];
    if (rawLegs is! List || rawLegs.isEmpty) {
      throw const RoutingServiceException(
        code: RoutingErrorCode.noRoutes,
        message: 'Directions API route contains no legs.',
      );
    }

    int totalDistance = 0;
    int totalDuration = 0;
    final steps = <NavigationStep>[];

    for (final rawLeg in rawLegs) {
      if (rawLeg is! Map) continue;
      final leg = Map<String, dynamic>.from(rawLeg);

      totalDistance += _readNestedInt(leg, const ['distance', 'value']);
      totalDuration += _readNestedInt(leg, const ['duration', 'value']);

      final rawSteps = leg['steps'];
      if (rawSteps is! List) continue;

      for (final rawStep in rawSteps) {
        if (rawStep is! Map) continue;
        final step = Map<String, dynamic>.from(rawStep);
        steps.add(_parseStep(step));
      }
    }

    final overviewPolyline = _readNestedString(
      routeMap,
      const ['overview_polyline', 'points'],
    );

    var routePolyline = _decodePolyline(overviewPolyline);
    if (routePolyline.isEmpty) {
      routePolyline = _flattenStepPolyline(steps);
    }

    if (routePolyline.isEmpty) {
      throw const RoutingServiceException(
        code: RoutingErrorCode.decodeError,
        message: 'Directions API returned empty route polyline.',
      );
    }

    return NavigationRoute(
      polylinePoints: routePolyline,
      distanceMeters: totalDistance,
      durationSeconds: totalDuration,
      steps: steps,
    );
  }

  NavigationStep _parseStep(Map<String, dynamic> step) {
    final instruction = _sanitizeInstruction(
      (step['html_instructions'] as String?) ?? '',
    );
    final maneuver = ((step['maneuver'] as String?) ?? '').trim();
    final distanceMeters = _readNestedInt(step, const ['distance', 'value']);
    final durationSeconds = _readNestedInt(step, const ['duration', 'value']);

    final startPoint = _parsePoint(step['start_location']);
    final endPoint = _parsePoint(step['end_location']);

    final polyline = _decodePolyline(
      _readNestedString(step, const ['polyline', 'points']),
    );

    final safePolyline = polyline.isNotEmpty
        ? polyline
        : <NavigationPoint>[startPoint, endPoint];

    return NavigationStep(
      instruction: instruction.isNotEmpty ? instruction : 'Двигайся прямо',
      maneuver: maneuver,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      startPoint: startPoint,
      endPoint: endPoint,
      polylinePoints: safePolyline,
    );
  }

  NavigationPoint _parsePoint(dynamic raw) {
    if (raw is! Map) {
      throw const RoutingServiceException(
        code: RoutingErrorCode.decodeError,
        message: 'Directions API step point has invalid format.',
      );
    }

    final map = Map<String, dynamic>.from(raw);
    final lat = _asDouble(map['lat']);
    final lng = _asDouble(map['lng']);

    if (lat == null || lng == null) {
      throw const RoutingServiceException(
        code: RoutingErrorCode.decodeError,
        message: 'Directions API step point misses lat/lng.',
      );
    }

    return NavigationPoint(latitude: lat, longitude: lng);
  }

  int _readNestedInt(Map<String, dynamic> map, List<String> path) {
    dynamic current = map;
    for (final key in path) {
      if (current is! Map || !current.containsKey(key)) {
        return 0;
      }
      current = current[key];
    }

    if (current is int) return current;
    if (current is num) return current.round();
    if (current is String) return int.tryParse(current) ?? 0;
    return 0;
  }

  String _readNestedString(Map<String, dynamic> map, List<String> path) {
    dynamic current = map;
    for (final key in path) {
      if (current is! Map || !current.containsKey(key)) {
        return '';
      }
      current = current[key];
    }

    if (current is String) return current;
    return '';
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _sanitizeInstruction(String value) {
    if (value.trim().isEmpty) return '';

    final withoutTags = value.replaceAll(RegExp(r'<[^>]*>'), ' ');
    final normalized = withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&', '&')
        .replaceAll('"', '"')
        .replaceAll('<', '<')
        .replaceAll('>', '>');
  }

  List<NavigationPoint> _flattenStepPolyline(List<NavigationStep> steps) {
    final points = <NavigationPoint>[];

    for (final step in steps) {
      final stepPoints = step.polylinePoints;
      if (stepPoints.isEmpty) continue;

      if (points.isEmpty) {
        points.addAll(stepPoints);
        continue;
      }

      if (_pointsEqual(points.last, stepPoints.first)) {
        points.addAll(stepPoints.skip(1));
      } else {
        points.addAll(stepPoints);
      }
    }

    return points;
  }

  bool _pointsEqual(NavigationPoint left, NavigationPoint right) {
    return left.latitude == right.latitude && left.longitude == right.longitude;
  }

  List<NavigationPoint> _decodePolyline(String encoded) {
    if (encoded.trim().isEmpty) {
      return const <NavigationPoint>[];
    }

    final points = <NavigationPoint>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      final latResult = _decodeNextValue(encoded, index);
      if (latResult == null) break;
      index = latResult.nextIndex;
      lat += latResult.delta;

      final lngResult = _decodeNextValue(encoded, index);
      if (lngResult == null) break;
      index = lngResult.nextIndex;
      lng += lngResult.delta;

      points.add(
        NavigationPoint(
          latitude: lat / 1e5,
          longitude: lng / 1e5,
        ),
      );
    }

    return points;
  }

  _PolylineChunk? _decodeNextValue(String encoded, int startIndex) {
    if (startIndex >= encoded.length) {
      return null;
    }

    var index = startIndex;
    var result = 0;
    var shift = 0;

    while (index < encoded.length) {
      final byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;

      if (byte < 0x20) {
        final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
        return _PolylineChunk(delta: delta, nextIndex: index);
      }
    }

    return null;
  }
}

class _PolylineChunk {
  final int delta;
  final int nextIndex;

  const _PolylineChunk({
    required this.delta,
    required this.nextIndex,
  });
}
