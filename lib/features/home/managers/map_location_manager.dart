import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/services/location_service.dart';
import '../modals/enlarged_map.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart' as perm_handler; // Added import

typedef AlwaysOnLocationPromptCallback = Future<bool> Function(BuildContext context, AppLocalizations localizations); // NEW

class MapLocationManager {
  final LocationService _locationService;
  final VoidCallback _onStateChange;
  final GoogleMapController? Function() _getMapController;
  final Function(GoogleMapController) _setMapController;
  final AlwaysOnLocationPromptCallback? onShowAlwaysOnLocationPrompt; // Made optional

  // --- FIX: Change the initial state to be a unique loading key ---
  // This ensures the very first time the UI builds, it shows a loading message.
  static const String _initialStateKey = 'harkai_initial_loading';
  String _locationData = _initialStateKey;
  bool _isErrorOrStatus = true; // The initial state is a "status"

  double? _latitude;
  double? _longitude;
  double? _targetLatitude;
  double? _targetLongitude;

  // For dynamic address updates
  double? _lastGeocodedLatitude;
  double? _lastGeocodedLongitude;
  // Threshold in meters to trigger a new address lookup
  static const double _addressUpdateDistanceThreshold = 500.0; // 500 meters
  static const double maxMarkerMoveDistance = 300.0;

