import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/core/managers/download_data_manager.dart';
import 'package:harkai/core/managers/geofence_manager.dart';
import 'package:harkai/core/managers/notification_manager.dart';
import 'package:harkai/core/services/location_service.dart';
import 'package:harkai/l10n/app_localizations_en.dart';
import 'package:workmanager/workmanager.dart';

const String backgroundTask = "harkaiBackgroundTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != backgroundTask) {
      return true; // Acknowledge other tasks if any
    }

    // --- Isolate Initialization ---
    // This is crucial for plugins to work in the background.
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    // --- Dependency Setup ---
    final locationService = LocationService();
    final downloadDataManager = DownloadDataManager();
    final localizations = AppLocalizationsEn(); // Default language for background notifications

    final notificationManager = NotificationManager(localizations: localizations);
    
    // Wire the managers together using the callback
    final geofenceManager = GeofenceManager(
      downloadDataManager,
      onNotificationTrigger: notificationManager.handleIncidentNotification,
    );

    // --- Task Execution ---
    try {
      // 1. Get current location to find the city
      final positionResult = await locationService.getInitialPosition();
      if (!positionResult.success || positionResult.data == null) {
        debugPrint('Background Task Error: Could not get initial position.');
        return false;
      }

      // 2. Determine city for downloading geofences
      final cityResult = await locationService.getAddressFromCoordinates(
        positionResult.data!.latitude,
        positionResult.data!.longitude,
      );
      if (!cityResult.success || cityResult.data == null) {
        debugPrint('Background Task Error: Could not determine city.');
        return false;
      }

      // 3. Initialize managers with city-specific data
      await geofenceManager.initialize(cityResult.data!);
      await notificationManager.initialize();
      debugPrint("Background Service: Managers initialized for city: ${cityResult.data!}");

      // 4. Start the location stream and connect it to the GeofenceManager
      locationService.getPositionStream().listen((Position newPosition) {
        geofenceManager.onLocationUpdate(newPosition);
      });

      // The stream will keep this isolate alive.
      // Workmanager handles the lifecycle.
      return true;

    } catch (e, s) {
      debugPrint('FATAL Error in background task: $e');
      debugPrint(s.toString());
      return false; // Indicate failure
    }
  });
}