import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:harkai/l10n/app_localizations.dart';

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
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();
  final PhoneService _phoneService = PhoneService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final SpeechPermissionService _speechPermissionService = SpeechPermissionService();

  late final MarkerManager _dataEventManager;
  late final MapLocationManager _mapLocationManager;
  late final UserSessionManager _userSessionManager;
  GoogleMapController? _mapController;
  AppLocalizations? _localizations;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localizations = AppLocalizations.of(context)!;

    _userSessionManager = UserSessionManager(
      firebaseAuthInstance: _firebaseAuth,
      phoneService: _phoneService,
      onAuthChangedCallback: (User? user) {
        if (mounted) setState(() {});
      },
    );

    _mapLocationManager = MapLocationManager(
      locationService: _locationService,
      onStateChange: () {
        if (mounted) setState(() {});
      },
      getMapController: () => _mapController,
      setMapController: (controller) {
        if (mounted) {
          if (_mapController != controller) {
            _mapController = controller;
          }
        }
      },
      // Removed localizations: _localizations! from constructor
    );

    _dataEventManager = MarkerManager(
      firestoreService: _firestoreService,
      onStateChange: () {
        if (mounted) setState(() {});
      },
    );

    _initializeScreenData();
  }

  Future<void> _initializeScreenData() async {
    if (_localizations == null) return; // Should not happen if called after didChangeDependencies

    _userSessionManager.initialize();
    await _mapLocationManager.initializeManager(_localizations!); // Pass localizations here
    await _dataEventManager.initialize(_localizations!);
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

  Set<Marker> _prepareMapMarkers() {
    if (_localizations == null) return {};
    return _dataEventManager.incidences
        .map((incidence) => createMarkerFromIncidence(
              incidence,
              _localizations!,
              onImageMarkerTapped: (tappedIncidence) {
                showDialog(
                  context: context,
                  builder: (_) => IncidentImageDisplayModal(incidence: tappedIncidence),
                );
              },
            ))
        .toSet();
  }

  Set<Marker> _getDisplayMarkers() {
    Set<Marker> displayMarkers = _prepareMapMarkers();
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
          anchor: const Offset(0.5, 0.4),
        ),
      );
    }
    return displayMarkers;
  }

  Set<Marker> _getMarkersForBigMapModal() {
    if (_localizations == null) return {};
    Set<Marker> markers = _dataEventManager.incidences
        .map((incidence) => createMarkerFromIncidence(incidence, _localizations!))
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
          // Example of localizing InfoWindow title for the target pin in the big map
          infoWindow: InfoWindow(title: _localizations!.targetLocationNotSet), // You'll need to add this key
          zIndex: 2,
          anchor: const Offset(0.5, 0.4),
        ),
      );
    }
    return markers;
  }

  Set<Circle> _getCirclesForDisplay() {
    if (_localizations == null) return {};
    return _dataEventManager.incidences
        .map((incidence) => createCircleFromIncidence(incidence, _localizations!))
        .toSet();
  }

  Set<Circle> _getCirclesForBigMapModal() {
    if (_localizations == null) return {};
    return _dataEventManager.incidences
        .map((incidence) => createCircleFromIncidence(incidence, _localizations!))
        .toSet();
  }

  Future<void> _handleIncidentButtonPressed(MakerType markerType) async {
    if (!mounted || _localizations == null) return;
    await _dataEventManager.processIncidentReporting(
      context: context,
      localizations: _localizations!,
      newMarkerToSelect: markerType,
      targetLatitude: _mapLocationManager.targetLatitude,
      targetLongitude: _mapLocationManager.targetLongitude,
    );
  }

  Future<void> _handleEmergencyButtonPressed() async {
    if (!mounted || _localizations == null) return;
    await _dataEventManager.processEmergencyReporting(
      context: context,
      localizations: _localizations!,
      targetLatitude: _mapLocationManager.targetLatitude,
      targetLongitude: _mapLocationManager.targetLongitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    _localizations ??= AppLocalizations.of(context)!;
    if (_localizations == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.1 * 255).toInt()),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // CORRECTED: Call the new method on MapLocationManager
                          LocationInfoWidget(locationText: _mapLocationManager.getLocalizedLocationText(_localizations!)),
                          MapDisplayWidget(
                            key: ValueKey('mapDisplay_${_mapLocationManager.initialCameraPosition?.latitude}_${_mapLocationManager.initialCameraPosition?.longitude}'),
                            initialLatitude: initialMapCenter?.latitude,
                            initialLongitude: initialMapCenter?.longitude,
                            markers: _getDisplayMarkers(),
                            circles: _getCirclesForDisplay(),
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
                            // CORRECTED: Call resetTargetToUserLocation with only context
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
                          currentServiceName: getCallButtonServiceName(_dataEventManager.selectedIncident, _localizations!),
                          onEmergencyPressed: _handleEmergencyButtonPressed,
                          onPhonePressed: () => _userSessionManager.makePhoneCall(
                            context: context,
                            localizations: _localizations!,
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