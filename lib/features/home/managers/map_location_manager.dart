import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/services/location_service.dart';
import '../modals/enlarged_map.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added

class MapLocationManager {
  final LocationService _locationService;
  final VoidCallback _onStateChange;
  final GoogleMapController? Function() _getMapController;
  final Function(GoogleMapController) _setMapController;

  // _locationText will now store raw data (like "City, Country") or a status/error key
  String _locationData = ''; // Stores actual location string or a key for status
  bool _isErrorOrStatus = false; // Flag to know if _locationData is a key or actual data

  double? _latitude;
  double? _longitude;
  double? _targetLatitude;
  double? _targetLongitude;

  StreamSubscription<Position>? _positionStreamSubscription;
  BitmapDescriptor? _targetPinDot;

  // String get locationText => _locationText; // Deprecated, use getLocalizedLocationText

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get targetLatitude => _targetLatitude;
  double? get targetLongitude => _targetLongitude;
  BitmapDescriptor? get targetPinDot => _targetPinDot;
  LatLng? get initialCameraPosition => _targetLatitude != null && _targetLongitude != null
      ? LatLng(_targetLatitude!, _targetLongitude!)
      : (_latitude != null && _longitude != null ? LatLng(_latitude!, _longitude!) : null);

  MapLocationManager({
    required LocationService locationService,
    required VoidCallback onStateChange,
    required GoogleMapController? Function() getMapController,
    required Function(GoogleMapController) setMapController,
    // Removed AppLocalizations from constructor, it will be passed to methods or obtained from context
  })  : _locationService = locationService,
        _onStateChange = onStateChange,
        _getMapController = getMapController,
        _setMapController = setMapController;

  // New method to get the localized display text
  String getLocalizedLocationText(AppLocalizations localizations) {
    if (_isErrorOrStatus) {
      // _locationData holds a key
      switch (_locationData) {
        case 'loading':
          return localizations.mapLoadingLocation;
        case 'fetching':
          return localizations.mapFetchingLocation;
        case 'services_disabled':
          return localizations.mapLocationServicesDisabled;
        case 'permission_denied':
          return localizations.mapLocationPermissionDenied;
        case 'failed_initial':
          return localizations.mapFailedToGetInitialLocation;
        case 'could_not_fetch_address':
          return localizations.mapCouldNotFetchAddress;
        // Add more cases for specific error messages if _locationData stores error details
        default:
          // If _locationData contains a formatted error message from a service
          if (_locationData.startsWith("Error:") || _locationData.startsWith("Failed:")) {
             // return localizations.mapErrorFetchingLocation(_locationData); // If you have a generic error key
             return _locationData; // Or just return the raw error if it's already descriptive
          }
          return localizations.mapCouldNotFetchAddress; // Generic fallback
      }
    }
    // _locationData holds "City, Country"
    return localizations.mapYouAreIn(_locationData.isNotEmpty ? _locationData : localizations.mapCouldNotFetchAddress);
  }


  Future<void> initializeManager(AppLocalizations localizations) async {
    await _loadCustomTargetIcon();
    await _locationService.requestLocationPermission(openSettingsOnError: true);
    await _fetchInitialLocationAndAddress(localizations);
    _setupLocationUpdatesListener(localizations);
  }

