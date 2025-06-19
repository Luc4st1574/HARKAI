import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../onboarding/screens/onboarding_tutorial.dart';

// Services
import '../../../core/services/location_service.dart';
import '../../../core/services/phone_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/services/notification_service.dart';

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
import 'package:harkai/features/incident_feed/screens/incident_screen.dart';

// Managers
import '../managers/marker_manager.dart';
import '../managers/map_location_manager.dart';
import '../managers/user_session_manager.dart';

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
  final SpeechPermissionService _speechPermissionService =
      SpeechPermissionService();
  final NotificationService _notificationService =
      NotificationService(); // Instantiate the new service

  late final MarkerManager _dataEventManager;
  late final MapLocationManager _mapLocationManager;
  late final UserSessionManager _userSessionManager;

  GoogleMapController? _mapController;
  AppLocalizations? _localizations;

  bool _isScrollViewLocked = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localizations == null) {
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
      );

      _dataEventManager = MarkerManager(
        firestoreService: _firestoreService,
        onStateChange: () {
          if (mounted) setState(() {});
        },
      );

      // This now handles the full startup sequence including onboarding
      _initializeAndCheckOnboarding();
    }
  }

  // New wrapper function to control the startup flow
  Future<void> _initializeAndCheckOnboarding() async {
    // Initialize services that don't show pop-ups first
    await _initializeScreenData();
    // Then check for onboarding, which will handle permission requests
    await _checkFirstLaunch();
  }

  // Updated to only initialize non-UI blocking services
  Future<void> _initializeScreenData() async {
    if (_localizations == null) return;
    _userSessionManager.initialize();
    await _dataEventManager.initialize(_localizations!);
  }

  // New function to request permissions
  Future<void> _requestInitialPermissions() async {
    if (_localizations == null) return;
    // This will now fetch location and request permission
    await _mapLocationManager.initializeManager(_localizations!);
    // Request speech permissions
    bool speechReady = await _speechPermissionService
        .ensurePermissionsAndInitializeService(openSettingsOnError: true);
    // Request notification permissions
    await _notificationService.requestNotificationPermission(openSettingsOnError: true);
    debugPrint("Home: Speech service ready after onboarding: $speechReady");
  }


  // Updated to correctly sequence permissions after onboarding
  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch) {
      if (mounted) {
        // Show the tutorial and wait for it to be dismissed
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const OnboardingTutorial(),
        );
        // Once the tutorial is done, save the preference and request permissions
        await prefs.setBool('is_first_launch', false);
        await _requestInitialPermissions();
      }
    } else {
      // If it's not the first launch, request permissions right away
      await _requestInitialPermissions();
    }
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
                  builder: (_) =>
                      IncidentImageDisplayModal(incidence: tappedIncidence),
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
          infoWindow: InfoWindow(title: _localizations!.targetLocationNotSet),
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

  void _handleIncidentButtonLongPressed(MakerType markerType) {
    if (!mounted ||_userSessionManager.currentUser == null ||_localizations == null) {
      return;
    }

    debugPrint("Button long pressed: ${markerType.name}. Navigating to IncidentScreen.");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncidentScreen(
          incidentType: markerType,
          currentUser: _userSessionManager.currentUser,
        ),
      ),
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

    final String? currentCity = _mapLocationManager.currentCityName;
    final LatLng? initialMapCenter = _mapLocationManager.initialCameraPosition;

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: SafeArea(
        child: Column(
          children: [
            HomeHeaderWidget(
              currentUser: _userSessionManager.currentUser,
              isLongPressEnabled: true,
            ),
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
                  physics: _isScrollViewLocked
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          LocationInfoWidget(
                              locationText: _mapLocationManager
                                  .getLocalizedLocationText(_localizations!)),
                          MapDisplayWidget(
                            key: ValueKey(
                                'mapDisplay_${_mapLocationManager.initialCameraPosition?.latitude}_${_mapLocationManager.initialCameraPosition?.longitude}'),
                            initialLatitude: initialMapCenter?.latitude,
                            initialLongitude: initialMapCenter?.longitude,
                            markers: _getDisplayMarkers(),
                            circles: _getCirclesForDisplay(),
                            selectedMarker: _dataEventManager.selectedIncident,
                            onMapTappedWithMarker: (LatLng position) {
                              _unlockScrollView();
                              _mapLocationManager.handleMapTapped(
                                  position, context, isDistanceCheckEnabled: true);
                            },
                            onMapLongPressed: (cameraPosition) {
                              _unlockScrollView();
                              _mapLocationManager.handleMapLongPressed(
                                context: context,
                                currentCameraPosition: cameraPosition,
                                markersForBigMap: _getMarkersForBigMapModal(),
                                circlesForBigMap: _getCirclesForBigMapModal(),
                              );
                            },
                            onMapCreated: _mapLocationManager.onMapCreated,
                            onResetTargetPressed: () {
                              _unlockScrollView();
                              _mapLocationManager
                                  .resetTargetToUserLocation(context);
                            },
                            onCameraMove: _mapLocationManager.handleCameraMove,
                            onMapInteractionStart: _lockScrollView,
                            onMapInteractionEnd: _unlockScrollView,
                          ),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: IncidentButtonsGridWidget(
                          selectedIncident: _dataEventManager.selectedIncident,
                          onIncidentButtonPressed: (MakerType type) {
                            _unlockScrollView();
                            _handleIncidentButtonPressed(type);
                          },
                          onIncidentButtonLongPressed: (MakerType type) {
                            _unlockScrollView();
                            _handleIncidentButtonLongPressed(type);
                          },
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: BottomActionButtonsWidget(
                          currentServiceName: getCallButtonServiceName(
                              _dataEventManager.selectedIncident,
                              _localizations!),
                          onEmergencyPressed: () {
                            _unlockScrollView();
                            _handleEmergencyButtonPressed();
                          },
                          onLongPressEmergency: () {
                            _unlockScrollView();
                            _handleIncidentButtonLongPressed(
                                MakerType.emergency);
                          },
                          onPhonePressed: () {
                            _unlockScrollView();
                            if (!mounted || _localizations == null) return;
                            _userSessionManager.makePhoneCall(
                              context: context,
                              localizations: _localizations!,
                              selectedIncident:
                                  _dataEventManager.selectedIncident,
                              cityName: currentCity,
                              firestoreService: _firestoreService,
                            );
                          },
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

  void _lockScrollView() {
    if (mounted && !_isScrollViewLocked) {
      setState(() {
        _isScrollViewLocked = true;
      });
      debugPrint("Home Screen: ScrollView LOCKED for map interaction.");
    }
  }

  void _unlockScrollView() {
    if (mounted && _isScrollViewLocked) {
      setState(() {
        _isScrollViewLocked = false;
      });
      debugPrint("Home Screen: ScrollView UNLOCKED.");
    }
  }
}