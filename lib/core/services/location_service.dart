// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as perm_handler;
import 'package:flutter_google_maps_webservices/geocoding.dart'as g_geocoding;

/// A data class to hold the result of a location operation,
class LocationResult<T> {
  final T? data;
  final bool success;
  final String? errorMessage;

  LocationResult({this.data, this.success = true, this.errorMessage});
}

/// Service class to handle all location-related operations.
class LocationService {
  late final g_geocoding.GoogleMapsGeocoding _googleGeocoding;

  /// Constructor for LocationService.
  LocationService() {
    final apiKey = dotenv.env['GEOCODING_KEY'];
    assert(apiKey != null,
        'GEOCODING_KEY not found in .env file. Please ensure it is set.');
    _googleGeocoding = g_geocoding.GoogleMapsGeocoding(apiKey: apiKey!);
    print("LocationService initialized.");
  }

  /// Checks if location services are enabled on the device.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Requests location permission from the user if not already granted.
  Future<bool> requestLocationPermission({bool openSettingsOnError = false}) async {
    print("Requesting location permission...");
    var status = await perm_handler.Permission.location.status; // Check general location status
    if (status.isGranted) {
      print("Location permission already granted.");
      return true;
    }

    // Request "always" permission
    status = await perm_handler.Permission.locationAlways.request();

    if (status.isGranted) {
      print("Location 'always' permission granted.");
      return true;
    } else {
      print("Location 'always' permission denied.");
      if (status.isPermanentlyDenied && openSettingsOnError) {
        await perm_handler.openAppSettings();
      }
      return false;
    }
  }

  /// Determines the current position of the device.
  Future<LocationResult<Position>> getInitialPosition() async {
    print("Attempting to retrieve initial position...");

    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return LocationResult(
          success: false, errorMessage: 'Location services are disabled.');
    }

    bool permissionGranted = await requestLocationPermission(openSettingsOnError: true);
    if (!permissionGranted) {
      // Check the specific status to provide a more accurate message
      perm_handler.PermissionStatus status =
          await perm_handler.Permission.locationWhenInUse.status;
      String errorMessage = 'Location permission denied.';
      if (status.isPermanentlyDenied) {
        errorMessage =
            'Location permissions are permanently denied. Please enable them in app settings.';
      }
      print(errorMessage);
      return LocationResult(success: false, errorMessage: errorMessage);
    }

    try {
      print("Fetching current position with high accuracy...");
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      print(
          "Initial Position - Latitude: ${position.latitude}, Longitude: ${position.longitude}");
      return LocationResult(data: position);
    } catch (e) {
      print('Error getting initial location: $e');
      return LocationResult(
          success: false, errorMessage: 'Failed to get location: ${e.toString()}');
    }
  }

  /// Provides a stream of position updates.
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // Update if the user moves 10 meters
  }) {
    print(
        "Setting up location updates stream with accuracy: $accuracy, distanceFilter: $distanceFilter");
    // The calling widget should ensure permissions are granted before subscribing to this stream.
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Fetches a human-readable address from geographic coordinates (latitude and longitude).
  Future<LocationResult<String>> getAddressFromCoordinates(
      double latitude, double longitude) async {
    print(
        "Fetching address for Latitude: $latitude, Longitude: $longitude");
    try {
      final response = await _googleGeocoding.searchByLocation(
        g_geocoding.Location(lat: latitude, lng: longitude),
      );

      print("Full Geocoding Response Status: ${response.status}");
      if (response.results.isNotEmpty) {
        print("First Geocoding Result: ${response.results.first.toJson()}");
      }


      if (response.status != "OK") {
        print(
            "Error from Geocoding API: ${response.status} - ${response.errorMessage}");
        return LocationResult(
            success: false,
            errorMessage: response.errorMessage ?? "Failed to fetch address (API status not OK)");
      }

      if (response.results.isEmpty) {
        print("No address results found for the given coordinates.");
        return LocationResult(
            data:
                'Location: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)} (No address found)');
      }

      final place = response.results.first;
      String? city;
      String? country;

      for (var component in place.addressComponents) {
        // print("Component: ${component.longName}, Types: ${component.types}");
        if (component.types.contains("locality")) {
          city = component.longName;
        }
        if (component.types.contains("administrative_area_level_1") && city == null) {
          // Fallback to administrative_area_level_1 if locality is not found
          city = component.longName;
        }
        if (component.types.contains("country")) {
          country = component.longName;
        }
      }

      print("Parsed Location - City: $city, Country: $country");

      if (city != null && country != null) {
        return LocationResult(data: '$city, $country');
      } else if (city != null) {
        return LocationResult(data: city);
      } else if (country != null) {
        return LocationResult(data: country);
      } else {
        // Fallback to formatted address if specific components are not found
        if (place.formattedAddress != null && place.formattedAddress!.isNotEmpty) {
            return LocationResult(data: place.formattedAddress);
        }
        return LocationResult(
            data:
                'Location: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)} (Address components not found)');
      }
    } catch (e) {
      print('Geocoding error: $e');
      return LocationResult(
          success: false,
          errorMessage:
              'Geocoding error: ${e.toString()}');
    }
  }
}
