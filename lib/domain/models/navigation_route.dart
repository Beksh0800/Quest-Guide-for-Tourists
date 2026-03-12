import 'package:equatable/equatable.dart';

/// Геокоордината для in-app навигации.
class NavigationPoint extends Equatable {
  final double latitude;
  final double longitude;

  const NavigationPoint({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object> get props => [latitude, longitude];
}

/// Один шаг turn-by-turn навигации.
class NavigationStep extends Equatable {
  final String instruction;
  final String maneuver;
  final int distanceMeters;
  final int durationSeconds;
  final NavigationPoint startPoint;
  final NavigationPoint endPoint;
  final List<NavigationPoint> polylinePoints;

  const NavigationStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startPoint,
    required this.endPoint,
    required this.polylinePoints,
  });

  @override
  List<Object> get props => [
        instruction,
        maneuver,
        distanceMeters,
        durationSeconds,
        startPoint,
        endPoint,
        polylinePoints,
      ];
}

/// Маршрут по дорогам между текущей позицией пользователя и целевой точкой квеста.
class NavigationRoute extends Equatable {
  final List<NavigationPoint> polylinePoints;
  final int distanceMeters;
  final int durationSeconds;
  final List<NavigationStep> steps;

  const NavigationRoute({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  @override
  List<Object> get props => [
        polylinePoints,
        distanceMeters,
        durationSeconds,
        steps,
      ];
}
