import 'package:equatable/equatable.dart';
import 'package:quest_guide/data/services/navigation_monitor_service.dart';

enum RouteStatus { onRoute, offRoute, unavailable }

class NavigationRuntimeState extends Equatable {
  final GpsQuality gpsQuality;
  final RouteStatus routeStatus;
  final ArrivalState arrivalState;
  final double? offRouteDistanceMeters;
  final DateTime? lastStableFixAt;

  const NavigationRuntimeState({
    required this.gpsQuality,
    required this.routeStatus,
    required this.arrivalState,
    this.offRouteDistanceMeters,
    this.lastStableFixAt,
  });

  @override
  List<Object?> get props => [
        gpsQuality,
        routeStatus,
        arrivalState,
        offRouteDistanceMeters,
        lastStableFixAt,
      ];
}
