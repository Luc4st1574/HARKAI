import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/features/home/widgets/header.dart'; // Reusing your existing header
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
  bool _isLoading = true;
  String _error = '';

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _fetchCurrentUserLocation();
    if (_currentPosition != null) {
      _fetchIncidents();
    }
  }

  Future<void> _fetchCurrentUserLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final locationResult = await _locationService.getInitialPosition();
      if (!mounted) return;
      if (locationResult.success && locationResult.data != null) {
        setState(() {
          _currentPosition = locationResult.data;
        });
      } else {
        setState(() {
          _error = locationResult.errorMessage ?? localizations.mapCurrentUserLocationNotAvailable;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizations.mapErrorFetchingLocation(e.toString());
        _isLoading = false;
      });
    }
  }

  void _fetchIncidents() {
    if (_currentPosition == null) {
      if (mounted) {
        setState(() {
          _error = localizations.mapCurrentUserLocationNotAvailable;
          _isLoading = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    _firestoreService.getIncidencesStreamByType(widget.incidentType).listen(
      (incidentsOfType) {
        if (!mounted) return;
        List<IncidenceData> processedIncidents = List.from(incidentsOfType);
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
        setState(() {
          _incidents = processedIncidents;
          _isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _error = localizations.incidentReportFailed("incidents"); 
          _isLoading = false;
        });
      },
    );
  }

  // Updated method to show the map modal
  void _navigateToIncidentMap(IncidenceData incident) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      // barrierDismissible: false, // Consider if you want this
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)), // Rounded corners for the dialog
          backgroundColor: Colors.transparent, // Make dialog background transparent
          elevation: 0, // No elevation for the dialog itself
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05, // 5% padding horizontally
            vertical: screenHeight * 0.1,   // 10% padding vertically
          ),
          child: SizedBox( // Constrain the size of the modal content
            width: screenWidth * 0.9,
            height: screenHeight * 0.7, // Adjust height as needed
            child: Stack( // Use Stack to overlay close button
              children: [
                ClipRRect( // Clip the map content to the dialog's rounded corners
                  borderRadius: BorderRadius.circular(15.0),
                  child: IncidentMapViewContent( 
                    incident: incident,
                    incidentTypeForExpiry: widget.incidentType,
                  ),
                ),
                Positioned( // Position the close button
                  top: 8.0,
                  right: 8.0,
                  child: Material( // Material for InkWell splash effect
                    color: Colors.black.withOpacity(0.5), // Semi-transparent background for button
                    shape: const CircleBorder(),
                    elevation: 2.0,
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
    if (_isLoading && _incidents.isEmpty) { 
      return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
        ),
      );
    }
    if (_incidents.isEmpty) {
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
}