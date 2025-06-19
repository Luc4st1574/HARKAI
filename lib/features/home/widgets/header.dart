// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart'; // For User object
import 'package:flutter/material.dart';
import '../../profile/screens/profile.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import
import '../../home/utils/markers.dart';
import 'package:harkai/features/incident_feed/screens/incident_screen.dart';
import 'package:harkai/features/places/screens/places_screen.dart';

/// A widget that displays the header section of the home screen.
class HomeHeaderWidget extends StatelessWidget {
  /// The current authenticated user. Can be null if no user is logged in.
  final User? currentUser;
  final VoidCallback? onLogoTap;
  final bool isLongPressEnabled;

  const HomeHeaderWidget({
    super.key,
    this.currentUser,
    this.onLogoTap,
    this.isLongPressEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; // Get AppLocalizations instance

    // Use profileDefaultUsername as a fallback if display name and email are null
    final String displayName =
        currentUser?.displayName ?? currentUser?.email ?? localizations.profileDefaultUsername;
    final String? photoURL = currentUser?.photoURL;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center, // Vertically center items
        children: [
          // App Logo
          // Ensure 'assets/images/logo.png' is in your pubspec.yaml and the path is correct.
          GestureDetector(
            onTap: onLogoTap ?? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlacesScreen()), // Your new screen
              );
            },
            onLongPress: isLongPressEnabled
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IncidentScreen(
                          // Or your PlaceIncidentFeedScreen
                          incidentType: MakerType.place,
                          currentUser: currentUser, // Pass the current user
                        ),
                      ),
                    );
                  }
                : null,
            child: Image.asset(
              'assets/images/logo.png',
              height: 50, // Standardized height
              errorBuilder: (context, error, stackTrace) {
                // Fallback in case the logo asset fails to load
                print("Error loading logo asset: $error");
                return const Icon(Icons.broken_image,
                    size: 50, color: Colors.grey);
              },
            ),
          ),

          // User Profile Section
          InkWell(
            // Using InkWell for better tap feedback
            onTap: () {
              print("User profile section tapped. Navigating to Profile screen.");
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const Profile()), // Assuming Profile() is const constructible
              );
            },
            borderRadius: BorderRadius.circular(30), // Tap feedback shape
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Padding for tap area
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User Name
                  Text(
                    displayName, // Now uses localized fallback
                    style: const TextStyle(
                      color: Color(0xFF57D463), // Color from original design
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis, // Prevent overflow for long names
                  ),
                  const SizedBox(width: 10), // Spacing between name and picture

                  // User Picture
                  CircleAvatar(
                    radius: 25, // Standardized radius
                    backgroundColor: Colors.grey.shade300, // Placeholder background
                    // Attempt to load network image if photoURL is available
                    backgroundImage:
                        photoURL != null ? NetworkImage(photoURL) : null,
                    // Fallback icon if no photoURL or if NetworkImage fails (though CircleAvatar doesn't have a direct error builder for backgroundImage)
                    child: photoURL == null
                        ? const Icon(
                            Icons.account_circle,
                            color: Color(0xFF57D463), // Color from original design
                            size:
                                50, // Icon size to fill the CircleAvatar (radius * 2)
                          )
                        : null, // No child if backgroundImage is intended to be shown
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}