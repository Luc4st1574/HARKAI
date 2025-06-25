import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_maps_webservices/directions.dart' as gm_directions;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:harkai/core/services/location_service.dart'; 
import 'package:geolocator/geolocator.dart'; // For Position object

class IncidentMapViewContent extends StatefulWidget {
  final IncidenceData incident;
  final MakerType incidentTypeForExpiry;

  const IncidentMapViewContent({
    super.key,
    required this.incident,
    required this.incidentTypeForExpiry,
  });

  @override
  State<IncidentMapViewContent> createState() => _IncidentMapViewContentState();
}

class _IncidentMapViewContentState extends State<IncidentMapViewContent> {
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  Set<Polyline> _polylines = {}; // For showing the path
  bool _isIncidentVisible = true;
  Position? _currentUserPosition; // To store user's current location

  AppLocalizations? _localizations;
  bool _dependenciesInitialized = false;
  final LocationService _locationService = LocationService();


  @override
  void initState() {
    super.initState();
    _checkIncidentVisibility();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dependenciesInitialized) {
      _localizations = AppLocalizations.of(context)!;
      if (_isIncidentVisible) {
        _prepareMapElements();
        _fetchCurrentUserLocationAndRoute(); // Fetch location then route
      }
      _dependenciesInitialized = true;
    }
  }

  void _checkIncidentVisibility() {
    // If the incident type is 'place', it should always be visible.
    if (widget.incidentTypeForExpiry == MakerType.place) {
      if (mounted) {
        setState(() {
          _isIncidentVisible = true;
        });
      }
      return; 
    }

    final now = DateTime.now();
    bool shouldBeVisible = true;

    if (widget.incidentTypeForExpiry == MakerType.pet) {
      // **FIXED LOGIC HERE**
      final twentyFourHoursAgo = now.subtract(const Duration(days: 1));
      if (widget.incident.timestamp.toDate().isBefore(twentyFourHoursAgo)) {
        shouldBeVisible = false;
      }
    } else {
      // For other incident types (fire, crash, theft, emergency)
      final threeHoursAgo = now.subtract(const Duration(hours: 3));
      if (widget.incident.timestamp.toDate().isBefore(threeHoursAgo)) {
        shouldBeVisible = false;
      }
    }

    if (mounted && _isIncidentVisible != shouldBeVisible) {
        setState(() {
          _isIncidentVisible = shouldBeVisible;
        });
    }
  }

  void _prepareMapElements() {
    if (_localizations == null) return;
    final marker = createMarkerFromIncidence(widget.incident, _localizations!);
    final circle = createCircleFromIncidence(widget.incident, _localizations!);
    if (mounted) {
      setState(() {
        _markers = {marker};
        _circles = {circle};
      });
    }
  }

  Future<void> _fetchCurrentUserLocationAndRoute() async {
    final locationResult = await _locationService.getInitialPosition();
    if (locationResult.success && locationResult.data != null) {
      if (mounted) {
        setState(() {
          _currentUserPosition = locationResult.data;
        });
        _fetchAndDrawRoute(); // Now fetch route
      }
    } else {
      debugPrint("Could not get user's current location for route: ${locationResult.errorMessage}");
      // Optionally, show a toast or a message if location is crucial for route
    }
  }

  Future<void> _fetchAndDrawRoute() async {
    if (_currentUserPosition == null) {
      debugPrint("User current position is null, cannot fetch route.");
      return;
    }

    final String? apiKey = dotenv.env['MAPS_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("MAPS_KEY not found in .env for Directions API.");
      // Consider showing a user-facing error or logging
      return;
    }

    final gm_directions.GoogleMapsDirections directions = gm_directions.GoogleMapsDirections(apiKey: apiKey);
    final gm_directions.Location origin = gm_directions.Location(lat: _currentUserPosition!.latitude, lng: _currentUserPosition!.longitude);
    final gm_directions.Location destination = gm_directions.Location(lat: widget.incident.latitude, lng: widget.incident.longitude);

    try {
      gm_directions.DirectionsResponse response = await directions.directions(
        origin,
        destination,
        travelMode: gm_directions.TravelMode.driving, // You can change this (walking, bicycling)
      );

      if (response.isOkay && response.routes.isNotEmpty) {
        final gm_directions.Route route = response.routes.first;
        if (route.overviewPolyline.points.isNotEmpty) {
          PolylinePoints polylinePoints = PolylinePoints();
          List<PointLatLng> decodedResult = polylinePoints.decodePolyline(route.overviewPolyline.points);
          
          List<LatLng> polylineCoordinates = [];
          if (decodedResult.isNotEmpty) {
            for (var point in decodedResult) {
              polylineCoordinates.add(LatLng(point.latitude, point.longitude));
            }
          }

          if (polylineCoordinates.isNotEmpty) {
            final Polyline polyline = Polyline(
              polylineId: const PolylineId('routeToIncident'),
              color: Colors.blueAccent.withOpacity(0.8),
              width: 5,
              points: polylineCoordinates,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            );
            if (mounted) {
              setState(() {
                _polylines = {polyline};
              });
            }
          } else {
            debugPrint("Directions API: Decoded polyline has no points.");
          }
        } else {
          debugPrint("Directions API: No overview polyline found in the route.");
        }
      } else {
        debugPrint("Directions API Error: ${response.errorMessage ?? 'Failed to get directions.'}");
      }
    } catch (e) {
      debugPrint("Exception when fetching directions: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    _localizations ??= AppLocalizations.of(context)!;
    if (_localizations == null) {
        return const Center(child: CircularProgressIndicator());
    }

    if (!_isIncidentVisible) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _localizations!.incidentMapViewIncidentExpired,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GoogleMap(
      mapType: MapType.terrain,
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.incident.latitude, widget.incident.longitude),
        zoom: 14, // Adjusted zoom for potentially showing route
      ),
      markers: _markers,
      circles: _circles,
      polylines: _polylines, // Display the route
      myLocationEnabled: true,      // Show user's blue dot
      myLocationButtonEnabled: true, // Show button to center on user
      zoomControlsEnabled: true,
    );
  }
}