import 'package:flutter/material.dart';
import '../utils/markers.dart'; 

/// A widget that displays a grid of incident buttons.
class IncidentButtonsGridWidget extends StatelessWidget {
  final MakerType selectedIncident;
  final Function(MakerType) onIncidentButtonPressed;

  const IncidentButtonsGridWidget({
    super.key,
    required this.selectedIncident,
    required this.onIncidentButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final List<MakerType> markerTypesForGrid = [
      MakerType.fire,
      MakerType.crash,
      MakerType.theft,
      MakerType.dog,
    ];

    // Spacing for the grid
    const double gridSpacing = 12.0;

    return Padding(
      // Padding around the entire grid.
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First row of incident buttons.
          Row(
            children: [
              Expanded(
                child: _IndividualIncidentButton(
                  markerType: markerTypesForGrid[0], // Fire
                  isSelected: selectedIncident == markerTypesForGrid[0],
                  onPressed: () => onIncidentButtonPressed(markerTypesForGrid[0]),
                ),
              ),
              const SizedBox(width: gridSpacing), // Spacing between buttons in a row.
              Expanded(
                child: _IndividualIncidentButton(
                  markerType: markerTypesForGrid[1], // Crash
                  isSelected: selectedIncident == markerTypesForGrid[1],
                  onPressed: () => onIncidentButtonPressed(markerTypesForGrid[1]),
                ),
              ),
            ],
          ),
          const SizedBox(height: gridSpacing),
          Row(
            children: [
              Expanded(
                child: _IndividualIncidentButton(
                  markerType: markerTypesForGrid[2],
                  isSelected: selectedIncident == markerTypesForGrid[2],
                  onPressed: () => onIncidentButtonPressed(markerTypesForGrid[2]),
                ),
              ),
              const SizedBox(width: gridSpacing),
              Expanded(
                child: _IndividualIncidentButton(
                  markerType: markerTypesForGrid[3],
                  isSelected: selectedIncident == markerTypesForGrid[3],
                  onPressed: () => onIncidentButtonPressed(markerTypesForGrid[3]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// --- Individual Incident Button (Private to this file) ---
class _IndividualIncidentButton extends StatelessWidget {
  final MakerType markerType;
  final bool isSelected;
  final VoidCallback onPressed;

  const _IndividualIncidentButton({
    required this.markerType,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final MarkerInfo? markerDetails = getMarkerInfo(markerType);

    final String title = markerDetails?.title ?? 'Marker ${markerType.name}';
    final Color buttonColor = markerDetails?.color ?? Colors.grey.shade700;
    final String iconPath = markerDetails?.iconPath ?? 'assets/images/alert.png';
    final AssetImage iconAsset = AssetImage(iconPath);
    const double iconSize = 20.0;
    const double fontSize = 13.0;
    const FontWeight fontWeight = FontWeight.bold;
    const double buttonElevation = 5.0; // Consistent elevation for shadow
    const EdgeInsets buttonPadding = EdgeInsets.symmetric(vertical: 14, horizontal: 10);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: buttonPadding,
        elevation: isSelected ? buttonElevation + 2 : buttonElevation,
        side: isSelected
            ? const BorderSide(color: Colors.white, width: 2.0)
            : BorderSide.none,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image(
            image: iconAsset,
            height: iconSize,
            width: iconSize,
            color: Colors.white, // Assuming icons are tintable or primarily white
            errorBuilder: (context, error, stackTrace) {
              // Fallback if the image asset fails to load
              return Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: iconSize);
            },
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}