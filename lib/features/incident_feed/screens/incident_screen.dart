import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/features/home/widgets/header.dart';
import 'package:harkai/core/services/location_service.dart';
import 'package:harkai/l10n/app_localizations.dart';
import '../widgets/incident_tile.dart';
import '../widgets/map_view.dart'; // To show map on tile tap

class IncidentScreen extends StatefulWidget {
  final MakerType incidentType;
  final User? currentUser;

  const IncidentScreen({
    super.key,
    required this.incidentType,
    required this.currentUser,
  });

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  
  List<IncidenceData> _incidents = [];
  Position? _currentPosition;
  bool _isLoadingInitialData = true; // For initial load
  String _error = '';

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<List<IncidenceData>>? _incidentsStreamSubscription;

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize only once
    if (_incidentsStreamSubscription == null && _positionStreamSubscription == null) {
      _initializeScreenData();
    }
  }

  Future<void> _initializeScreenData() async {
    await _fetchInitialUserLocation(); // Get initial location first
    _listenToIncidents();       // Then start listening to incidents
    _startListeningToLocationUpdates(); // And start listening to location updates
  }

  Future<void> _fetchInitialUserLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInitialData = true; // Still true until incidents are also loaded
      _error = '';
    });
    try {
      final locationResult = await _locationService.getInitialPosition();
      if (!mounted) return;
      if (locationResult.success && locationResult.data != null) {
        _currentPosition = locationResult.data; 
      } else {
        _currentPosition = null; // Ensure it's null if fetch failed
        _error = locationResult.errorMessage ?? localizations.mapCurrentUserLocationNotAvailable;
      }
    } catch (e) {
      if (!mounted) return;
      _currentPosition = null;
      _error = localizations.mapErrorFetchingLocation(e.toString());
    }
    // No setState here, _listenToIncidents will handle initial loading state for UI
  }

  void _listenToIncidents() {
    if (!mounted) return;
    _incidentsStreamSubscription?.cancel();

    if (_currentPosition != null && _incidents.isEmpty) {
      setState(() { _isLoadingInitialData = true; });
    }


    _incidentsStreamSubscription = _firestoreService
        .getIncidencesStreamByType(widget.incidentType)
        .listen(
      (incidentsOfType) {
        if (!mounted) return;
        _processIncidentsUpdate(incidentsOfType);
        setState(() { _isLoadingInitialData = false; }); // Data loaded (or empty)
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _error = localizations.incidentReportFailed("incidents");
          _incidents = [];
          _isLoadingInitialData = false;
        });
      },
    );
  }
  
  void _startListeningToLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = _locationService.getPositionStream(
    ).listen(
      (Position newPosition) {
        if (mounted) {
          _currentPosition = newPosition;
          _processIncidentsUpdate(List.from(_incidents));
        }
      },
      onError: (error) {
        debugPrint("Error in IncidentScreen location stream: $error");
      },
    );
  }

  void _processIncidentsUpdate(List<IncidenceData> newIncidents) {
    if (!mounted) return;

    List<IncidenceData> processedIncidents = List.from(newIncidents);

    if (_currentPosition != null) {
      for (var incident in processedIncidents) {
        incident.distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          incident.latitude,
          incident.longitude,
        );
      }
      processedIncidents.sort((a, b) =>
          (a.distance ?? double.maxFinite)
              .compareTo(b.distance ?? double.maxFinite));
    }

    if (widget.incidentType == MakerType.pet) {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      processedIncidents.removeWhere((incident) {
        return incident.timestamp.toDate().isBefore(startOfToday);
      });
    }
    
    bool listChanged = _incidents.length != processedIncidents.length ||
                      (_incidents.isNotEmpty && processedIncidents.isNotEmpty && _incidents.first.id != processedIncidents.first.id) ||
                      true; 

    if (listChanged) {
      setState(() {
        _incidents = processedIncidents;
      });
    }
  }

  void _navigateToIncidentMap(IncidenceData incident) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // localizations are available via the getter

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.1,
          ),
          child: SizedBox(
            width: screenWidth * 0.9,
            height: screenHeight * 0.7,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15.0),
                  child: IncidentMapViewContent( 
                    incident: incident,
                    incidentTypeForExpiry: widget.incidentType,
                  ),
                ),
                // Positioned Close Button - MODIFIED HERE
                Positioned(
                  top: 8.0,
                  left: 8.0, // Changed from right: 8.0 to left: 8.0
                  child: Material(
                    color: Colors.black.withOpacity(0.6),
                    shape: const CircleBorder(),
                    elevation: 4.0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20.0),
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  String _getScreenTitleText() {
    final markerInfo = getMarkerInfo(widget.incidentType, localizations);
    return localizations.incidentScreenTitle(markerInfo?.title ?? widget.incidentType.name.capitalizeAllWords());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: SafeArea( 
        child: Column(
          children: [
            HomeHeaderWidget(currentUser: widget.currentUser),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                _getScreenTitleText(),
                style: const TextStyle(
                  color: Color(0xFF57D463),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 20.0), 
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25), 
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitialData && _incidents.isEmpty) { 
      return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
    }
    if (_error.isNotEmpty && _incidents.isEmpty) { // Show error only if no incidents to display
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
        ),
      );
    }
    if (_incidents.isEmpty) { // Handles case after loading, but list is empty (and no error)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            localizations.incidentFeedNoIncidentsFound(
              getMarkerInfo(widget.incidentType, localizations)?.title ?? widget.incidentType.name.capitalizeAllWords()
            ),
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _incidents.length,
      itemBuilder: (context, index) {
        final incident = _incidents[index];
        return IncidentTile(
          incident: incident,
          distance: incident.distance, 
          onTap: () => _navigateToIncidentMap(incident),
          localizations: localizations,
        );
      },
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _incidentsStreamSubscription?.cancel();
    super.dispose();
  }
}