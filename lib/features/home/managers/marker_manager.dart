import 'dart:async';
import 'package:flutter/material.dart';
import 'package:harkai/core/managers/download_data_manager.dart';
import '../utils/incidences.dart';
import '../utils/markers.dart';
import '../modals/incident_description.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:harkai/features/home/utils/extensions.dart';

class MarkerManager {
  final FirestoreService _firestoreService;
  final VoidCallback _onStateChange;
  final DownloadDataManager _downloadDataManager;

  MakerType _selectedIncident = MakerType.none;
  MakerType get selectedIncident => _selectedIncident;

  List<IncidenceData> _incidencesData = [];
  List<IncidenceData> get incidences => _incidencesData;

  StreamSubscription<List<IncidenceData>>? _incidentsSubscription;
  Timer? _expiryCheckTimer;

  MarkerManager({
    required FirestoreService firestoreService,
    required VoidCallback onStateChange,
    required DownloadDataManager downloadDataManager,
  })  : _firestoreService = firestoreService,
        _onStateChange = onStateChange,
        _downloadDataManager = downloadDataManager;

  Future<void> initialize(AppLocalizations localizations) async {
    _setupIncidentListener(localizations);
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
      _onStateChange();
      debugPrint('MarkerManager: Error fetching incidents: $error');
    });
  }
  
  void _startPeriodicExpiryChecks({Duration interval = const Duration(hours: 1)}) {
    _expiryCheckTimer?.cancel();
    _expiryCheckTimer = Timer.periodic(interval, (timer) async {
      int cleanedCount = await _firestoreService.markExpiredIncidencesAsInvisible();
      debugPrint('MarkerManager: Periodic cleanup completed. $cleanedCount incidents marked invisible.');
    });
    debugPrint('MarkerManager: Periodic expiry checks started with an interval of ${interval.inMinutes} minutes.');
  }

  Future<void> addMarkerAndShowNotification({
    required BuildContext context,
    required MakerType makerType,
    required double latitude,
    required double longitude,
    String? description,
    String? imageUrl,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    final success = await _firestoreService.addIncidence(
      type: makerType,
      latitude: latitude,
      longitude: longitude,
      description: description,
      imageUrl: imageUrl,
    );

    if (context.mounted) {
      final markerInfo = getMarkerInfo(makerType, localizations); 
      final String markerTitle = markerInfo?.title ?? makerType.name.toString().split('.').last.capitalizeAllWords();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? localizations.incidentReportedSuccess(markerTitle)
              : localizations.incidentReportFailed(markerTitle)),
        ),
      );

      if (success) {
        // Trigger a check for new incidents in the user's city
        final userCity = "Default City"; // Replace with actual user city
        await _downloadDataManager.checkForNewIncidents(userCity);
      }
    }
  }

  Future<void> processIncidentReporting({
    required BuildContext context,
    required AppLocalizations localizations,
    required MakerType newMarkerToSelect,
    required double? targetLatitude,
    required double? targetLongitude,
  }) async {
    if (_selectedIncident == newMarkerToSelect) {
      _selectedIncident = MakerType.none;
      _onStateChange();
      debugPrint("MarkerManager: Deselected incident type ${newMarkerToSelect.name}.");
      return;
    }

    _selectedIncident = newMarkerToSelect;
    _onStateChange();
    debugPrint("MarkerManager: Selected incident type ${newMarkerToSelect.name} for reporting.");

    if (targetLatitude != null && targetLongitude != null) {
      final result = await showIncidentVoiceDescriptionDialog(
        context: context,
        markerType: _selectedIncident,
      );

      if (result != null) {
        final String? description = result['description'];
        final String? imageUrl = result['imageUrl'];

        if (description != null || imageUrl != null) {
          if (context.mounted) {
            await addMarkerAndShowNotification(
              context: context,
              makerType: _selectedIncident,
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
      _selectedIncident = MakerType.none;
      _onStateChange();
    }
  }
  
  Future<void> processEmergencyReporting({
    required BuildContext context,
    required AppLocalizations localizations,
    required double? targetLatitude,
    required double? targetLongitude,
  }) async {
    _selectedIncident = MakerType.emergency;
    _onStateChange();
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
            debugPrint("MarkerManager: Emergency incident reported. Selection persists as 'emergency'.");
          }
        } else {
          debugPrint("MarkerManager: Emergency reporting cancelled (no media). Reverting selection.");
          _selectedIncident = MakerType.none;
          _onStateChange();
        }
      } else {
        debugPrint("MarkerManager: Emergency reporting dialog cancelled by user. Reverting selection.");
        _selectedIncident = MakerType.none;
        _onStateChange();
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.emergencyReportLocationUnknown)),
        );
      }
      debugPrint("MarkerManager: Target location not set for emergency report. Reverting selection.");
      _selectedIncident = MakerType.none;
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