import 'package:flutter/material.dart';
import '../../home/utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Ensure this import is correct

/// A widget that displays a grid of incident buttons.
class IncidentButtonsGridWidget extends StatelessWidget {
  final MakerType selectedIncident;
  final Function(MakerType) onIncidentButtonPressed;
  final Function(MakerType) onIncidentButtonLongPressed;

  const IncidentButtonsGridWidget({
    super.key,
    required this.selectedIncident,
    required this.onIncidentButtonPressed,
    required this.onIncidentButtonLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    final List<MakerType> markerTypesForGrid = [
      MakerType.fire,
      MakerType.crash,
      MakerType.theft,
      MakerType.pet,
    ];

    const double gridSpacing = 12.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _IndividualIncidentButton(
                  markerType: markerTypesForGrid[0], // Fire
                  isSelected: selectedIncident == markerTypesForGrid[0],
                  onPressed: () => onIncidentButtonPressed(markerTypesForGrid[0]),
                  onLongPressed: () => onIncidentButtonLongPressed(markerTypesForGrid[0]),
                ),
              ),
              const SizedBox(width: gridSpacing),
              Expanded(
                child: _IndividualIncidentButton(
                  markerType: markerTypesForGrid[1], // Crash
                  isSelected: selectedIncident == markerTypesForGrid[1],
                  onPressed: () => onIncidentButtonPressed(markerTypesForGrid[1]),
                  onLongPressed: () => onIncidentButtonLongPressed(markerTypesForGrid[1]),
                ),
              ),
            ],
          ),
          const SizedBox(height: gridSpacing),
          Row(
            children: [
              Expanded(
                child: _IndividualIncidentButton(
                  markerType: markerTypesForGrid[2], // Theft
                  isSelected: selectedIncident == markerTypesForGrid[2],
                  onPressed: () => onIncidentButtonPressed(markerTypesForGrid[2]),
                  onLongPressed: () => onIncidentButtonLongPressed(markerTypesForGrid[2]),
                ),
              ),
              const SizedBox(width: gridSpacing),
              Expanded(
                child: _IndividualIncidentButton(
                  markerType: markerTypesForGrid[3], // Pet
                  isSelected: selectedIncident == markerTypesForGrid[3],
                  onPressed: () => onIncidentButtonPressed(markerTypesForGrid[3]),
                  onLongPressed: () => onIncidentButtonLongPressed(markerTypesForGrid[3]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndividualIncidentButton extends StatelessWidget {
  final MakerType markerType;
  final bool isSelected;
  final VoidCallback onPressed;
  final VoidCallback? onLongPressed; // Make this nullable or required

  const _IndividualIncidentButton({
    required this.markerType,
    required this.isSelected,
    required this.onPressed,
    this.onLongPressed, // Add to constructor
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final MarkerInfo? markerDetails = getMarkerInfo(markerType, localizations);
    String title = markerDetails?.title ?? 'Error';

    final Color buttonColor = markerDetails?.color ?? Colors.grey.shade700;
    final String iconPath = markerDetails?.iconPath ?? 'assets/images/alert.png';
    final AssetImage iconAsset = AssetImage(iconPath);
    const double iconSize = 20.0;
    const double fontSize = 13.0;
    const FontWeight fontWeight = FontWeight.bold;
    const double buttonElevation = 5.0;
    const EdgeInsets buttonPadding = EdgeInsets.symmetric(vertical: 14, horizontal: 10);

    return ElevatedButton(
      onPressed: onPressed,
      onLongPress: onLongPressed, // Add this
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
            color: Colors.white,
            errorBuilder: (context, error, stackTrace) {
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