// lib/features/places/screens/places_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:harkai/l10n/app_localizations.dart';

// Services
import 'package:harkai/core/services/location_service.dart';
import 'package:harkai/core/services/phone_service.dart';
import 'package:harkai/core/services/payment_service.dart'; // Your new payment service

// Utils & Managers (from home feature, ensure paths are correct)
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/features/home/managers/marker_manager.dart';
import 'package:harkai/features/home/managers/map_location_manager.dart';
import 'package:harkai/features/home/managers/user_session_manager.dart';

// Widgets (from home feature)
import 'package:harkai/features/home/widgets/header.dart';
import 'package:harkai/features/home/widgets/location_info.dart';
import 'package:harkai/features/home/widgets/map.dart';

// Modals (from home feature - to be adapted)
import 'package:harkai/features/home/modals/incident_description.dart';
import 'package:harkai/features/home/modals/incident_image.dart';

// Incident Feed Screen (reused)
import 'package:harkai/features/incident_feed/screens/incident_screen.dart';


class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final PaymentService _paymentService = PaymentService(); // Instance of your payment service

  late final MarkerManager _markerManager;
  late final MapLocationManager _mapLocationManager;
  late final UserSessionManager _userSessionManager;
  GoogleMapController? _mapController;
  AppLocalizations? _localizations;
  User? _currentUser;

  bool _isAddingPlace = false; // To show loading indicator during payment/add process

  @override
  void initState() {
    super.initState();
    // Initialization will occur in didChangeDependencies after localizations are available
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localizations == null) {
      _localizations = AppLocalizations.of(context)!;

      _userSessionManager = UserSessionManager(
        firebaseAuthInstance: _firebaseAuth,
        phoneService: PhoneService(),
        onAuthChangedCallback: (User? user) {
          if (mounted) setState(() => _currentUser = user);
        },
      );

      _mapLocationManager = MapLocationManager(
        locationService: _locationService,
        onStateChange: () {
          if (mounted) setState(() {});
        },
        getMapController: () => _mapController,
        setMapController: (controller) {
          if (mounted && _mapController != controller) {
            _mapController = controller;
          }
        },
      );

      _markerManager = MarkerManager(
        firestoreService: _firestoreService,
        onStateChange: () {
          if (mounted) setState(() {});
        },
      );

      _initializeScreenData();
    }
  }

  Future<void> _initializeScreenData() async {
    if (_localizations == null) return;
    _userSessionManager.initialize();
    await _mapLocationManager.initializeManager(_localizations!);
    await _markerManager.initialize(_localizations!);
    // Any other initial data fetching for places screen specifically can go here
  }

  @override
  void dispose() {
    _userSessionManager.dispose();
    _mapLocationManager.dispose();
    _markerManager.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _getDisplayMarkers() {
    if (_localizations == null) return {};
    Set<Marker> displayMarkers = _markerManager.incidences
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

    final targetLat = _mapLocationManager.targetLatitude;
    final targetLng = _mapLocationManager.targetLongitude;
    final targetPin = _mapLocationManager.targetPinDot;

    if (targetLat != null && targetLng != null && targetPin != null) {
      displayMarkers.add(
        Marker(
          markerId: const MarkerId('target_location_pin_places'), // Unique ID
          position: LatLng(targetLat, targetLng),
          icon: targetPin,
          zIndex: 2.0,
          anchor: const Offset(0.5, 0.4),
        ),
      );
    }
    return displayMarkers;
  }

  Set<Circle> _getCirclesForDisplay() {
    if (_localizations == null) return {};
    return _markerManager.incidences
        .map((incidence) => createCircleFromIncidence(incidence, _localizations!))
        .toSet();
  }

  Future<void> _handleAddPlaceButtonPressed() async {
    if (_localizations == null || _currentUser == null) return;

    final targetLat = _mapLocationManager.targetLatitude;
    final targetLng = _mapLocationManager.targetLongitude;

    if (targetLat == null || targetLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_localizations!.targetLocationNotSet)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isAddingPlace = true);

    // 1. Show payment required message and ask to proceed
    bool proceedToPayment = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_localizations!.addPlaceButtonTitle),
            content: Text(_localizations!.paymentRequiredMessage("\$1.00")), // Hardcoding $1.00 for now
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_localizations!.profileDialogNo), // Reusing "No"
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(_localizations!.profileDialogYes), // Reusing "Yes"
              ),
            ],
          ),
        ) ?? false;

    if (!proceedToPayment) {
      if (mounted) setState(() => _isAddingPlace = false);
      return;
    }
    
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_localizations!.paymentProcessingMessage)),
        );
    }

    // 2. Initiate Payment
    bool paymentSuccess = await _paymentService.initiateAndProcessPayment(
      context: context, // Pass context for messages within payment service
      amount: 1.00,
      currency: "USD",
      userDescription: "Add new place to Harkai: ${_currentUser!.displayName ?? _currentUser!.email}",
    );

    if (!paymentSuccess) {
      if (mounted) {
        setState(() => _isAddingPlace = false);
        // Error message is usually shown by PaymentService itself
      }
      return;
    }
    
    if (!mounted) { // Check mounted again after async payment
      setState(() => _isAddingPlace = false);
      return;
    }
    
    // 3. If payment successful, show the details modal
    // IMPORTANT: You need to adapt showIncidentVoiceDescriptionDialog or create a new one
    // that enforces mandatory photo and collects place-specific details.
    final result = await showIncidentVoiceDescriptionDialog(
      context: context,
      markerType: MakerType.place, // Pass the place type
    );

    if (result != null) {
      final String? description = result['description']; // This might be place name + description
      final String? imageUrl = result['imageUrl'];

      // Ensure photo is provided (adapt modal to enforce this and return it)
      if (imageUrl == null || imageUrl.isEmpty) {
          if (mounted) {
            if (mounted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_localizations!.photoRequiredMessage)),
                );
              }
            }
          }
      } else if (description != null) { // imageUrl will be mandatory
        if (mounted) {
          await _markerManager.addMarkerAndShowNotification(
            context: context, // For localizations and ScaffoldMessenger
            makerType: MakerType.place,
            latitude: targetLat,
            longitude: targetLng,
            description: description, // This should be place name/description
            imageUrl: imageUrl,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_localizations!.paymentSuccessfulMessage)),
          );
        }
      }
    }
    // Reset loading state regardless of modal outcome after successful payment
    if (mounted) setState(() => _isAddingPlace = false);
  }

  void _handlePlacesFeedNavigation() {
    if (_currentUser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncidentScreen(
          incidentType: MakerType.place,
          currentUser: _currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _localizations ??= AppLocalizations.of(context)!; // Ensure localizations
    if (_localizations == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final LatLng? initialMapCenter = _mapLocationManager.initialCameraPosition;

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: SafeArea(
        child: Column(
          children: [
            HomeHeaderWidget(currentUser: _currentUser),
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
                  ],
                ),
                child: Column( // Using Column instead of CustomScrollView for simplicity here
                  children: [
                    LocationInfoWidget(
                        locationText: _mapLocationManager.getLocalizedLocationText(_localizations!)),
                    Expanded( // Map needs to be expanded to take available space
                      child: MapDisplayWidget(
                        key: ValueKey('mapDisplay_places_${initialMapCenter?.latitude}_${initialMapCenter?.longitude}'),
                        initialLatitude: initialMapCenter?.latitude,
                        initialLongitude: initialMapCenter?.longitude,
                        markers: _getDisplayMarkers(),
                        circles: _getCirclesForDisplay(),
                        selectedMarker: MakerType.none, // Not selecting an incident type on this map for highlighting
                        onMapTappedWithMarker: _mapLocationManager.handleMapTapped,
                        onMapCreated: _mapLocationManager.onMapCreated,
                        onResetTargetPressed: () => _mapLocationManager.resetTargetToUserLocation(context),
                        onCameraMove: _mapLocationManager.handleCameraMove,
                        onMapLongPressed: (cameraPosition) =>
                                _mapLocationManager.handleMapLongPressed(
                              context: context,
                              currentCameraPosition: cameraPosition,
                              markersForBigMap: _getDisplayMarkers(), // Can reuse display markers
                              circlesForBigMap: _getCirclesForDisplay(), // Can reuse display circles
                            ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                      child: _isAddingPlace
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Image.asset(
                                  'assets/images/place_icon.png',
                                  width: 24,
                                  height: 24,
                                  color: Colors.white
                                ),
                                label: Text(
                                  _localizations!.addPlaceButtonTitle,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.yellow.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30.0),
                                  ),
                                  elevation: 5.0,
                                ),
                                onPressed: _handleAddPlaceButtonPressed,
                                onLongPress: _handlePlacesFeedNavigation,
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