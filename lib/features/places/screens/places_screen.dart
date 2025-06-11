// lib/features/places/screens/places_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:pay/pay.dart';

// Services
import 'package:harkai/core/services/location_service.dart';
import 'package:harkai/core/services/phone_service.dart';

// Utils & Managers (from home feature)
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/features/home/managers/marker_manager.dart';
import 'package:harkai/features/home/managers/map_location_manager.dart';
import 'package:harkai/features/home/managers/user_session_manager.dart';

// Widgets (from home feature)
import 'package:harkai/features/home/widgets/header.dart';
import 'package:harkai/features/home/widgets/map.dart';

// Modals & Screens
import 'package:harkai/features/home/modals/incident_description.dart';
import 'package:harkai/features/home/modals/incident_image.dart';
import 'package:harkai/features/home/screens/home.dart';
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

  late final MarkerManager _markerManager;
  late final MapLocationManager _mapLocationManager;
  late final UserSessionManager _userSessionManager;
  GoogleMapController? _mapController;
  AppLocalizations? _localizations;
  User? _currentUser;

  bool _isAddingPlace = false;

  // *** UPDATED: Future to hold the payment configuration loaded from assets ***
  late final Future<PaymentConfiguration> _googlePayConfigFuture;

  @override
  void initState() {
    super.initState();
    // *** UPDATED: Initialize the configuration from the asset file ***
    _googlePayConfigFuture =
        PaymentConfiguration.fromAsset('google_pay.json');
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
        .where((incidence) =>
            incidence.type == MakerType.place) // Only show place markers
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

    final targetLat = _mapLocationManager.targetLatitude;
    final targetLng = _mapLocationManager.targetLongitude;
    final targetPin = _mapLocationManager.targetPinDot;
    if (targetLat != null && targetLng != null && targetPin != null) {
      displayMarkers.add(
        Marker(
          markerId: const MarkerId('target_location_pin_places'),
          position: LatLng(targetLat, targetLng),
          icon: targetPin,
          anchor: const Offset(0.5, 0.4),
        ),
      );
    }
    return displayMarkers;
  }

  Set<Circle> _getCirclesForDisplay() {
    if (_localizations == null) return {};
    return _markerManager.incidences
        .where((incidence) =>
            incidence.type == MakerType.place) // Only show circles for places
        .map((incidence) => createCircleFromIncidence(incidence, _localizations!))
        .toSet();
  }

  // *** UPDATED: This function now uses the FutureBuilder for the configuration ***
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

    final paymentItems = [
      PaymentItem(
        label: _localizations!.addplaceTitle,
        amount: '8.00',
        status: PaymentItemStatus.final_price,
      )
    ];

    // Show the payment dialog
    final paymentResult = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F3F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(color: Colors.yellow.shade700, width: 2),
        ),
        title: Text(
          _localizations!.paymentRequiredMessage('8.00'),
          style: TextStyle(
            color: Colors.yellow.shade700,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _localizations!.addplaceInfo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 25),
            FutureBuilder<PaymentConfiguration>(
              future: _googlePayConfigFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData) {
                    // *** MODIFIED: Wrapped button in a SizedBox for width control ***
                    return SizedBox(
                      width: double.infinity, // Makes the button wider
                      child: GooglePayButton(
                        paymentConfiguration: snapshot.data!,
                        paymentItems: paymentItems,
                        // *** MODIFIED: Changed type for a simpler look ***
                        type: GooglePayButtonType.plain,
                        theme: GooglePayButtonTheme.light,
                        onPaymentResult: (Map<String, dynamic> result) {
                          Navigator.pop(context, true);
                        },
                        loadingIndicator:
                            const Center(child: CircularProgressIndicator()),
                        onError: (error) {
                          debugPrint("Google Pay Error: $error");
                          Navigator.pop(context, false);
                        },
                      ),
                    );
                  } else {
                    return const Text("Error loading payment configuration.");
                  }
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.yellow.shade700),
            ),
          )
        ],
      ),
    );

    if (paymentResult == true) {
      // Payment was successful
      if (!mounted) {
        setState(() => _isAddingPlace = false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_localizations!.paymentSuccessfulMessage)),
      );
      // Now, proceed to the incident description dialog
      final result = await showIncidentVoiceDescriptionDialog(
        context: context,
        markerType: MakerType.place,
      );

      if (result != null) {
        final String? description = result['description'];
        final String? imageUrl = result['imageUrl'];

        if (imageUrl == null || imageUrl.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_localizations!.photoRequiredMessage)),
            );
          }
        } else if (description != null) {
          if (mounted) {
            await _markerManager.addMarkerAndShowNotification(
              context: context,
              makerType: MakerType.place,
              latitude: targetLat,
              longitude: targetLng,
              description: description,
              imageUrl: imageUrl,
            );
          }
        }
      }
    } else {
      // Payment failed or was cancelled
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_localizations!.paymentFailedMessage)),
        );
      }
    }

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
            HomeHeaderWidget(
              currentUser: _currentUser,
              onLogoTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const Home()),
                    (Route<dynamic> route) => false);
              },
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
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16.0),
                    Expanded(
                      child: MapDisplayWidget(
                        key: ValueKey(
                            'mapDisplay_places_${initialMapCenter?.latitude}_${initialMapCenter?.longitude}'),
                        initialLatitude: initialMapCenter?.latitude,
                        initialLongitude: initialMapCenter?.longitude,
                        markers: _getDisplayMarkers(),
                        circles: _getCirclesForDisplay(),
                        selectedMarker: MakerType.none,
                        onMapTappedWithMarker: (LatLng position) {
                          _mapLocationManager.handleMapTapped(position, context, isDistanceCheckEnabled: false);
                        },
                        onMapCreated: _mapLocationManager.onMapCreated,
                        onResetTargetPressed: () =>
                            _mapLocationManager.resetTargetToUserLocation(context),
                        onCameraMove: _mapLocationManager.handleCameraMove,
                        onMapLongPressed: (cameraPosition) =>
                            _mapLocationManager.handleMapLongPressed(
                          context: context,
                          currentCameraPosition: cameraPosition,
                          markersForBigMap: _getDisplayMarkers(),
                          circlesForBigMap: _getCirclesForDisplay(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 20.0),
                      child: _isAddingPlace
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Image.asset(
                                  'assets/images/place_icon.png',
                                  width: 24,
                                  height: 24,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  _localizations!.buttonAddPlace,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.yellow.shade700,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
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