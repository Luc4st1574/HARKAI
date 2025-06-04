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
        case 'loading': // This case might not be used with the new logic if mapinitialFetchingLocation is used directly
          return localizations.mapLoadingLocation;
        case 'fetching': // This case might not be used with the new logic
          return localizations.mapFetchingLocation;
        // Directly compare with localized strings if they are used as keys for _locationData
        default:
          if (_locationData == localizations.mapinitialFetchingLocation) return localizations.mapinitialFetchingLocation;
          if (_locationData == localizations.mapCouldNotFetchAddress) return localizations.mapCouldNotFetchAddress;
          if (_locationData == localizations.mapFailedToGetInitialLocation) return localizations.mapFailedToGetInitialLocation;
          if (_locationData == localizations.mapLocationServicesDisabled) return localizations.mapLocationServicesDisabled;
          if (_locationData == localizations.mapLocationPermissionDenied) return localizations.mapLocationPermissionDenied;
          
          // Fallback for other error messages that might be directly set
          if (_locationData.startsWith("Error:") || _locationData.startsWith("Failed:")) {
            return _locationData; 
          }
          return localizations.mapCouldNotFetchAddress; // Generic fallback error
      }
    }
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

  // MODIFIED METHOD
  Future<void> _fetchInitialLocationAndAddress(AppLocalizations localizations, {bool isUpdate = false}) async {
    if (!isUpdate) {
      // Display "Initial location fetching..." message first
      _locationData = localizations.mapinitialFetchingLocation;
      _isErrorOrStatus = true;
      _onStateChange();

      final initialPosResult = await _locationService.getInitialPosition();

      if (initialPosResult.success && initialPosResult.data != null) {
        _latitude = initialPosResult.data!.latitude;
        _longitude = initialPosResult.data!.longitude;
        // Set target only on initial successful position fetch
        _targetLatitude = _latitude;
        _targetLongitude = _longitude;

        // Now, attempt to get the address
        final addressResult = await _locationService.getAddressFromCoordinates(_latitude!, _longitude!);
        if (addressResult.success && addressResult.data != null) {
          _locationData = addressResult.data!;
          _isErrorOrStatus = false;
          _lastGeocodedLatitude = _latitude;
          _lastGeocodedLongitude = _longitude;
        } else {
          // Position was successful, but address fetching failed
          _locationData = localizations.mapCouldNotFetchAddress;
          _isErrorOrStatus = true;
          debugPrint("getAddressFromCoordinates failed initially: ${addressResult.errorMessage}");
        }
        _animateMapToTarget(zoom: 16.0);
      } else {
        // Initial position fetching failed
        _locationData = initialPosResult.errorMessage ?? localizations.mapFailedToGetInitialLocation;
        _isErrorOrStatus = true;
        debugPrint("getInitialPosition failed: ${initialPosResult.errorMessage}");
      }
      // Update UI with the final state of the initial fetch
      _onStateChange();
      return; // Exit after initial fetch logic
    }

    // --- Logic for isUpdate = true (background updates) ---
    if (_latitude != null && _longitude != null) {
      final addressResult = await _locationService.getAddressFromCoordinates(_latitude!, _longitude!);
      if (addressResult.success && addressResult.data != null) {
        _locationData = addressResult.data!;
        _isErrorOrStatus = false;
        _lastGeocodedLatitude = _latitude;
        _lastGeocodedLongitude = _longitude;
      } else {
        debugPrint("getAddressFromCoordinates failed during background update: ${addressResult.errorMessage}");
      }
    } else {
      debugPrint("MapLocationManager: _fetchInitialLocationAndAddress called with isUpdate=true but lat/lng are null.");
    }
    _onStateChange(); // Update UI with new address or status from background update
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

    _positionStreamSubscription?.cancel(); 
    _positionStreamSubscription =
        _locationService.getPositionStream().listen((Position position) async { 
      _latitude = position.latitude;
      _longitude = position.longitude;

      bool shouldUpdateAddress = false;
      if (_lastGeocodedLatitude == null || _lastGeocodedLongitude == null) {
        shouldUpdateAddress = true; 
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
        await _fetchInitialLocationAndAddress(localizations, isUpdate: true);
      } else {
        _onStateChange();
      }

    }, onError: (error) {
      _latitude = null; _longitude = null;
      debugPrint("Error in location stream: $error");
      // Decide if/how to update _locationData or _isErrorOrStatus on stream error
      // For now, just updating state which might clear lat/lng
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
    // Animate to initial target after map is created, if available
    if (_targetLatitude != null && _targetLongitude != null) {
        _animateMapToTarget(zoom: 16.0);
    } else if (_latitude != null && _longitude != null) {
        // Fallback to current location if target isn't set yet
        final currentMapController = _getMapController();
        currentMapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(_latitude!, _longitude!), 16.0),
        );
    }
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
      // Re-fetch address for the current user location, treating it as an update.
      await _fetchInitialLocationAndAddress(localizations, isUpdate: true); 
      _animateMapToTarget(zoom: 16.0);
    } else {
      if (ScaffoldMessenger.of(context).mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.mapCurrentUserLocationNotAvailable)),
        );
      }
      // Attempt to fetch initial location again if current lat/lng are null
      await _fetchInitialLocationAndAddress(localizations); // This will be an initial fetch
    }
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
    debugPrint("MapLocationManager disposed and position stream cancelled.");
  }
}