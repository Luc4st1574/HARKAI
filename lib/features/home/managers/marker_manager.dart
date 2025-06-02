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

  // Store raw IncidenceData
  List<IncidenceData> _incidencesData = [];
  List<IncidenceData> get incidences => _incidencesData;

  // Circles remain similar
  Set<Circle> _incidentCircles = {};
  Set<Circle> get incidentCircles => _incidentCircles;

  StreamSubscription<List<IncidenceData>>? _incidentsSubscription;
  Timer? _expiryCheckTimer;

  MarkerManager({
    required FirestoreService firestoreService,
    required VoidCallback onStateChange,
  })  : _firestoreService = firestoreService,
        _onStateChange = onStateChange;

  Future<void> initialize() async {
    _setupIncidentListener();
    debugPrint('MarkerManager: Initializing and performing initial cleanup...');
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
      _incidencesData = incidences; // Store raw data
      
      // Circles can still be generated here or in Home.dart
      final newCircles = <Circle>{};
      for (var incidence in incidences) {
        newCircles.add(createCircleFromIncidence(incidence));
      }
      _incidentCircles = newCircles;
      
      _onStateChange(); // Notify Home to rebuild markers
    }, onError: (error) {
      _incidencesData = [];
      _incidentCircles = {};
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
        } else {
          debugPrint('MarkerManager: No expired incidents found in periodic check.');
        }
      } catch (e) {
        debugPrint('MarkerManager: Error during periodic expiry check: $e');
      }
    });
    debugPrint('MarkerManager: Periodic expiry checks started with an interval of ${interval.inMinutes} minutes.');
  }


  Future<void> addMarkerAndShowNotification({ // Renamed from addMarkerAndShowNotification
    required BuildContext context,
    required MakerType makerType,
    required double latitude,
    required double longitude,
    String? description,
    String? imageUrl, // New parameter
  }) async {
    final success = await _firestoreService.addIncidence(
      type: makerType,
      latitude: latitude,
      longitude: longitude,
      description: description,
      imageUrl: imageUrl, // Pass imageUrl
    );

    if (context.mounted) {
      final markerInfo = getMarkerInfo(makerType);
      final String markerTitle = markerInfo?.title ?? _StringExtension(makerType.name.toString().split('.').last).capitalizeAllWords();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '$markerTitle incident reported!'
              : 'Failed to report $markerTitle incident.'),
        ),
      );
    }
  }

  // This method now triggers the dialog and processes its result
  Future<void> processIncidentReporting({
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
        // Show the media input dialog
        final result = await showIncidentVoiceDescriptionDialog( // This is your enhanced modal
          context: context,
          markerType: newInternalSelectedMarker,
        );

        // result is now Map<String, String?>? e.g., {'description': '...', 'imageUrl': '...'}
        if (result != null) {
          final String? description = result['description'];
          final String? imageUrl = result['imageUrl'];

          // Only add marker if there's a description or an image
          if (description != null || imageUrl != null) {
            if (context.mounted) {
              await addMarkerAndShowNotification(
                context: context,
                makerType: newInternalSelectedMarker, // Use the marker type selected for the dialog
                latitude: targetLatitude,
                longitude: targetLongitude,
                description: description,
                imageUrl: imageUrl,
              );
            }
          } else {
            debugPrint("Incident reporting cancelled or no media provided.");
          }
        } else {
            debugPrint("Incident reporting dialog returned null (cancelled).");
        }
        // Reset selected incident if dialog is cancelled or completed, to allow re-selection
        _selectedIncident = MakerType.none;
        _onStateChange();

      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target location not set. Tap on map or use compass.')),
          );
        }
        _selectedIncident = MakerType.none;
        _onStateChange();
      }
    } else if (wasSelected) { // If it was already selected, deselect it
      _selectedIncident = MakerType.none;
      _onStateChange();
    }
  }
  
  // Simplified version for emergency, assuming it might have a slightly different flow or pre-filled description.
  // Or it could also use the full processIncidentReporting. For now, let's keep it similar.
  Future<void> processEmergencyReporting({
    required BuildContext context,
    required double? targetLatitude,
    required double? targetLongitude,
  }) async {
    if (targetLatitude != null && targetLongitude != null) {
      final result = await showIncidentVoiceDescriptionDialog(
        context: context,
        markerType: MakerType.emergency, // Specifically for emergency
      );

      if (result != null) {
        final String? description = result['description'];
        final String? imageUrl = result['imageUrl'];
        
        if (description != null || imageUrl != null) {
            if (context.mounted) {
              await addMarkerAndShowNotification(
                  context: context,
                  makerType: MakerType.emergency,
                  latitude: targetLatitude,
                  longitude: targetLongitude,
                  description: description ?? "Emergency Report", // Default description if none
                  imageUrl: imageUrl,
              );
              // Optionally, keep emergency selected or clear it
              setActiveMaker(MakerType.emergency);
              _selectedIncident = MakerType.none; // Clear after reporting
              _onStateChange();
            }
        } else {
            debugPrint("Emergency reporting cancelled or no media provided.");
        }
      } else {
          debugPrint("Emergency reporting dialog returned null (cancelled).");
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to report emergency: Target location unknown.')),
        );
      }
    }
  }


  void resetSelectedMarkerToNone() {
    _selectedIncident = MakerType.none;
    _onStateChange();
  }

  void dispose() {
    _incidentsSubscription?.cancel();
    _expiryCheckTimer?.cancel();
    debugPrint('MarkerManager: Disposed.');
  }
}

extension _StringExtension on String {
    String capitalizeAllWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }
}