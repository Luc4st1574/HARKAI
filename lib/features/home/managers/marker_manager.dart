import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/incidences.dart';
import '../utils/markers.dart';
import '../modals/incident_description.dart';

class MarkerManager {
  final FirestoreService _firestoreService;
  final VoidCallback _onStateChange;

  MakerType _selectedIncident = MakerType.none;
  MakerType get selectedIncident => _selectedIncident;

  Set<Marker> _incidentMarkers = {};
  Set<Marker> get incidentMarkers => _incidentMarkers;

  Set<Circle> _incidentCircles = {}; // New: Set to store circles
  Set<Circle> get incidentCircles => _incidentCircles; // New: Getter for circles

  StreamSubscription<List<IncidenceData>>? _incidentsSubscription;
  Timer? _expiryCheckTimer;

  MarkerManager({
    required FirestoreService firestoreService,
    required VoidCallback onStateChange,
  })  : _firestoreService = firestoreService,
        _onStateChange = onStateChange;

  Future<void> initialize() async {
    _setupIncidentListener();
    debugPrint('MarkerManager: Initializing and performing initial cleanup of expired incidents...');
    int initialCleanedCount = await _firestoreService.markExpiredIncidencesAsInvisible();
    debugPrint('MarkerManager: Initial cleanup completed. $initialCleanedCount incidents marked invisible.');
    _startPeriodicExpiryChecks();
  }

  void setActiveMaker(MakerType markerType) {
    _selectedIncident = markerType;
    _onStateChange();
  }

  void _setupIncidentListener() {
    _incidentsSubscription = _firestoreService
        .getIncidencesStream()
        .listen((List<IncidenceData> incidences) {
      final newMarkers = <Marker>{};
      final newCircles = <Circle>{}; // New: Set for circles for this update
      for (var incidence in incidences) {
        newMarkers.add(createMarkerFromIncidence(incidence));
        newCircles.add(createCircleFromIncidence(incidence)); // New: Create and add circle
      }
      _incidentMarkers = newMarkers;
      _incidentCircles = newCircles; // New: Update the circles set
      _onStateChange();
    }, onError: (error) {
      _incidentMarkers = {};
      _incidentCircles = {}; // New: Clear circles on error too
      _onStateChange();
      debugPrint('MarkerManager: Error fetching incidents: $error');
    });
  }

  void _startPeriodicExpiryChecks({Duration interval = const Duration(hours: 1)}) {
    _expiryCheckTimer?.cancel();
    _expiryCheckTimer = Timer.periodic(interval, (timer) async {
      debugPrint('MarkerManager: Performing periodic check for expired incidents...');
      try {
        int cleanedCount = await _firestoreService.markExpiredIncidencesAsInvisible();
        if (cleanedCount > 0) {
          debugPrint('MarkerManager: Periodically marked $cleanedCount expired incidents as invisible.');
          // The stream listener (_setupIncidentListener) will automatically update markers and circles.
        } else {
          debugPrint('MarkerManager: No expired incidents found in periodic check.');
        }
      } catch (e) {
        debugPrint('MarkerManager: Error during periodic expiry check: $e');
      }
    });
    debugPrint('MarkerManager: Periodic expiry checks started with an interval of ${interval.inMinutes} minutes.');
  }

  Future<bool> addMarkerAndShowNotification({
    required BuildContext context,
    required MakerType makerType,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    final success = await _firestoreService.addIncidence(
      type: makerType,
      latitude: latitude,
      longitude: longitude,
      description: description,
    );

    if (context.mounted) {
      final markerInfo = getMarkerInfo(makerType);
      final String markerTitle = markerInfo?.title ?? makerType.name.toString().split('.').last.capitalizeAllWords();
      // Show a snackbar notification with the result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '$markerTitle marker added!'
              : 'Failed to add ${markerTitle.toLowerCase()} marker.'),
        ),
      );
    }
    return success;
  }

  Future<String?> handleMarkerSelectionAndGetDescription({
    required BuildContext context,
    required MakerType newMarkerToSelect,
    required double? targetLatitude,
    required double? targetLongitude,
  }) async {
    final bool wasSelected = _selectedIncident == newMarkerToSelect;
    final MakerType newInternalSelectedMarker = wasSelected ? MakerType.none : newMarkerToSelect;

    _selectedIncident = newInternalSelectedMarker;
    _onStateChange();

    if (!wasSelected && newInternalSelectedMarker != MakerType.none) {
      if (targetLatitude != null && targetLongitude != null) {
        final description = await showIncidentVoiceDescriptionDialog(
          context: context,
          markerType: newInternalSelectedMarker,
        );
        if (description == null) {
          _selectedIncident = MakerType.none;
          _onStateChange();
          return null;
        }
        return description;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target location not set. Tap on map or use compass.')),
          );
        }
        _selectedIncident = MakerType.none;
        _onStateChange();
        return null;
      }
    } else if (wasSelected) {
      _selectedIncident = MakerType.none;
      _onStateChange();
    }
    return null;
  }

  Future<String?> handleEmergencyAndGetDescription({
    required BuildContext context,
    required double? targetLatitude,
    required double? targetLongitude,
  }) async {
    if (targetLatitude != null && targetLongitude != null) {
      final description = await showIncidentVoiceDescriptionDialog(
        context: context,
        markerType: MakerType.emergency,
      );
      return description;
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to add emergency marker: Target location unknown.')),
        );
      }
      return null;
    }
  }

  void resetSelectedMarkerToNone() {
    _selectedIncident = MakerType.none;
    _onStateChange();
  }

  void dispose() {
    _incidentsSubscription?.cancel();
    _expiryCheckTimer?.cancel();
    debugPrint('MarkerManager: Disposed. Incidents subscription and expiry timer cancelled.');
  }
}