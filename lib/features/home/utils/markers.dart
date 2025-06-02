import 'package:google_maps_flutter/google_maps_flutter.dart' show BitmapDescriptor;
import 'package:flutter/material.dart';

/// Enum representing the different types of alerts the user can create or see.
enum MakerType {
  fire,
  crash,
  theft,
  pet,
  emergency, 
  none,
}

/// Class holding display information and emergency contact details for each alert type.
class MarkerInfo {
  final String title;
  final String emergencyNumber;
  final String agent;
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

// Global map to easily access AlertInfo for a given AlertType.
final Map<MakerType, MarkerInfo> markerInfoMap = {
  MakerType.fire: MarkerInfo(
    title: 'Fire Alert',
    emergencyNumber: '(044) 226495',
    agent: 'Firefighters',
    color: Colors.orange,
    iconPath: 'assets/images/fire.png',
  ),
  MakerType.crash: MarkerInfo(
    title: 'Crash Alert',
    emergencyNumber: '(044) 484242',
    agent: 'Serenazgo',
    color: Colors.blue,
    iconPath: 'assets/images/car.png',
  ),
  MakerType.theft: MarkerInfo(
    title: 'Theft Alert',
    emergencyNumber: '(044) 250664',
    agent: 'Police',
    color: Colors.purple,
    iconPath: 'assets/images/theft.png',
  ),
  MakerType.pet: MarkerInfo(
    title: 'Pet Alert',
    emergencyNumber: '913684363',
    agent: 'Shelter',
    color: Colors.green,
    iconPath: 'assets/images/dog.png',
  ),
  MakerType.emergency: MarkerInfo(
    title: 'Emergency',
    emergencyNumber: '911',
    agent: 'Emergencies',
    color: Colors.red.shade900,
    iconPath: 'assets/images/alert.png'
  ),
};

/// Utility function to safely get [MarkerInfo] from the [markerInfoMap].
MarkerInfo? getMarkerInfo(MakerType type) {
  if (type == MakerType.none) return null;
  return markerInfoMap[type];
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
    case MakerType.none: // Default or unknown type
      return BitmapDescriptor.hueRed;
  }
}

/// Gets the service name for the call button based on the selected alert.
String getCallButtonServiceName(MakerType selectedAlert) {
  if (selectedAlert == MakerType.none) {
    final emergencyInfo = getMarkerInfo(MakerType.emergency);
    return emergencyInfo != null ? 'Call ${emergencyInfo.agent}' : 'Call Emergencies';
  }

  final alertInfo = getMarkerInfo(selectedAlert);
  return alertInfo != null ? 'Call ${alertInfo.agent}' : 'Call Emergencies';
}

/// Gets the emergency number for the call button based on the selected alert.
String getCallButtonEmergencyNumber(MakerType selectedAlert) {
  if (selectedAlert == MakerType.none || selectedAlert == MakerType.emergency) {
    return getMarkerInfo(MakerType.emergency)?.emergencyNumber ?? '911'; // Fallback
  }
  return getMarkerInfo(selectedAlert)?.emergencyNumber ?? '911'; // Fallback
}