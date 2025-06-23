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

    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    final locationService = LocationService();
    final downloadDataManager = DownloadDataManager();
    final localizations = AppLocalizationsEn(); 

    final notificationManager = NotificationManager(localizations: localizations);
    
    final geofenceManager = GeofenceManager(
      downloadDataManager,
      onNotificationTrigger: notificationManager.handleIncidentNotification,
    );

    try {
      // MODIFIED: Removed logic to get user's city. Initialization is now global.
      await geofenceManager.initialize();
      await notificationManager.initialize();
      debugPrint("Background Service: Managers initialized globally.");

      // This stream will continue to run and check the user's location against all cached incidents.
      locationService.getPositionStream().listen((Position newPosition) {
        geofenceManager.onLocationUpdate(newPosition);
      });

      return true;

    } catch (e, s) {
      debugPrint('FATAL Error in background task: $e');
      debugPrint(s.toString());
      return false; 
    }
  });
}