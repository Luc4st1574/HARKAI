import 'package:flutter/foundation.dart' show debugPrint;
import 'package:permission_handler/permission_handler.dart';

class SpeechPermissionService {
  /// Checks and requests microphone permission.
  Future<bool> requestMicrophonePermission({bool openSettingsOnError = false}) async {
    debugPrint("SpeechPermissionService: Checking microphone permission...");
    PermissionStatus status = await Permission.microphone.status;
    debugPrint("SpeechPermissionService: Current microphone permission status: ${status.name}");

    if (status.isGranted) {
      debugPrint("SpeechPermissionService: Microphone permission already granted.");
      return true;
    }

    if (status.isDenied || status.isRestricted || status.isLimited) {
      debugPrint("SpeechPermissionService: Microphone permission is ${status.name}. Requesting...");
      status = await Permission.microphone.request();
      if (status.isGranted) {
        debugPrint("SpeechPermissionService: Microphone permission granted after request.");
        return true;
      } else {
        debugPrint("SpeechPermissionService: Microphone permission denied after request. Status: ${status.name}");
        if (status.isPermanentlyDenied && openSettingsOnError) {
          debugPrint("SpeechPermissionService: Microphone permission permanently denied. Opening app settings...");
          await openAppSettings();
        }
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      debugPrint("SpeechPermissionService: Microphone permission is permanently denied.");
      if (openSettingsOnError) {
        debugPrint("SpeechPermissionService: Attempting to open app settings for microphone permission...");
        await openAppSettings();
      }
      return false;
    }
    
    debugPrint("SpeechPermissionService: Unhandled microphone permission status: ${status.name}");
    return false;
  }

  /// Call this at app startup to request microphone permission and check STT service.
  Future<bool> ensurePermissionsAndInitializeService({bool openSettingsOnError = true}) async {
    bool micPermissionGranted = await requestMicrophonePermission(openSettingsOnError: openSettingsOnError);
    if (!micPermissionGranted) {
      debugPrint("SpeechPermissionService: Microphone permission not granted. Speech input will likely fail.");
      return false;
    }

    return micPermissionGranted;
  }

  Future<PermissionStatus> getMicrophonePermissionStatus() async {
    return await Permission.microphone.status;
  }

}