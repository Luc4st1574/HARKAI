import 'package:flutter/foundation.dart' show debugPrint;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechPermissionService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();

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

  /// Initializes the SpeechToText service.
  /// This often handles speech-specific permissions/setups beyond basic microphone access.
  Future<bool> initializeSpeechToTextService() async {
    debugPrint("SpeechPermissionService: Initializing SpeechToText service instance...");
    try {
      // Using a fresh instance for initialization check, not necessarily the one used in the modal.
      // The modal will initialize its own instance.
      final stt.SpeechToText localSTT = stt.SpeechToText();
      bool available = await localSTT.initialize(
        onStatus: (status) => debugPrint('SpeechPermissionService: STT init status: $status'),
        onError: (error) => debugPrint('SpeechPermissionService: STT init error: ${error.errorMsg}'),
        // Set a short finalTimeout if you only want to check availability quickly.
        // finalTimeout: const Duration(milliseconds: 50) 
      );
      if (available) {
        debugPrint("SpeechPermissionService: SpeechToText service is available and initialized for checking.");
      } else {
        debugPrint("SpeechPermissionService: SpeechToText service is NOT available after initialization check.");
      }
      return available;
    } catch (e) {
      debugPrint("SpeechPermissionService: Exception during SpeechToText service initialization check: $e");
      return false;
    }
  }

  /// Call this at app startup to request microphone permission and check STT service.
  Future<bool> ensurePermissionsAndInitializeService({bool openSettingsOnError = true}) async {
    bool micPermissionGranted = await requestMicrophonePermission(openSettingsOnError: openSettingsOnError);
    if (!micPermissionGranted) {
      debugPrint("SpeechPermissionService: Microphone permission not granted. Speech input will likely fail.");
      await initializeSpeechToTextService(); // Attempt to check STT service status regardless
      return false; // Return false because primary mic permission failed
    }

    // If microphone permission is granted, then check/initialize the STT service.
    bool sttServiceReady = await initializeSpeechToTextService();
    if(!sttServiceReady){
      debugPrint("SpeechPermissionService: STT Service not ready even if mic permission was granted.");
    }
    
    return micPermissionGranted && sttServiceReady;
  }

  Future<PermissionStatus> getMicrophonePermissionStatus() async {
    return await Permission.microphone.status;
  }

  Future<bool> isSpeechRecognitionAvailable() async {
    // This checks if the STT service itself is available, usually after initialize has been called.
    return _speechToText.isAvailable;
  }
}