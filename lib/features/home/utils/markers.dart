import 'package:google_maps_flutter/google_maps_flutter.dart' show BitmapDescriptor;
import 'package:flutter/material.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import

/// Enum representing the different types of alerts the user can create or see.
enum MakerType {
  fire,
  crash,
  theft,
  pet,
  emergency, 
  place,
  none,
}

/// Class holding display information and emergency contact details for each alert type.
class MarkerInfo {
  final String title; // This will now hold the localized title
  final String emergencyNumber;
  final String agent; // This will now hold the localized agent name
  final Color? color;
  final String? iconPath;

  /// Constructor for AlertInfo.
  MarkerInfo({
    required this.title,
    required this.emergencyNumber,
    required this.agent,
    this.color,
    this.iconPath,
  });
}

// Changed: markerInfoMap is now a function that returns a localized map
Map<MakerType, MarkerInfo> getLocalizedMarkerInfoMap(AppLocalizations localizations) {
  return {
    MakerType.fire: MarkerInfo(
      title: localizations.homeFireAlertButtonTitle, // Localized
      emergencyNumber: '(044) 226495',
      agent: localizations.agentFirefighters, // Localized
      color: Colors.orange,
      iconPath: 'assets/images/fire.png',
    ),
    MakerType.crash: MarkerInfo(
      title: localizations.homeCrashAlertButtonTitle, // Localized
      emergencyNumber: '(044) 484242',
      agent: localizations.agentSerenazgo, // Localized
      color: Colors.blue,
      iconPath: 'assets/images/car.png',
    ),
    MakerType.theft: MarkerInfo(
      title: localizations.homeTheftAlertButtonTitle, // Localized
      emergencyNumber: '(044) 250664',
      agent: localizations.agentPolice, // Localized
      color: Colors.purple,
      iconPath: 'assets/images/theft.png',
    ),
    MakerType.pet: MarkerInfo(
      title: localizations.homePetAlertButtonTitle, // Localized
      emergencyNumber: '913684363',
      agent: localizations.agentShelter, // Localized
      color: Colors.green,
      iconPath: 'assets/images/dog.png',
    ),
    MakerType.emergency: MarkerInfo(
      title: localizations.homeCallEmergenciesButton, // Using a general "Emergencies" title, or create a specific one
      emergencyNumber: '911',
      agent: localizations.agentEmergencies, // Localized
      color: Colors.red.shade900,
      iconPath: 'assets/images/alert.png'
    ),
    MakerType.place: MarkerInfo(
      title: localizations.addPlaceButtonTitle, // Or a more generic "Place"
      emergencyNumber: '', // Not applicable for places
      agent: localizations.placeMarkerName, // e.g., "Place" or "Business"
      color: Colors.yellow.shade700, // A nice yellow
      iconPath: 'assets/images/place_icon.png',
    ),
  };
}

/// Utility function to safely get [MarkerInfo] using AppLocalizations.
/// Requires context or AppLocalizations instance to be passed where it's called.
MarkerInfo? getMarkerInfo(MakerType type, AppLocalizations localizations) {
  if (type == MakerType.none) return null;
  return getLocalizedMarkerInfoMap(localizations)[type];
}

/// Utility functions related to map display and operations.

double getMarkerHue(MakerType type) {
  switch (type) {
    case MakerType.fire:
      return BitmapDescriptor.hueOrange;
    case MakerType.crash:
      return BitmapDescriptor.hueAzure;
    case MakerType.theft:
      return BitmapDescriptor.hueViolet;
    case MakerType.pet:
      return BitmapDescriptor.hueGreen;
    case MakerType.emergency:
      return BitmapDescriptor.hueRed; // Emergency is red
    case MakerType.place:
      return BitmapDescriptor.hueYellow;
    case MakerType.none: // Default or unknown type
      return BitmapDescriptor.hueRed;
  }
}

/// Gets the localized service name for the call button based on the selected alert.
/// Requires AppLocalizations instance.
String getCallButtonEmergencyNumber(MakerType selectedAlert, AppLocalizations localizations) {
  final MarkerInfo? alertInfo;
  if (selectedAlert == MakerType.none || selectedAlert == MakerType.emergency) {
    alertInfo = getMarkerInfo(MakerType.emergency, localizations);
  } else {
    alertInfo = getMarkerInfo(selectedAlert, localizations);
  }
  return alertInfo?.emergencyNumber ?? '911'; // Default to 911 if no specific number
}

// getCallButtonServiceName remains mostly the same, it's for the button label.
String getCallButtonServiceName(MakerType selectedAlert, AppLocalizations localizations) {
  final MarkerInfo? alertInfo;
  if (selectedAlert == MakerType.none) {
    alertInfo = getMarkerInfo(MakerType.emergency, localizations);
    return localizations.homeCallAgentButton(alertInfo?.agent ?? localizations.agentEmergencies);
  }

  alertInfo = getMarkerInfo(selectedAlert, localizations);
  return localizations.homeCallAgentButton(alertInfo?.agent ?? localizations.agentEmergencies);
}