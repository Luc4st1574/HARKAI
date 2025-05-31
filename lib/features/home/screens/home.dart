import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Services
import '../../../core/services/location_service.dart';
import '../../../core/services/phone_service.dart';

// Utils (Models and Map Utilities)
import '../utils/incidences.dart';
import '../utils/markers.dart';

// Widgets for this screen
import '../widgets/header.dart';
import '../widgets/location_info.dart';
import '../widgets/map.dart';
import '../widgets/incident_buttons.dart';
import '../widgets/bottom_butons.dart';

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
  final FirestoreService _firestoreService = FirestoreService();
  final PhoneService _phoneService = PhoneService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Managers (Instances of the renamed classes)
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
      firestoreService: _firestoreService,
      onStateChange: () { if (mounted) setState(() {}); },
    );

    _initializeScreenData();
  }

  Future<void> _initializeScreenData() async {
    _userSessionManager.initialize();
    await _mapLocationManager.initializeManager();
    await _dataEventManager.initialize();
  }

  @override
  void dispose() {
    _userSessionManager.dispose();
    _mapLocationManager.dispose();
    _dataEventManager.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _getDisplayMarkers() {
    Set<Marker> displayMarkers = Set.from(_dataEventManager.incidentMarkers);
    final targetLat = _mapLocationManager.targetLatitude;
    final targetLng = _mapLocationManager.targetLongitude;
    final targetPin = _mapLocationManager.targetPinDot;

    if (targetLat != null && targetLng != null && targetPin != null) {
      displayMarkers.add(
        Marker(
          markerId: const MarkerId('target_location_pin'),
          position: LatLng(targetLat, targetLng),
          icon: targetPin,
          zIndex: 2.0,
          infoWindow: const InfoWindow(title: 'Place marker here'),
          anchor: const Offset(0.5, 0.4),
        ),
      );
    }
    return displayMarkers;
  }

  Set<Marker> _getMarkersForBigMapModal() {
    Set<Marker> markers = Set.from(_dataEventManager.incidentMarkers);
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

  Set<Circle> _getCirclesForBigMapModal() {
    // We only want circles for actual incidents, not the temporary target pin.
    return _dataEventManager.incidentCircles;
  }

  Future<void> _handleIncidentButtonPressed(MakerType markerType) async {
    if (!mounted) return;

    final String? description = await _dataEventManager.handleMarkerSelectionAndGetDescription(
      context: context,
      newMarkerToSelect: markerType,
      targetLatitude: _mapLocationManager.targetLatitude,
      targetLongitude: _mapLocationManager.targetLongitude,
    );

    if (!mounted) return;

    if (_dataEventManager.selectedIncident != MakerType.none && description != null) {
      if (_mapLocationManager.targetLatitude != null && _mapLocationManager.targetLongitude != null) {
        await _dataEventManager.addMarkerAndShowNotification(
          context: context,
          makerType: _dataEventManager.selectedIncident,
          latitude: _mapLocationManager.targetLatitude!,
          longitude: _mapLocationManager.targetLongitude!,
          description: description,
        );
      }
    }
  }

  Future<void> _handleEmergencyButtonPressed() async {
    if (!mounted) return;

    final String? description = await _dataEventManager.handleEmergencyAndGetDescription(
        context: context,
        targetLatitude: _mapLocationManager.targetLatitude,
        targetLongitude: _mapLocationManager.targetLongitude,
    );

    if (!mounted) return;

    if (description != null && _mapLocationManager.targetLatitude != null && _mapLocationManager.targetLongitude != null) {
        await _dataEventManager.addMarkerAndShowNotification(
            context: context,
            makerType: MakerType.emergency,
            latitude: _mapLocationManager.targetLatitude!,
            longitude: _mapLocationManager.targetLongitude!,
            description: description,
        );
      if (mounted) {
        _dataEventManager.setActiveMaker(MakerType.emergency);
      }
    } else if (description == null && _mapLocationManager.targetLatitude != null && _mapLocationManager.targetLongitude != null) {
        debugPrint("Emergency marker not added as description dialog was cancelled.");
    }
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          LocationInfoWidget(locationText: _mapLocationManager.locationText),
                          MapDisplayWidget(
                            key: ValueKey('mapDisplay_${_mapLocationManager.targetLatitude}_${_mapLocationManager.targetLongitude}'),
                            initialLatitude: initialMapCenter?.latitude,
                            initialLongitude: initialMapCenter?.longitude,
                            markers: _getDisplayMarkers(),
                            circles: _dataEventManager.incidentCircles, // New: Pass circles
                            selectedMarker: _dataEventManager.selectedIncident,
                            onMapTappedWithMarker: _mapLocationManager.handleMapTapped,
                            onMapLongPressed: (cameraPosition) =>
                                _mapLocationManager.handleMapLongPressed(
                                  context: context,
                                  currentCameraPosition: cameraPosition,
                                  markersForBigMap: _getMarkersForBigMapModal(),
                                  circlesForBigMap: _getCirclesForBigMapModal(), // New: Pass circles for big map
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
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: IncidentButtonsGridWidget(
                          selectedIncident: _dataEventManager.selectedIncident,
                          onIncidentButtonPressed: _handleIncidentButtonPressed,
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
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