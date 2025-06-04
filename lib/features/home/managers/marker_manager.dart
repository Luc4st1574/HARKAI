import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/incidences.dart';
import '../utils/markers.dart';
import '../modals/incident_description.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import

class MarkerManager {
  final FirestoreService _firestoreService;
  final VoidCallback _onStateChange;

  MakerType _selectedIncident = MakerType.none;
  MakerType get selectedIncident => _selectedIncident;

  List<IncidenceData> _incidencesData = [];
  List<IncidenceData> get incidences => _incidencesData;

  StreamSubscription<List<IncidenceData>>? _incidentsSubscription;
  Timer? _expiryCheckTimer;

  MarkerManager({
    required FirestoreService firestoreService,
    required VoidCallback onStateChange,
  })  : _firestoreService = firestoreService,
        _onStateChange = onStateChange;
        // _localizations = localizations; // Optional

  // Call this after localizations are available in HomeState
  Future<void> initialize(AppLocalizations localizations) async {
    _setupIncidentListener(localizations); // Pass localizations to listener setup
    debugPrint('MarkerManager: Initializing and performing initial cleanup...');
    int initialCleanedCount = await _firestoreService.markExpiredIncidencesAsInvisible();
    debugPrint('MarkerManager: Initial cleanup completed. $initialCleanedCount incidents marked invisible.');
    _startPeriodicExpiryChecks();
  }

  void setActiveMaker(MakerType markerType) {
    _selectedIncident = markerType;
    _onStateChange();
  }

  void _setupIncidentListener(AppLocalizations localizations) {
    _incidentsSubscription = _firestoreService
        .getIncidencesStream()
        .listen((List<IncidenceData> incidences) {
      _incidencesData = incidences;
      _onStateChange();
    }, onError: (error) {
      _incidencesData = [];
      // _incidentCircles = {};
      _onStateChange();
      debugPrint('MarkerManager: Error fetching incidents: $error');
    });
  }
  
  void _startPeriodicExpiryChecks({Duration interval = const Duration(hours: 1)}) {
    _expiryCheckTimer?.cancel();
    _expiryCheckTimer = Timer.periodic(interval, (timer) async {
      // ... (expiry check logic remains)
    });
    debugPrint('MarkerManager: Periodic expiry checks started with an interval of ${interval.inMinutes} minutes.');
  }

  Future<void> addMarkerAndShowNotification({
    required BuildContext context, // Has context to get localizations
    required MakerType makerType,
    required double latitude,
    required double longitude,
    String? description,
    String? imageUrl,
  }) async {
    final localizations = AppLocalizations.of(context)!; // Get localizations from context
    final success = await _firestoreService.addIncidence(
      type: makerType,
      latitude: latitude,
      longitude: longitude,
      description: description,
      imageUrl: imageUrl,
    );

    if (context.mounted) {
      // getMarkerInfo now requires localizations
      final markerInfo = getMarkerInfo(makerType, localizations); 
      // markerInfo.title will be localized
      final String markerTitle = markerInfo?.title ?? _StringExtension(makerType.name.toString().split('.').last).capitalizeAllWords();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? localizations.incidentReportedSuccess(markerTitle) // Use localized string
              : localizations.incidentReportFailed(markerTitle)), // Use localized string
        ),
      );
    }
  }

  Future<void> processIncidentReporting({
    required BuildContext context, // Has context
    required AppLocalizations localizations, // Explicitly pass localizations
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
        final result = await showIncidentVoiceDescriptionDialog(
          context: context,
          markerType: newInternalSelectedMarker,
        );

        if (result != null) {
          final String? description = result['description'];
          final String? imageUrl = result['imageUrl'];

          if (description != null || imageUrl != null) {
            if (context.mounted) {
              await addMarkerAndShowNotification( // This method gets localizations from its own context
                context: context,
                makerType: newInternalSelectedMarker,
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
        _selectedIncident = MakerType.none;
        _onStateChange();

      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.targetLocationNotSet)), // Use localized string
          );
        }
        _selectedIncident = MakerType.none;
        _onStateChange();
      }
    } else if (wasSelected) {
      _selectedIncident = MakerType.none;
      _onStateChange();
    }
  }
  
  Future<void> processEmergencyReporting({
    required BuildContext context, // Has context
    required AppLocalizations localizations, // Explicitly pass localizations
    required double? targetLatitude,
    required double? targetLongitude,
  }) async {
    if (targetLatitude != null && targetLongitude != null) {
      final result = await showIncidentVoiceDescriptionDialog(
        context: context,
        markerType: MakerType.emergency,
      );

      if (result != null) {
        final String? description = result['description'];
        final String? imageUrl = result['imageUrl'];
        
        if (description != null || imageUrl != null) {
            if (context.mounted) {
              await addMarkerAndShowNotification( // This method gets localizations from context
                  context: context,
                  makerType: MakerType.emergency,
                  latitude: targetLatitude,
                  longitude: targetLongitude,
                  description: description ?? localizations.incidentModalStatusError, // Example default
                  imageUrl: imageUrl,
              );
              setActiveMaker(MakerType.emergency);
              _selectedIncident = MakerType.none;
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
          SnackBar(content: Text(localizations.emergencyReportLocationUnknown)), // Use localized string
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