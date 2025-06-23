import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/core/managers/download_data_manager.dart';
import 'package:harkai/core/managers/geofence_manager.dart';
import 'package:harkai/core/managers/notification_manager.dart';
import 'package:harkai/core/services/location_service.dart';
import 'package:harkai/l10n/app_localizations.dart'; // MODIFIED: Import base class
import 'package:harkai/l10n/app_localizations_en.dart'; // English fallback
import 'package:harkai/l10n/app_localizations_es.dart'; // MODIFIED: Import Spanish class
import 'package:workmanager/workmanager.dart';

const String backgroundTask = "harkaiBackgroundTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 1. Use a Completer to keep the task running while the stream is active.
    final Completer<bool> taskCompleter = Completer<bool>();

    // This ensures we can clean up the stream listener if an error occurs.
    StreamSubscription<Position>? positionStreamSubscription;

    try {
      // 2. Initialize dependencies required for the background isolate.
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp();

      // --- FIX: Dynamically select the localization class ---
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final AppLocalizations localizations = deviceLocale.languageCode == 'es'
          ? AppLocalizationsEs()
          : AppLocalizationsEn(); 

      final locationService = LocationService();
      final downloadDataManager = DownloadDataManager();
      final notificationManager = NotificationManager(localizations: localizations); // USE THE DYNAMIC ONE
      final geofenceManager = GeofenceManager(
        downloadDataManager,
        onNotificationTrigger: notificationManager.handleIncidentNotification,
      );
      
      await geofenceManager.initialize();
      await notificationManager.initialize();
      debugPrint("Background Service: Managers initialized globally.");

      // 3. Listen to the stream and manage the completer's state.
      positionStreamSubscription = locationService.getPositionStream().listen(
        (Position newPosition) {
          // This will now run continuously as the task is kept alive.
          geofenceManager.onLocationUpdate(newPosition);
        },
        onError: (error) {
          debugPrint('Error in background location stream: $error');
          positionStreamSubscription?.cancel();
          if (!taskCompleter.isCompleted) {
            taskCompleter.complete(false); // Task fails on stream error
          }
        },
        onDone: () {
          debugPrint('Background location stream was closed.');
          positionStreamSubscription?.cancel();
          if (!taskCompleter.isCompleted) {
            taskCompleter.complete(true); // Task succeeds if stream closes gracefully
          }
        },
      );
      
    } catch (e, s) {
      debugPrint('FATAL Error in background task setup: $e');
      debugPrint(s.toString());
      positionStreamSubscription?.cancel(); // Ensure cleanup on setup error
      if (!taskCompleter.isCompleted) {
         taskCompleter.complete(false); // The task fails if setup fails
      }
    }

    return taskCompleter.future;
  });
}