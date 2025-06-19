import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:harkai/l10n/app_localizations.dart';

class EnlargedMapModal extends StatelessWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final Set<Marker> markers;
  final Set<Circle> circles;
  final double currentZoom;

  const EnlargedMapModal({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.markers,
    required this.circles,
    required this.currentZoom,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // Get AppLocalizations

    if (initialLatitude == null || initialLongitude == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15.0),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(localizations.enlargedMapDataUnavailable), // Localized string
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(15.0),
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(initialLatitude!, initialLongitude!),
              zoom: currentZoom,
            ),
            markers: markers,
            circles: circles,
            mapType: MapType.terrain,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
          Positioned(
            top: 10.0,
            right: 10.0,
            child: Material(
              color: Colors.black.withAlpha((0.6 * 255).toInt()),
              shape: const CircleBorder(),
              elevation: 4.0,
              child: InkWell(
                borderRadius: BorderRadius.circular(20.0),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}