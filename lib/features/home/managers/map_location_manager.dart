import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show Circle;
import '../../../core/services/location_service.dart';
import '../modals/enlarged_map.dart';

class MapLocationManager { // Renamed from HomeMapLocationManager
  final LocationService _locationService;
  final VoidCallback _onStateChange;
  final GoogleMapController? Function() _getMapController;
  final Function(GoogleMapController) _setMapController;

  String _locationText = 'Loading location...';
  double? _latitude;
  double? _longitude;
  double? _targetLatitude;
  double? _targetLongitude;

  StreamSubscription<Position>? _positionStreamSubscription;
  BitmapDescriptor? _targetPinDot;

  String get locationText => _locationText;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get targetLatitude => _targetLatitude;
  double? get targetLongitude => _targetLongitude;
  BitmapDescriptor? get targetPinDot => _targetPinDot;
  LatLng? get initialCameraPosition => _targetLatitude != null && _targetLongitude != null? LatLng(_targetLatitude!, _targetLongitude!)
                                    : (_latitude != null && _longitude != null? 
                                    LatLng(_latitude!, _longitude!): null);

  MapLocationManager({
    required LocationService locationService,
    required VoidCallback onStateChange,
    required GoogleMapController? Function() getMapController,
    required Function(GoogleMapController) setMapController,
  })  : _locationService = locationService,
        _onStateChange = onStateChange,
        _getMapController = getMapController,
        _setMapController = setMapController;

  Future<void> initializeManager() async {
    await _loadCustomTargetIcon();
    await _locationService.requestLocationPermission(openSettingsOnError: true);
    await _fetchInitialLocationAndAddress();
    _setupLocationUpdatesListener();
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

  Future<void> _fetchInitialLocationAndAddress() async {
    _locationText = 'Fetching location...';
    _onStateChange();

    final initialPosResult = await _locationService.getInitialPosition();

    if (initialPosResult.success && initialPosResult.data != null) {
      _latitude = initialPosResult.data!.latitude;
      _longitude = initialPosResult.data!.longitude;
      _targetLatitude = _latitude;
      _targetLongitude = _longitude;

      final addressResult = await _locationService.getAddressFromCoordinates(_latitude!, _longitude!);
      _locationText = addressResult.success
          ? 'You are in ${addressResult.data!}'
          : addressResult.errorMessage ?? 'Could not fetch address';
      
      _animateMapToTarget(zoom: 16.0);
    } else {
      _locationText = initialPosResult.errorMessage ?? 'Failed to get initial location';
    }
    _onStateChange();
  }

  void _setupLocationUpdatesListener() async {
    bool serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
        _locationText = 'Location services are disabled.';
        _latitude = null; _longitude = null;
        _onStateChange(); return;
    }
    bool permGranted = await _locationService.requestLocationPermission();
      if (!permGranted) {
        _locationText = 'Location permission denied.';
        _latitude = null; _longitude = null;
        _onStateChange(); return;
    }

    _positionStreamSubscription =
        _locationService.getPositionStream().listen((Position position) {
      _latitude = position.latitude;
      _longitude = position.longitude;
      _onStateChange();
    }, onError: (error) {
      _latitude = null; _longitude = null;
      _locationText = 'Error fetching location: $error';
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
    required Set<Circle> circlesForBigMap, // New parameter
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
              circles: circlesForBigMap, // New: Pass circles
              currentZoom: currentCameraPosition.zoom,
            ),
          ),
        );
      },
    );
  }

  Future<void> resetTargetToUserLocation(BuildContext context) async {
    if (_latitude != null && _longitude != null) {
      _targetLatitude = _latitude;
      _targetLongitude = _longitude;
      _onStateChange();
      _animateMapToTarget(zoom: 16.0);
    } else {
      if (ScaffoldMessenger.of(context).mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Current user location not available.')),
          );
      }
    }
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}