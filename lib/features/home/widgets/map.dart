// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import

/// A widget that displays the Google Map with markers and user interaction.
class MapDisplayWidget extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final Set<Marker> markers;
  final Set<Circle> circles; // New: Add circles property
  final MakerType selectedMarker;
  final Function(LatLng) onMapTappedWithMarker;
  final Function(GoogleMapController)? onMapCreated;
  final Function(CameraPosition)? onMapLongPressed;
  final VoidCallback? onResetTargetPressed;
  final Function(CameraPosition)? onCameraMove;

  const MapDisplayWidget({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.markers,
    required this.circles, // New: Require circles in constructor
    required this.selectedMarker,
    required this.onMapTappedWithMarker,
    this.onMapCreated,
    this.onMapLongPressed,
    this.onResetTargetPressed,
    this.onCameraMove,
  });

  @override
  State<MapDisplayWidget> createState() => _MapDisplayWidgetState();
}

class _MapDisplayWidgetState extends State<MapDisplayWidget> {
  GoogleMapController? _localMapController;
  CameraPosition? _currentCameraPosition;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _currentCameraPosition = CameraPosition(
        target: LatLng(widget.initialLatitude!, widget.initialLongitude!),
        zoom: 16.0,
      );
    }
  }

  @override
  void didUpdateWidget(MapDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.initialLatitude != oldWidget.initialLatitude ||
            widget.initialLongitude != oldWidget.initialLongitude) &&
        widget.initialLatitude != null && widget.initialLongitude != null) {
      
      final newTarget = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      if (_localMapController != null) {
        _localMapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newTarget, _currentCameraPosition?.zoom ?? 16.0),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Get AppLocalizations instance
    final localizations = AppLocalizations.of(context)!;
    final double screenHeight = MediaQuery.of(context).size.height;
    const double mapHeightFactor = 0.40;

    if (widget.initialLatitude == null || widget.initialLongitude == null) {
      return SizedBox(
        height: screenHeight * mapHeightFactor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              Text(localizations.homeMapLoadingText), // Changed to use localization key
            ],
          ),
        ),
      );
    }

    // Camera position will be primarily controlled by home.dart via onMapCreated and key changes
    final CameraPosition cameraPosForMap = _currentCameraPosition ?? CameraPosition(
            target: LatLng(widget.initialLatitude!, widget.initialLongitude!),
            zoom: 16.0,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.2 * 255).toInt()),
              spreadRadius: 3,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.0),
          child: SizedBox(
            height: screenHeight * mapHeightFactor,
            width: double.infinity,
            child: Stack(
              children: [
                GoogleMap(
                  key: widget.key, // Ensure key is passed for state preservation if needed
                  initialCameraPosition: cameraPosForMap,
                  markers: widget.markers,
                  circles: widget.circles, // New: Pass circles to GoogleMap
                  mapType: MapType.terrain,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomGesturesEnabled: true,
                  zoomControlsEnabled: true,
                  scrollGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    _localMapController = controller;
                    debugPrint('GoogleMap created successfully in MapDisplayWidget.');
                    widget.onMapCreated?.call(controller);
                    if (_currentCameraPosition != null && _localMapController != null) {
                      _localMapController!.animateCamera(
                        CameraUpdate.newCameraPosition(_currentCameraPosition!),
                      );
                    } else if (widget.initialLatitude != null && widget.initialLongitude != null) {
                      _localMapController!.animateCamera(
                        CameraUpdate.newCameraPosition(CameraPosition(
                          target: LatLng(widget.initialLatitude!, widget.initialLongitude!),
                          zoom: 16.0,
                        )),
                      );
                    } else {
                      debugPrint("Error: Cannot animate camera as initial coordinates are also null.");
                    }
                  },
                  onCameraMove: (CameraPosition position) {
                    _currentCameraPosition = position; 
                    widget.onCameraMove?.call(position);
                  },
                  onCameraIdle: () {
                    // Can be used if needed
                  },
                  onTap: (LatLng position) {
                    widget.onMapTappedWithMarker(position);
                  },
                  onLongPress: (LatLng latLng) {
                    if (widget.onMapLongPressed != null) {
                      if (_currentCameraPosition != null) {
                        widget.onMapLongPressed!(_currentCameraPosition!);
                      } else if (widget.initialLatitude != null && widget.initialLongitude != null){
                        debugPrint("Warning: _currentCameraPosition was null during onLongPress. Using initial widget values for target.");
                        widget.onMapLongPressed!(CameraPosition(
                          target: LatLng(widget.initialLatitude!, widget.initialLongitude!),
                          zoom: 16.0,
                        ));
                      } else {
                          debugPrint("Error: Cannot determine camera position for long press as initial/target coordinates are also null.");
                      }
                    }
                  },
                ),
                if (widget.onResetTargetPressed != null)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 10.0,
                    child: Material(
                      color: Colors.transparent,
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'resetTargetFAB_mainMap', // Ensure unique heroTag
                        onPressed: widget.onResetTargetPressed,
                        backgroundColor: Colors.white.withAlpha((0.85 * 255).round()),
                        elevation: 4.0,
                        child: const Icon(Icons.explore_outlined, color: Color(0xFF001F3F)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}