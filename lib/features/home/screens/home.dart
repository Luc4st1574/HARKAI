import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Services
import '../../../core/services/location_service.dart';
import '../../../core/services/phone_service.dart';
import '../../../core/services/speech_service.dart';

// Utils (Models and Map Utilities)
import '../utils/incidences.dart';
import '../utils/markers.dart';

// Widgets for this screen
import '../widgets/header.dart';
import '../widgets/location_info.dart';
import '../widgets/map.dart';
import '../widgets/incident_buttons.dart';
import '../widgets/bottom_butons.dart';
import '../modals/incident_image.dart';

// Managers
import '../managers/marker_manager.dart';
import '../managers/map_location_manager.dart';
import '../managers/session_permision_manager.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Service Instances
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService(); // Used by MarkerManager
  final PhoneService _phoneService = PhoneService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final SpeechPermissionService _speechPermissionService = SpeechPermissionService();

  // Managers
  late final MarkerManager _dataEventManager;
  late final MapLocationManager _mapLocationManager;
  late final UserSessionManager _userSessionManager;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();

    _userSessionManager = UserSessionManager(
      firebaseAuthInstance: _firebaseAuth,
      phoneService: _phoneService,
      onAuthChangedCallback: (User? user) {
        if (mounted) setState(() {});
      },
    );

    _mapLocationManager = MapLocationManager(
      locationService: _locationService,
      onStateChange: () { if (mounted) setState(() {}); },
      getMapController: () => _mapController,
      setMapController: (controller) {
        if (mounted) {
          if (_mapController != controller) {
              _mapController = controller;
          }
        }
      },
    );
    
    _dataEventManager = MarkerManager(
      firestoreService: _firestoreService, // Pass the instance
      onStateChange: () { if (mounted) setState(() {}); },
    );

    _initializeScreenData();
  }

  Future<void> _initializeScreenData() async {
    _userSessionManager.initialize();
    await _mapLocationManager.initializeManager();
    await _dataEventManager.initialize(); // Initializes MarkerManager
    bool speechReady = await _speechPermissionService.ensurePermissionsAndInitializeService(openSettingsOnError: true);
    debugPrint("Home: Speech service ready: $speechReady");
  }

  @override
  void dispose() {
    _userSessionManager.dispose();
    _mapLocationManager.dispose();
    _dataEventManager.dispose();
    _mapController?.dispose();
    super.dispose();
  }
  
  // Method to prepare markers for the map, including custom onTap for image markers
  Set<Marker> _prepareMapMarkers() {
    // Use the raw IncidenceData list from MarkerManager
    return _dataEventManager.incidences 
        .map((incidence) => createMarkerFromIncidence( // from incidences.dart
              incidence,
              onImageMarkerTapped: (tappedIncidence) { 
                // This callback is passed to createMarkerFromIncidence
                // It will be set as the onTap for markers that have an imageUrl
                showDialog(
                  context: context, // Use the Home screen's context
                  builder: (_) => IncidentImageDisplayModal(incidence: tappedIncidence),
                );
              },
            ))
        .toSet();
  }

  Set<Marker> _getDisplayMarkers() {
    Set<Marker> displayMarkers = _prepareMapMarkers(); // Uses the new method

    final targetLat = _mapLocationManager.targetLatitude;
    final targetLng = _mapLocationManager.targetLongitude;
    final targetPin = _mapLocationManager.targetPinDot;

    if (targetLat != null && targetLng != null && targetPin != null) {
      displayMarkers.add(
        Marker(
          markerId: const MarkerId('target_location_pin'),
          position: LatLng(targetLat, targetLng),
          icon: targetPin,
          zIndex: 2.0, // Ensure target pin is on top of other markers if needed
          anchor: const Offset(0.5, 0.4), // Adjust anchor as needed
        ),
      );
    }
    return displayMarkers;
  }

  Set<Marker> _getMarkersForBigMapModal() {
    // For the big map, InfoWindow is usually enough.
    // If you want the image modal here too, use _prepareMapMarkers.
    // Otherwise, a simpler marker creation is fine.
    Set<Marker> markers = _dataEventManager.incidences
        .map((incidence) => createMarkerFromIncidence(incidence)) // Default marker, will show InfoWindow
        .toSet();
        
    final targetLat = _mapLocationManager.targetLatitude;
    final targetLng = _mapLocationManager.targetLongitude;
    final targetPin = _mapLocationManager.targetPinDot;

    if (targetLat != null && targetLng != null && targetPin != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('target_location_pin_big_map'),
          position: LatLng(targetLat, targetLng),
          icon: targetPin,
          infoWindow: const InfoWindow(title: 'Selected Incident Location'),
          zIndex: 2,
          anchor: const Offset(0.5, 0.4),
        ),
      );
    }
    return markers;
  }

  Set<Circle> _getCirclesForDisplay() {
    // Directly use the circles prepared by MarkerManager
    return _dataEventManager.incidentCircles;
  }

  Set<Circle> _getCirclesForBigMapModal() {
    // Directly use the circles prepared by MarkerManager
    return _dataEventManager.incidentCircles;
  }

  Future<void> _handleIncidentButtonPressed(MakerType markerType) async {
    if (!mounted) return;
    // Use the updated processing method in MarkerManager
    await _dataEventManager.processIncidentReporting(
        context: context,
        newMarkerToSelect: markerType,
        targetLatitude: _mapLocationManager.targetLatitude,
        targetLongitude: _mapLocationManager.targetLongitude,
    );
  }

  Future<void> _handleEmergencyButtonPressed() async {
    if (!mounted) return;
      await _dataEventManager.processEmergencyReporting(
        context: context,
        targetLatitude: _mapLocationManager.targetLatitude,
        targetLongitude: _mapLocationManager.targetLongitude,
    );
  }


  @override
  Widget build(BuildContext context) {
    final LatLng? initialMapCenter = _mapLocationManager.initialCameraPosition;

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: SafeArea(
        child: Column(
          children: [
            HomeHeaderWidget(currentUser: _userSessionManager.currentUser),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white, // Background for the scrollable content area
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [ // Optional: add shadow for depth
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                ),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          LocationInfoWidget(locationText: _mapLocationManager.locationText),
                          MapDisplayWidget(
                            key: ValueKey('mapDisplay_${_mapLocationManager.initialCameraPosition?.latitude}_${_mapLocationManager.initialCameraPosition?.longitude}'),
                            initialLatitude: initialMapCenter?.latitude,
                            initialLongitude: initialMapCenter?.longitude,
                            markers: _getDisplayMarkers(), 
                            circles: _getCirclesForDisplay(), // Pass circles to the map
                            selectedMarker: _dataEventManager.selectedIncident,
                            onMapTappedWithMarker: _mapLocationManager.handleMapTapped,
                            onMapLongPressed: (cameraPosition) =>
                                _mapLocationManager.handleMapLongPressed(
                                  context: context,
                                  currentCameraPosition: cameraPosition,
                                  markersForBigMap: _getMarkersForBigMapModal(),
                                  circlesForBigMap: _getCirclesForBigMapModal(),
                                ),
                            onMapCreated: _mapLocationManager.onMapCreated,
                            onResetTargetPressed: () => _mapLocationManager.resetTargetToUserLocation(context),
                            onCameraMove: _mapLocationManager.handleCameraMove,
                          ),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0), // Spacing around incident buttons
                        child: IncidentButtonsGridWidget(
                          selectedIncident: _dataEventManager.selectedIncident,
                          onIncidentButtonPressed: _handleIncidentButtonPressed,
                        ),
                      ),
                    ),
                    SliverFillRemaining( // To push bottom buttons to the actual bottom
                      hasScrollBody: false, // False if content above might not fill the screen
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: BottomActionButtonsWidget(
                          currentServiceName: getCallButtonServiceName(_dataEventManager.selectedIncident),
                          onEmergencyPressed: _handleEmergencyButtonPressed,
                          onPhonePressed: () => _userSessionManager.makePhoneCall(
                            context: context,
                            selectedIncident: _dataEventManager.selectedIncident,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}