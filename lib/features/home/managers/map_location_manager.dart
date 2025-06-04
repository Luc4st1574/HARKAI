import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position, Geolocator;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/services/location_service.dart';
import '../modals/enlarged_map.dart';
import 'package:harkai/l10n/app_localizations.dart';

class MapLocationManager {
  final LocationService _locationService;
  final VoidCallback _onStateChange;
  final GoogleMapController? Function() _getMapController;
  final Function(GoogleMapController) _setMapController;

  String _locationData = '';
  bool _isErrorOrStatus = false;

  double? _latitude;
  double? _longitude;
  double? _targetLatitude;
  double? _targetLongitude;

  // For dynamic address updates
  double? _lastGeocodedLatitude;
  double? _lastGeocodedLongitude;
  // Threshold in meters to trigger a new address lookup
  static const double _addressUpdateDistanceThreshold = 500.0; // 500 meters

  StreamSubscription<Position>? _positionStreamSubscription;
  BitmapDescriptor? _targetPinDot;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get targetLatitude => _targetLatitude;
  double? get targetLongitude => _targetLongitude;
  BitmapDescriptor? get targetPinDot => _targetPinDot;
  LatLng? get initialCameraPosition => _targetLatitude != null && _targetLongitude != null
      ? LatLng(_targetLatitude!, _targetLongitude!)
      : (_latitude != null && _longitude != null ? LatLng(_latitude!, _longitude!) : null);

  String? get currentCityName {
    if (!_isErrorOrStatus && _locationData.isNotEmpty) {
      return _locationData.split(',').first.trim();
    }
    return null;
  }
  
  MapLocationManager({
    required LocationService locationService,
    required VoidCallback onStateChange,
    required GoogleMapController? Function() getMapController,
    required Function(GoogleMapController) setMapController,
  })  : _locationService = locationService,
        _onStateChange = onStateChange,
        _getMapController = getMapController,
        _setMapController = setMapController;

  String getLocalizedLocationText(AppLocalizations localizations) {
    if (_isErrorOrStatus) {
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
        default:
          if (_locationData.startsWith("Error:") || _locationData.startsWith("Failed:")) {
            return _locationData; 
          }
          return localizations.mapCouldNotFetchAddress;
      }
    }
    return localizations.mapYouAreIn(_locationData.isNotEmpty ? _locationData : localizations.mapCouldNotFetchAddress);
  }

  Future<void> initializeManager(AppLocalizations localizations) async {
    await _loadCustomTargetIcon();
    await _locationService.requestLocationPermission(openSettingsOnError: true);
    await _fetchInitialLocationAndAddress(localizations); // This will also set initial _lastGeocodedLatitude/Longitude
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

  Future<void> _fetchInitialLocationAndAddress(AppLocalizations localizations, {bool isUpdate = false}) async {
    if (!isUpdate) { // Only show "fetching" on initial load, not on background updates
        _locationData = localizations.mapFetchingLocation; // Use key directly for getLocalizedLocationText
        _isErrorOrStatus = true;
        _onStateChange();
    }

    final initialPosResult = await _locationService.getInitialPosition(); // Gets current position

    if (initialPosResult.success && initialPosResult.data != null) {
      _latitude = initialPosResult.data!.latitude;
      _longitude = initialPosResult.data!.longitude;
      if (!isUpdate) { // Only set target on initial load, not on background address updates
          _targetLatitude = _latitude;
          _targetLongitude = _longitude;
      }

      final addressResult = await _locationService.getAddressFromCoordinates(_latitude!, _longitude!);
      if (addressResult.success && addressResult.data != null) {
        _locationData = addressResult.data!;
        _isErrorOrStatus = false;
        // Store the location for which we successfully got an address
        _lastGeocodedLatitude = _latitude;
        _lastGeocodedLongitude = _longitude;
      } else {
        // If fetching address fails, keep the old valid address if this is an update,
        // or set error if initial fetch.
        if (!isUpdate) {
            _locationData = localizations.mapCouldNotFetchAddress;
            _isErrorOrStatus = true;
        }
        debugPrint("getAddressFromCoordinates failed: ${addressResult.errorMessage}");
      }
      if (!isUpdate) _animateMapToTarget(zoom: 16.0);
    } else {
      if (!isUpdate) {
        _locationData = initialPosResult.errorMessage ?? localizations.mapFailedToGetInitialLocation;
        _isErrorOrStatus = true;
      }
      debugPrint("getInitialPosition failed: ${initialPosResult.errorMessage}");
    }
    _onStateChange(); // Update UI with new address or status
  }

  void _setupLocationUpdatesListener(AppLocalizations localizations) async {
    bool serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationData = localizations.mapLocationServicesDisabled;
      _isErrorOrStatus = true;
      _latitude = null; _longitude = null;
      _onStateChange();
      return;
    }
    bool permGranted = await _locationService.requestLocationPermission();
    if (!permGranted) {
      _locationData = localizations.mapLocationPermissionDenied;
      _isErrorOrStatus = true;
      _latitude = null; _longitude = null;
      _onStateChange();
      return;
    }

    _positionStreamSubscription?.cancel(); // Cancel any existing subscription
    _positionStreamSubscription =
        _locationService.getPositionStream().listen((Position position) async { // Mark as async
      _latitude = position.latitude;
      _longitude = position.longitude;

      bool shouldUpdateAddress = false;
      if (_lastGeocodedLatitude == null || _lastGeocodedLongitude == null) {
        shouldUpdateAddress = true; // No address fetched yet or last attempt failed
      } else {
        double distanceMoved = Geolocator.distanceBetween(
          _lastGeocodedLatitude!,
          _lastGeocodedLongitude!,
          position.latitude,
          position.longitude,
        );
        if (distanceMoved > _addressUpdateDistanceThreshold) {
          shouldUpdateAddress = true;
        }
      }

      if (shouldUpdateAddress) {
        debugPrint("MapLocationManager: User moved significantly. Re-fetching address...");
        // Fetch new address. Pass isUpdate=true to avoid resetting target or showing "Fetching..."
        await _fetchInitialLocationAndAddress(localizations, isUpdate: true);
      } else {
        // If address isn't updated, still call _onStateChange to reflect lat/lng changes if any other part of UI uses them directly.
        _onStateChange();
      }

    }, onError: (error) {
      _latitude = null; _longitude = null;
      debugPrint("Error in location stream: $error");
      _onStateChange(); // Still update UI to reflect potential error state if needed
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
    _onStateChange();
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

  Future<void> resetTargetToUserLocation(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    if (_latitude != null && _longitude != null) {
      _targetLatitude = _latitude;
      _targetLongitude = _longitude;
      // Re-fetch address for the current user location and update display
      await _fetchInitialLocationAndAddress(localizations, isUpdate: true); // Pass isUpdate to prevent full reset
      _animateMapToTarget(zoom: 16.0); // Also animate map to this location
    } else {
      if (ScaffoldMessenger.of(context).mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.mapCurrentUserLocationNotAvailable)),
        );
      }
       // Attempt to fetch initial location again if current lat/lng are null
      await _fetchInitialLocationAndAddress(localizations);
    }
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
    debugPrint("MapLocationManager disposed and position stream cancelled.");
  }
}