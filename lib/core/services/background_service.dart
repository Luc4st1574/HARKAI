import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/core/managers/download_data_manager.dart';
import 'package:harkai/core/managers/geofence_manager.dart';
import 'package:harkai/core/services/location_service.dart';
import 'package:workmanager/workmanager.dart';

const backgroundTask = "backgroundTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == backgroundTask) {
      final downloadDataManager = DownloadDataManager();
      final geofenceManager = GeofenceManager(downloadDataManager);
      final locationService = LocationService();

      try {
        final position = await locationService.getInitialPosition();
        if (position.success && position.data != null) {
          final city = await locationService.getAddressFromCoordinates(
            position.data!.latitude,
            position.data!.longitude,
          );
          if (city.success && city.data != null) {
            await geofenceManager.initialize(city.data!);
            locationService.getPositionStream().listen((Position position) {
              geofenceManager.onLocationUpdate(position);
            });
          }
        }
      } catch (e) {
        debugPrint('Error in background task: $e');
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}