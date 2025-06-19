import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/incidences.dart';
import '../utils/markers.dart';
import '../modals/incident_description.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:harkai/features/home/utils/extensions.dart';

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
    if (_selectedIncident != markerType) {
      _selectedIncident = markerType;
      _onStateChange();
    }
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
      final String markerTitle = markerInfo?.title ?? makerType.name.toString().split('.').last.capitalizeAllWords();
      
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
    required BuildContext context,
    required AppLocalizations localizations,
    required MakerType newMarkerToSelect, // This is the type of the button pressed
    required double? targetLatitude,
    required double? targetLongitude,
  }) async {
    if (_selectedIncident == newMarkerToSelect) {
      // If the same incident button is tapped again, deselect it.
      _selectedIncident = MakerType.none;
      _onStateChange();
      debugPrint("MarkerManager: Deselected incident type ${newMarkerToSelect.name}.");
      return; // Exit without showing dialog
    }

    // A new incident type is selected, or an existing different one was active.
    _selectedIncident = newMarkerToSelect;
    _onStateChange();
    debugPrint("MarkerManager: Selected incident type ${newMarkerToSelect.name} for reporting.");

    if (targetLatitude != null && targetLongitude != null) {
      final result = await showIncidentVoiceDescriptionDialog(
        context: context,
        markerType: _selectedIncident, // Use the currently active _selectedIncident
      );

      if (result != null) {
        final String? description = result['description'];
        final String? imageUrl = result['imageUrl'];

        if (description != null || imageUrl != null) {
          if (context.mounted) {
            await addMarkerAndShowNotification(
              context: context,
              makerType: _selectedIncident, // Report the currently active type
              latitude: targetLatitude,
              longitude: targetLongitude,
              description: description,
              imageUrl: imageUrl,
            );
            debugPrint("MarkerManager: Incident ${_selectedIncident.name} reported. Selection persists.");
          }
        } else {
          debugPrint("MarkerManager: Incident reporting cancelled or no media provided for ${_selectedIncident.name}. Reverting selection.");
          _selectedIncident = MakerType.none;
          _onStateChange();
        }
      } else {
        // Dialog was cancelled by the user (e.g., back button or cancel button in modal)
        debugPrint("MarkerManager: Incident reporting dialog cancelled by user for ${_selectedIncident.name}. Reverting selection.");
        _selectedIncident = MakerType.none;
        _onStateChange();
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.targetLocationNotSet)),
        );
      }
      debugPrint("MarkerManager: Target location not set for ${_selectedIncident.name}. Reverting selection.");
      _selectedIncident = MakerType.none; // Reset if no target location
      _onStateChange();
    }
  }
  
  Future<void> processEmergencyReporting({
    required BuildContext context,
    required AppLocalizations localizations,
    required double? targetLatitude,
    required double? targetLongitude,
  }) async {
    // Always treat emergency button press as selecting MakerType.emergency
    _selectedIncident = MakerType.emergency;
    _onStateChange(); // Update UI (phone button text to "Call Emergencies" or specific agent)
    debugPrint("MarkerManager: Emergency reporting selected.");

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
            await addMarkerAndShowNotification(
              context: context,
              makerType: MakerType.emergency,
              latitude: targetLatitude,
              longitude: targetLongitude,
              description: description ?? localizations.incidentModalStatusError,
              imageUrl: imageUrl,
            );
            // Emergency reported. _selectedIncident REMAINS MakerType.emergency
            debugPrint("MarkerManager: Emergency incident reported. Selection persists as 'emergency'.");
          }
        } else {
          debugPrint("MarkerManager: Emergency reporting cancelled (no media). Reverting selection.");
          _selectedIncident = MakerType.none;
          _onStateChange();
        }
      } else {
        debugPrint("MarkerManager: Emergency reporting dialog cancelled by user. Reverting selection.");
        _selectedIncident = MakerType.none; // Reset if dialog is cancelled
        _onStateChange();
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.emergencyReportLocationUnknown)),
        );
      }
      debugPrint("MarkerManager: Target location not set for emergency report. Reverting selection.");
      _selectedIncident = MakerType.none; // Reset if no target location
      _onStateChange();
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