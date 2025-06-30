// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
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

  /// Requests foreground location permission (WhenInUse for iOS, Fine/Coarse for Android).
  Future<bool> requestForegroundLocationPermission({bool openSettingsOnError = false}) async {
    debugPrint("LocationService: Requesting foreground location permission...");

    while (true) {
      var status = await perm_handler.Permission.locationWhenInUse.status;
      debugPrint("LocationService: Current foreground location permission status: $status");

      if (status.isGranted) {
        debugPrint("LocationService: Foreground location permission already granted.");
        return true;
      }

      if (status.isPermanentlyDenied) {
        debugPrint("LocationService: Foreground location permission permanently denied. Opening app settings...");
        if (openSettingsOnError) {
          await perm_handler.openAppSettings();
        }
        // Give the user time to change settings and return.
        await Future.delayed(const Duration(seconds: 5));
        // Continue loop to re-check status if user returns from settings.
        continue;
      }

      // If denied (but not permanently), request it.
      debugPrint("LocationService: Requesting foreground location permission...");
      status = await perm_handler.Permission.locationWhenInUse.request();
      if (status.isGranted) {
        debugPrint("LocationService: Foreground location permission granted after request.");
        return true;
      }
      // If not granted after request, loop will re-check or exit if it becomes permanently denied.
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay
    }
  }

  /// Requests "Always Allow" background location permission.
  Future<bool> requestBackgroundLocationPermission({bool openSettingsOnError = false}) async {
    debugPrint("LocationService: Requesting 'Always' background location permission...");
    var status = await perm_handler.Permission.locationAlways.status;
    debugPrint("LocationService: Current background location permission status: $status");

    if (status.isGranted) {
      debugPrint("LocationService: 'Always' background location permission already granted.");
      return true;
    }
    
    // If not granted, request it.
    status = await perm_handler.Permission.locationAlways.request();

    if (status.isGranted) {
      debugPrint("LocationService: 'Always' background location permission granted.");
      return true;
    }

    if (status.isPermanentlyDenied && openSettingsOnError) {
      debugPrint("LocationService: 'Always' background location permission permanently denied. Opening app settings...");
      await perm_handler.openAppSettings();
      // No loop here, as this is typically a one-shot request after foreground is obtained.
    }
    
    debugPrint("LocationService: 'Always' background location permission denied or restricted.");
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

    // MODIFIED: Call foreground permission only
    bool permissionGranted = await requestForegroundLocationPermission(openSettingsOnError: true);
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
      print("Fetching current position...");
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
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
    LocationAccuracy accuracy = LocationAccuracy.low,
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