  StreamSubscription<geolocator.Position>? _positionStreamSubscription;
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
    this.onShowAlwaysOnLocationPrompt, // Made optional
  })  : _locationService = locationService,
        _onStateChange = onStateChange,
        _getMapController = getMapController,
        _setMapController = setMapController;

  // --- FIX: Update this method to handle the new initial state ---
  String getLocalizedLocationText(AppLocalizations localizations) {
    // If we are in the initial loading state, always show the "getting initial location" message.
    if (_locationData == _initialStateKey) {
      return localizations.mapinitialFetchingLocation;
    }

    if (_isErrorOrStatus) {
      switch (_locationData) {
        case 'loading': 
          return localizations.mapLoadingLocation;
        case 'fetching':
          return localizations.mapFetchingLocation;
        default:
          if (_locationData == localizations.mapinitialFetchingLocation) return localizations.mapinitialFetchingLocation;
          if (_locationData == localizations.mapCouldNotFetchAddress) return localizations.mapCouldNotFetchAddress;
          if (_locationData == localizations.mapFailedToGetInitialLocation) return localizations.mapFailedToGetInitialLocation;
          if (_locationData == localizations.mapLocationServicesDisabled) return localizations.mapLocationServicesDisabled;
          if (_locationData == localizations.mapLocationPermissionDenied) return localizations.mapLocationPermissionDenied;
          
          if (_locationData.startsWith("Error:") || _locationData.startsWith("Failed:")) {
            return _locationData; 
          }
          return localizations.mapCouldNotFetchAddress;
      }
    }
    return localizations.mapYouAreIn(_locationData.isNotEmpty ? _locationData : localizations.mapCouldNotFetchAddress);
  }

  Future<void> initializeManager(BuildContext context, AppLocalizations localizations) async {
    await _loadCustomTargetIcon();
    
    // 1. Request foreground permission
    bool foregroundPermissionGranted = await _locationService.requestForegroundLocationPermission(openSettingsOnError: true);
    if (!foregroundPermissionGranted) {
      _locationData = localizations.mapLocationPermissionDenied;
      _isErrorOrStatus = true;
      _onStateChange();
      debugPrint("MapLocationManager: Foreground location permission denied. Cannot proceed with map.");
      return; // Cannot proceed without foreground location
    }

    // 2. If foreground is granted, check background status and prompt if needed
    var backgroundStatus = await perm_handler.Permission.locationAlways.status;
    if (backgroundStatus != perm_handler.PermissionStatus.granted && 
        backgroundStatus != perm_handler.PermissionStatus.permanentlyDenied) {
      debugPrint("MapLocationManager: Background location not yet granted. Showing explanation modal.");
      // ADDED NULL CHECK HERE
      if (onShowAlwaysOnLocationPrompt != null) { 
        bool userAcceptedExplanation = await onShowAlwaysOnLocationPrompt!(context, localizations); 
      
        if (userAcceptedExplanation) {
          debugPrint("MapLocationManager: User accepted explanation. Requesting background location permission.");
          await _locationService.requestBackgroundLocationPermission(openSettingsOnError: true);
        } else {
          debugPrint("MapLocationManager: User declined explanation modal. Proceeding without always-on permission.");
        }
      } else {
        debugPrint("MapLocationManager: No always-on location prompt callback provided. Skipping explanation.");
      }
    } else {
      debugPrint("MapLocationManager: Background location already granted or permanently denied. Skipping explanation modal.");
    }

    // 3. Fetch initial location and address (now that permissions are handled)
    await _fetchInitialLocationAndAddress(localizations); 
    
    // 4. Setup continuous location updates
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
    if (!isUpdate) {
      _locationData = localizations.mapinitialFetchingLocation;
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
          _locationData = addressResult.data!;
          _isErrorOrStatus = false;
          _lastGeocodedLatitude = _latitude;
          _lastGeocodedLongitude = _longitude;
        } else {
          _locationData = localizations.mapCouldNotFetchAddress;
          _isErrorOrStatus = true;
          debugPrint("getAddressFromCoordinates failed initially: ${addressResult.errorMessage}");
        }
        _animateMapToTarget(zoom: 16.0);
      } else {
        _locationData = initialPosResult.errorMessage ?? localizations.mapFailedToGetInitialLocation;
        _isErrorOrStatus = true;
        debugPrint("getInitialPosition failed: ${initialPosResult.errorMessage}");
      }
      _onStateChange();
      return; 
    }

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
    _onStateChange();
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
    bool permGranted = await _locationService.requestForegroundLocationPermission(); // Changed to Foreground
    if (!permGranted) {
      _locationData = localizations.mapLocationPermissionDenied;
      _isErrorOrStatus = true;
      _latitude = null; _longitude = null;
      _onStateChange();
      return;
    }

    _positionStreamSubscription?.cancel(); 
    _positionStreamSubscription =
        _locationService.getPositionStream().listen((geolocator.Position position) async { 
      _latitude = position.latitude;
      _longitude = position.longitude;

      bool shouldUpdateAddress = false;
      if (_lastGeocodedLatitude == null || _lastGeocodedLongitude == null) {
        shouldUpdateAddress = true; 
      } else {
        double distanceMoved = geolocator.Geolocator.distanceBetween(
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
    if (_targetLatitude != null && _targetLongitude != null) {
        _animateMapToTarget(zoom: 16.0);
    } else if (_latitude != null && _longitude != null) {
        final currentMapController = _getMapController();
        currentMapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(_latitude!, _longitude!), 16.0),
        );
    }
  }

  void handleMapTapped(LatLng position, BuildContext context, {bool isDistanceCheckEnabled = true}) {
    if (isDistanceCheckEnabled && _latitude != null && _longitude != null) {
      final distance = geolocator.Geolocator.distanceBetween(
        _latitude!,
        _longitude!,
        position.latitude,
        position.longitude,
      );

      if (distance > maxMarkerMoveDistance) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.mapMarkerTooFar),
          ),
        );
        return;
      }
    }

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
      await _fetchInitialLocationAndAddress(localizations, isUpdate: true); 
      _animateMapToTarget(zoom: 16.0);
    } else {
      if (ScaffoldMessenger.of(context).mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.mapCurrentUserLocationNotAvailable)),
        );
      }
      await _fetchInitialLocationAndAddress(localizations); 
    }
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
    debugPrint("MapLocationManager disposed and position stream cancelled.");
  }
}