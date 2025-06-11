// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as perm_handler;
import 'package:flutter_google_maps_webservices/geocoding.dart'as g_geocoding;

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

  /// Requests location permission from the user.
  Future<bool> requestLocationPermission({bool openSettingsOnError = false}) async {
    print("Requesting location permission...");

    while (true) {
      var status = await perm_handler.Permission.location.status;
      print("Current location permission status: $status");

      if (status.isGranted) {
        print("Location permission granted.");
        // After getting basic location, now try for "Always" permission
        return await requestBackgroundLocationPermission(openSettingsOnError: openSettingsOnError);
      }

      if (status.isPermanentlyDenied) {
        print("Location permission permanently denied. Opening app settings...");
        if (openSettingsOnError) {
          await perm_handler.openAppSettings();
        }
        // Give the user time to change settings and return.
        await Future.delayed(const Duration(seconds: 5));
        continue; // Re-check the status after returning from settings.
      }

      // If denied (but not permanently), request it.
      print("Requesting location permission...");
      await perm_handler.Permission.location.request();
      // Loop will re-check the status on the next iteration.
      await Future.delayed(const Duration(seconds: 1)); // Small delay
    }
  }
  
  /// Requests "Always Allow" background location permission.
  Future<bool> requestBackgroundLocationPermission({bool openSettingsOnError = false}) async {
    var status = await perm_handler.Permission.locationAlways.status;
    if (status.isGranted) {
      print("Background location permission already granted.");
      return true;
    }
    
    print("Requesting 'Always' background location permission...");
    status = await perm_handler.Permission.locationAlways.request();

    if (status.isGranted) {
      print("'Always' background location permission granted.");
      return true;
    }

    if (status.isPermanentlyDenied && openSettingsOnError) {
      await perm_handler.openAppSettings();
    }
    
    return false;
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
        if (component.types.contains("locality")) {
          city = component.longName;
        }
        if (component.types.contains("administrative_area_level_1") && city == null) {
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