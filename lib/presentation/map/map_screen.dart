import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quest_guide/core/l10n/app_localizations.dart';
import 'package:quest_guide/core/theme/app_theme.dart';
import 'package:quest_guide/data/repositories/progress_repository.dart';
import 'package:quest_guide/data/repositories/quest_repository.dart';
import 'package:quest_guide/data/services/local_notification_service.dart';
import 'package:quest_guide/data/services/navigation_monitor_service.dart';
import 'package:quest_guide/data/services/navigation_voice_service.dart';
import 'package:quest_guide/data/services/road_routing_service.dart';
import 'package:quest_guide/domain/models/navigation_route.dart';
import 'package:quest_guide/domain/models/quest_location.dart';
import 'package:quest_guide/domain/models/quest_progress.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  final String questId;

  const MapScreen({super.key, required this.questId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _questRepo = QuestRepository();
  final _progressRepo = ProgressRepository();
  final GoogleDirectionsRoutingService _routingService =
      GoogleDirectionsRoutingService();
  final NavigationMonitorService _navigationMonitor =
      const NavigationMonitorService();
  final NavigationVoiceService _voiceService = NavigationVoiceService();

  List<QuestLocation> _locations = [];
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  bool _loading = true;
  String? _error;
  int _activeIndex = 0;
  bool _isWithinTargetRadius = false;
  bool _proximityNotified = false;
  bool _devOverride = false;
  GoogleMapController? _mapController;

  NavigationRoute? _activeRoute;
  bool _routeLoading = false;
  String? _routeError;
  DateTime? _lastRouteRequestedAt;
  NavigationPoint? _lastRouteOrigin;
  int _currentStepIndex = 0;
  bool _isOffRoute = false;
  double? _offRouteDistanceMeters;

  bool _voiceEnabled = true;

  @override
  void initState() {
    super.initState();
    unawaited(_voiceService.initialize());
    _voiceService.setEnabled(_voiceEnabled);
    _load();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();

    _routingService.dispose();

    unawaited(_voiceService.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final locations = await _questRepo.getLocations(widget.questId);
      locations.sort((a, b) => a.order.compareTo(b.order));

      if (locations.isEmpty) {
        if (!mounted) return;
        setState(() {
          _locations = [];
          _loading = false;
          _error = AppLocalizations.of(context).noLocations;
        });
        return;
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      QuestProgress? progress;
      if (userId != null) {
        progress =
            await _progressRepo.getActiveProgress(userId, widget.questId);
        progress ??= await _progressRepo.startQuest(
          userId: userId,
          questId: widget.questId,
          initialLocationIndex: 0,
        );
      }

      final activeIndex =
          (progress?.currentLocationIndex ?? 0).clamp(0, locations.length - 1);

      if (!mounted) return;
      setState(() {
        _locations = locations;
        _activeIndex = activeIndex;
        _loading = false;
        _routeError = null;
      });

      await _startLocationTracking();
      await _centerOnActivePoint();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${AppLocalizations.of(context).error}: $e';
      });
    }
  }

  Future<void> _startLocationTracking() async {
    final l10n = AppLocalizations.of(context);
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted) return;
      setState(() => _error = l10n.locationServiceDisabled);
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _error = l10n.locationPermissionDenied);
      return;
    }

    final initial = await Geolocator.getCurrentPosition();
    _onPositionUpdate(initial);

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate);
  }

  Future<void> _centerOnActivePoint() async {
    if (_locations.isEmpty) return;
    final target = _locations[_activeIndex];
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(target.latitude, target.longitude),
          zoom: 15,
        ),
      ),
    );
  }

  void _onPositionUpdate(Position position) {
    if (!mounted || _locations.isEmpty) return;

    final target = _locations[_activeIndex];
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );

    final withinRadius = distance <= target.radiusMeters;
    if (withinRadius && !_proximityNotified) {
      _proximityNotified = true;
      final l10n = AppLocalizations.of(context);
      LocalNotificationService.instance.show(
        id: widget.questId.hashCode + _activeIndex,
        title: l10n.locationReachedTitle,
        body: l10n.locationReachedBody(target.name),
      );
    }

    setState(() {
      _currentPosition = position;
      _isWithinTargetRadius = withinRadius;
    });

    final currentPoint = _positionToPoint(position);
    unawaited(_updateNavigationState(currentPoint));
  }

  Future<void> _updateNavigationState(NavigationPoint currentPoint) async {
    if (_locations.isEmpty) return;

    final target = _locations[_activeIndex];
    final destination = NavigationPoint(
      latitude: target.latitude,
      longitude: target.longitude,
    );

    final decision = _navigationMonitor.evaluate(
      currentPosition: currentPoint,
      destination: destination,
      activeRoute: _activeRoute,
      lastRouteOrigin: _lastRouteOrigin,
      lastRouteRequestedAt: _lastRouteRequestedAt,
      now: DateTime.now(),
      force: _activeRoute == null,
    );

    if (!mounted) return;
    setState(() {
      _isOffRoute = decision.isOffRoute;
      _offRouteDistanceMeters = decision.offRouteDistanceMeters;
    });

    if (decision.isOffRoute) {
      final l10n = AppLocalizations.of(context);
      await _voiceService.speak(
        text: l10n.mapVoiceOffRoutePrompt,
        promptKey: 'off_route_${widget.questId}_$_activeIndex',
        dedupeWindow: const Duration(seconds: 35),
      );
    }

    if (decision.shouldReroute) {
      await _requestRoadRoute(
        origin: currentPoint,
        destination: destination,
        reason: decision.reason,
      );
      return;
    }

    _updateCurrentStepIndex(currentPoint);
    await _maybeAnnounceNextManeuver(currentPoint);
  }

  Future<void> _requestRoadRoute({
    required NavigationPoint origin,
    required NavigationPoint destination,
    required String reason,
  }) async {
    if (_routeLoading || _locations.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    if (mounted) {
      setState(() {
        _routeLoading = true;
        if (reason == 'initial') {
          _routeError = null;
        }
      });
    }

    _lastRouteRequestedAt = DateTime.now();
    _lastRouteOrigin = origin;

    try {
      final route = await _routingService.fetchWalkingRoute(
        origin: origin,
        destination: destination,
      );

      if (!mounted) return;

      final nextStepIndex = _resolveStepIndex(
        currentPoint: origin,
        route: route,
        fromIndex: 0,
      );

      setState(() {
        _activeRoute = route;
        _routeLoading = false;
        _routeError = null;
        _currentStepIndex = nextStepIndex;
        _isOffRoute = false;
      });

      final shouldRefocus = reason == 'initial' || reason == 'off-route';
      if (shouldRefocus) {
        await _fitRouteIntoView(route.polylinePoints);
      }

      if (reason == 'off-route') {
        await _voiceService.speak(
          text: l10n.mapVoiceReroutingPrompt,
          promptKey: 'reroute_${widget.questId}_$_activeIndex',
          dedupeWindow: const Duration(seconds: 25),
        );
      }

      await _maybeAnnounceNextManeuver(origin);
    } on RoutingServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _routeLoading = false;
        _routeError = _localizedRoutingError(e, l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routeLoading = false;
        _routeError = l10n.mapRouteUnavailable;
      });
    }
  }

  String _localizedRoutingError(
    RoutingServiceException exception,
    AppLocalizations l10n,
  ) {
    switch (exception.code) {
      case RoutingErrorCode.missingApiKey:
        return l10n.mapRouteApiKeyMissing;
      case RoutingErrorCode.noRoutes:
        return l10n.mapRouteNoRoads;
      default:
        return l10n.mapRouteUnavailable;
    }
  }

  Future<void> _fitRouteIntoView(List<NavigationPoint> polyline) async {
    if (_mapController == null || polyline.isEmpty) return;

    final points = <NavigationPoint>[...polyline];
    final current = _currentPosition;
    if (current != null) {
      points.add(_positionToPoint(current));
    }

    if (points.isEmpty) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if (minLat == maxLat && minLng == maxLng) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(minLat, minLng),
            zoom: 16,
          ),
        ),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 72),
      );
    } catch (_) {
      // no-op: map might be not fully laid out yet.
    }
  }

  int _resolveStepIndex({
    required NavigationPoint currentPoint,
    required NavigationRoute route,
    required int fromIndex,
  }) {
    if (route.steps.isEmpty) return 0;

    var index = fromIndex.clamp(0, route.steps.length - 1);
    while (index < route.steps.length - 1) {
      final step = route.steps[index];
      final distance = _distanceBetweenPoints(currentPoint, step.endPoint);
      if (distance > _navigationMonitor.config.stepArrivalThresholdMeters) {
        break;
      }
      index += 1;
    }

    return index;
  }

  void _updateCurrentStepIndex(NavigationPoint currentPoint) {
    final route = _activeRoute;
    if (route == null || route.steps.isEmpty) return;

    final nextIndex = _resolveStepIndex(
      currentPoint: currentPoint,
      route: route,
      fromIndex: _currentStepIndex,
    );

    if (!mounted || nextIndex == _currentStepIndex) return;
    setState(() {
      _currentStepIndex = nextIndex;
    });
  }

  Future<void> _maybeAnnounceNextManeuver(NavigationPoint currentPoint) async {
    if (!_voiceEnabled) return;

    final step = _nextStep;
    if (step == null) return;

    final l10n = AppLocalizations.of(context);
    final distanceMeters = _distanceBetweenPoints(currentPoint, step.endPoint);
    final roundedDistance = distanceMeters.round();

    final voiceInstruction = _toVoiceInstruction(step.instruction);
    if (voiceInstruction.isEmpty) return;

    if (roundedDistance <= _navigationMonitor.config.voiceNowDistanceMeters) {
      await _voiceService.speak(
        text: l10n.mapVoiceNowPrompt(voiceInstruction),
        promptKey:
            'maneuver_now_${widget.questId}_$_activeIndex$_currentStepIndex',
      );
      return;
    }

    if (roundedDistance <= _navigationMonitor.config.voiceSoonDistanceMeters) {
      await _voiceService.speak(
        text: l10n.mapVoiceSoonPrompt(roundedDistance, voiceInstruction),
        promptKey:
            'maneuver_soon_${widget.questId}_$_activeIndex$_currentStepIndex',
      );
    }
  }

  String _toVoiceInstruction(String instruction) {
    final normalized = instruction.trim();
    if (normalized.isEmpty) {
      return '';
    }

    if (normalized.endsWith('.')) {
      return normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }

  NavigationPoint _positionToPoint(Position position) {
    return NavigationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  double _distanceBetweenPoints(NavigationPoint from, NavigationPoint to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  NavigationStep? get _nextStep {
    final route = _activeRoute;
    if (route == null || route.steps.isEmpty) return null;
    if (_currentStepIndex < 0 || _currentStepIndex >= route.steps.length) {
      return null;
    }
    return route.steps[_currentStepIndex];
  }

  int? _remainingRouteDistanceMeters() {
    final route = _activeRoute;
    final current = _currentPosition;
    if (route == null || current == null || route.steps.isEmpty) return null;

    final currentPoint = _positionToPoint(current);
    final nextStep = _nextStep;
    if (nextStep == null) return null;

    var remaining = _distanceBetweenPoints(currentPoint, nextStep.endPoint)
        .round()
        .clamp(0, 2000000);

    for (var i = _currentStepIndex + 1; i < route.steps.length; i++) {
      remaining += route.steps[i].distanceMeters;
    }

    return remaining;
  }

  int? _remainingRouteDurationSeconds() {
    final route = _activeRoute;
    final remainingMeters = _remainingRouteDistanceMeters();
    if (route == null || remainingMeters == null || route.distanceMeters <= 0) {
      return null;
    }

    final ratio = remainingMeters / route.distanceMeters;
    return (route.durationSeconds * ratio)
        .round()
        .clamp(0, route.durationSeconds);
  }

  double? _distanceToNextManeuverMeters() {
    final current = _currentPosition;
    final step = _nextStep;
    if (current == null || step == null) return null;

    return _distanceBetweenPoints(
      _positionToPoint(current),
      step.endPoint,
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (var i = 0; i < _locations.length; i++) {
      final loc = _locations[i];
      final hue = i < _activeIndex
          ? BitmapDescriptor.hueGreen
          : (i == _activeIndex
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueAzure);

      markers.add(
        Marker(
          markerId: MarkerId(loc.id),
          position: LatLng(loc.latitude, loc.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${loc.name}',
            snippet: loc.description,
          ),
        ),
      );
    }

    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_locations.isEmpty) return {};

    final polylines = <Polyline>{};

    final activeRoute = _activeRoute;
    if (activeRoute != null && activeRoute.polylinePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('road_route'),
          color: AppColors.primary,
          width: 6,
          points: activeRoute.polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(growable: false),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true,
        ),
      );
      return polylines;
    }

    if (_currentPosition != null) {
      final target = _locations[_activeIndex];
      polylines.add(
        Polyline(
          polylineId: const PolylineId('fallback_line'),
          color: AppColors.accent.withValues(alpha: 0.45),
          width: 4,
          geodesic: true,
          points: [
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            LatLng(target.latitude, target.longitude),
          ],
        ),
      );
    }

    return polylines;
  }

  Future<void> _openExternalNavigation() async {
    if (_locations.isEmpty) return;

    final target = _locations[_activeIndex];
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}&travelmode=walking',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _goToTask() async {
    context.go('/quest/${widget.questId}/task/$_activeIndex');
  }

  Future<void> _skipToTaskInDebug() async {
    if (!kDebugMode) return;
    setState(() {
      _devOverride = !_devOverride;
    });
  }

  double? _distanceToTargetMeters() {
    if (_currentPosition == null || _locations.isEmpty) return null;
    final target = _locations[_activeIndex];
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      target.latitude,
      target.longitude,
    );
  }

  String _formatDistance(int meters, AppLocalizations l10n) {
    if (meters >= 1000) {
      final km = meters / 1000;
      final value = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
      return '$value ${l10n.kmLabel}';
    }
    return '$meters ${l10n.mapMetersLabel}';
  }

  String _formatEta(int seconds, AppLocalizations l10n) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) {
      return l10n.mapEtaMinutes(minutes);
    }

    final hours = minutes ~/ 60;
    final restMinutes = minutes % 60;
    return l10n.mapEtaHoursMinutes(hours, restMinutes);
  }

  IconData _maneuverIcon(String maneuver) {
    final normalized = maneuver.toLowerCase();

    if (normalized.contains('left')) {
      return Icons.turn_left_rounded;
    }
    if (normalized.contains('right')) {
      return Icons.turn_right_rounded;
    }
    if (normalized.contains('uturn')) {
      return Icons.u_turn_left_rounded;
    }
    if (normalized.contains('roundabout')) {
      return Icons.roundabout_left_rounded;
    }

    return Icons.straight_rounded;
  }

  void _toggleVoiceHints() {
    setState(() {
      _voiceEnabled = !_voiceEnabled;
    });
    _voiceService.setEnabled(_voiceEnabled);
    if (!_voiceEnabled) {
      unawaited(_voiceService.stop());
    }
  }

  Widget _buildRouteSummary(AppLocalizations l10n) {
    final remainingMeters = _remainingRouteDistanceMeters();
    final remainingSeconds = _remainingRouteDurationSeconds();

    if (remainingMeters != null && remainingSeconds != null) {
      return Row(
        children: [
          const Icon(Icons.route_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.mapRemainingRoute(
                _formatDistance(remainingMeters, l10n),
                _formatEta(remainingSeconds, l10n),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    final directDistance = _distanceToTargetMeters()?.round();
    if (directDistance != null) {
      return Text(
        l10n.distanceToTarget(directDistance),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTurnByTurnCard(AppLocalizations l10n) {
    final route = _activeRoute;
    final nextStep = _nextStep;

    if (route == null || nextStep == null || route.steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final distanceToManeuver = _distanceToNextManeuverMeters()?.round();
    final upcomingSteps = route.steps.skip(_currentStepIndex).take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _maneuverIcon(nextStep.maneuver),
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.mapNextManeuver,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (distanceToManeuver != null)
                Text(
                  l10n.mapDistanceToManeuver(distanceToManeuver),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nextStep.instruction,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.mapUpcomingSteps,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          ...upcomingSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _maneuverIcon(step.maneuver),
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.instruction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDistance(step.distanceMeters, l10n),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStatusBanners(AppLocalizations l10n) {
    final banners = <Widget>[];

    if (_routeLoading) {
      banners.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.mapRouteLoading,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isOffRoute) {
      final deviation = _offRouteDistanceMeters?.round();
      banners.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deviation != null
                      ? l10n.mapOffRouteDistance(deviation)
                      : l10n.mapOffRouteDetected,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_routeError != null) {
      banners.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _routeError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (final banner in banners) ...[
          banner,
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mapTitle)),
        body: Center(child: Text(_error!)),
      );
    }

    if (_locations.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mapTitle)),
        body: Center(child: Text(l10n.noLocations)),
      );
    }

    final target = _locations[_activeIndex];
    final canStartTask = _isWithinTargetRadius || _devOverride;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: [
          IconButton(
            onPressed: _toggleVoiceHints,
            tooltip:
                _voiceEnabled ? l10n.mapVoiceHintsOn : l10n.mapVoiceHintsOff,
            icon: Icon(
              _voiceEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              final route = _activeRoute;
              if (route != null) {
                unawaited(_fitRouteIntoView(route.polylinePoints));
              }
            },
            myLocationEnabled: _currentPosition != null,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            initialCameraPosition: CameraPosition(
              target: LatLng(target.latitude, target.longitude),
              zoom: 14,
            ),
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.pointOf(_activeIndex + 1, _locations.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(target.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  _buildRouteSummary(l10n),
                  const SizedBox(height: 8),
                  _buildRouteStatusBanners(l10n),
                  _buildTurnByTurnCard(l10n),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: canStartTask ? _goToTask : null,
                          icon: const Icon(Icons.task_alt_rounded),
                          label: Text(
                            canStartTask ? l10n.doTask : l10n.moveCloser,
                          ),
                        ),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _skipToTaskInDebug,
                          tooltip: l10n.devBypass,
                          icon: Icon(
                            _devOverride
                                ? Icons.lock_open_rounded
                                : Icons.lock_rounded,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openExternalNavigation,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l10n.mapOpenGoogleMapsFallback),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
