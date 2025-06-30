// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import

/// A widget that displays location information prominently.
class LocationInfoWidget extends StatelessWidget {
  final String locationText;

  const LocationInfoWidget({
    super.key,
    required this.locationText,
  });

  @override
  Widget build(BuildContext context) {
    // Get AppLocalizations instance
    final localizations = AppLocalizations.of(context)!;

    return Padding(
      // Consistent padding as in the original _buildLocationInfo method
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            locationText, // This is dynamic, passed from map_location_manager
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF57D463),
            ),
          ),
          const SizedBox(height: 4),

          Text(
            localizations.homeScreenLocationInfoText, // Changed to use localization key
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF57D463),
            ),
          ),
        ],
      ),
    );
  }
}