  Future<void> _loadCustomTargetIcon() async {
    try {
      _targetPinDot = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(15, 15)),
        'assets/images/tap_position_marker.png',
      );
    } catch (e) {
      debugPrint('Error loading custom target icon: $e');
      _targetPinDot = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
    _onStateChange();
  }

  Future<void> _fetchInitialLocationAndAddress(AppLocalizations localizations) async {
    _locationData = 'fetching'; // Key for "Fetching location..."
    _isErrorOrStatus = true;
    _onStateChange();

    final initialPosResult = await _locationService.getInitialPosition();

    if (initialPosResult.success && initialPosResult.data != null) {
      _latitude = initialPosResult.data!.latitude;
      _longitude = initialPosResult.data!.longitude;
      _targetLatitude = _latitude;
      _targetLongitude = _longitude;

      final addressResult = await _locationService.getAddressFromCoordinates(_latitude!, _longitude!);
      if (addressResult.success && addressResult.data != null) {
        _locationData = addressResult.data!; // Store "City, Country"
        _isErrorOrStatus = false;
      } else {
        _locationData = 'could_not_fetch_address'; // Key for error
        _isErrorOrStatus = true;
        debugPrint(addressResult.errorMessage);
      }
      _animateMapToTarget(zoom: 16.0);
    } else {
      _locationData = initialPosResult.errorMessage ?? 'failed_initial'; // Store error or key
      _isErrorOrStatus = true;
      debugPrint(initialPosResult.errorMessage);
    }
    _onStateChange();
  }

  void _setupLocationUpdatesListener(AppLocalizations localizations) async {
    bool serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationData = 'services_disabled'; // Key
      _isErrorOrStatus = true;
      _latitude = null; _longitude = null;
      _onStateChange();
      return;
    }
    bool permGranted = await _locationService.requestLocationPermission();
    if (!permGranted) {
      _locationData = 'permission_denied'; // Key
      _isErrorOrStatus = true;
      _latitude = null; _longitude = null;
      _onStateChange();
      return;
    }

    _positionStreamSubscription =
        _locationService.getPositionStream().listen((Position position) {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _onStateChange();
    }, onError: (error) {
      _latitude = null; _longitude = null;
      _locationData = localizations.mapErrorFetchingLocation(error.toString()); // Use localized string with param
      _isErrorOrStatus = true;
      _onStateChange();
    });
  }

  void _animateMapToTarget({double zoom = 16.0}) {
    if (_targetLatitude != null && _targetLongitude != null) {
      final currentMapController = _getMapController();
      currentMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_targetLatitude!, _targetLongitude!), zoom),
      );
    }
  }

  void onMapCreated(GoogleMapController controller) {
    _setMapController(controller);
    _animateMapToTarget(zoom: 16.0);
  }

  void handleMapTapped(LatLng position) {
    _targetLatitude = position.latitude;
    _targetLongitude = position.longitude;
    _onStateChange(); // This will trigger a rebuild, and getLocalizedLocationText will be called
    _animateMapToTarget();
  }

  void handleCameraMove(CameraPosition position) {
    debugPrint("Camera moved to: Target: ${position.target}, Zoom: ${position.zoom}");
  }

  Future<void> handleMapLongPressed({
    required BuildContext context,
    required CameraPosition currentCameraPosition,
    required Set<Marker> markersForBigMap,
    required Set<Circle> circlesForBigMap,
  }) async {
    // ... (implementation remains the same)
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          child: SizedBox(
            width: screenWidth * 0.85,
            height: screenHeight * 0.65,
            child: EnlargedMapModal(
              initialLatitude: currentCameraPosition.target.latitude,
              initialLongitude: currentCameraPosition.target.longitude,
              markers: markersForBigMap,
              circles: circlesForBigMap, 
              currentZoom: currentCameraPosition.zoom,
            ),
          ),
        );
      },
    );
  }

  Future<void> resetTargetToUserLocation(BuildContext context) async { // No longer takes AppLocalizations here
    final localizations = AppLocalizations.of(context)!; // Get localizations from context

    if (_latitude != null && _longitude != null) {
      _targetLatitude = _latitude;
      _targetLongitude = _longitude;
      // If _fetchInitialLocationAndAddress is called, it will update _locationData
      // For simplicity, if you just want to recenter and potentially re-fetch address:
      await _fetchInitialLocationAndAddress(localizations); // This will update _locationData and call _onStateChange
      // _onStateChange(); // Already called by _fetchInitialLocationAndAddress
      _animateMapToTarget(zoom: 16.0);
    } else {
      if (ScaffoldMessenger.of(context).mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.mapCurrentUserLocationNotAvailable)), // Localized
        );
      }
    }
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}