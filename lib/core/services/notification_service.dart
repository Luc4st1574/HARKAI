import 'package:flutter/foundation.dart' show debugPrint;
import 'package:permission_handler/permission_handler.dart' as perm_handler;

class NotificationService {
  Future<bool> requestNotificationPermission({bool openSettingsOnError = false}) async {
    debugPrint("Requesting notification permission...");
    var status = await perm_handler.Permission.notification.status;

    if (status.isGranted) {
      debugPrint("Notification permission already granted.");
      return true;
    }

    if (status.isDenied || status.isRestricted) {
      debugPrint("Notification permission is denied/restricted. Requesting...");
      status = await perm_handler.Permission.notification.request();
      if (status.isGranted) {
        debugPrint("Notification permission granted after request.");
        return true;
      } else {
        debugPrint("Notification permission denied after request.");
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      debugPrint("Notification permission is permanently denied.");
      if (openSettingsOnError) {
        debugPrint("Attempting to open app settings for notification permission...");
        await perm_handler.openAppSettings();
      }
    }
    return false;
  }
}