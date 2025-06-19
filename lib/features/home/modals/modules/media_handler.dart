// lib/features/home/modals/modules/media_handler.dart

import 'dart:async';
import 'dart:io'; // For File operations

import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class DeviceMediaHandler {
  final AudioRecorder _audioRecorder;
  final ImagePicker _imagePicker;

  DeviceMediaHandler()
      : _audioRecorder = AudioRecorder(),
        _imagePicker = ImagePicker();

  // --- Temporary File Management ---
  
  /// Generates a temporary file path for media storage.
  Future<String> getTemporaryFilePath(String extension) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/incident_media_$timestamp.$extension';
  }

  /// Deletes a file at the given [filePath].

  Future<void> deleteTemporaryFile(String? filePath) async {
    if (filePath == null) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint("DeviceMediaHandler: Deleted temporary file: $filePath");
      }
    } catch (e) {
      debugPrint(
          "DeviceMediaHandler: Error deleting temporary file $filePath: $e");
    }
  }

  // --- Audio Recording ---

  /// Checks if the audio recorder is currently recording.
  Future<bool> isAudioRecording() async {
    return await _audioRecorder.isRecording();
  }

  /// Starts audio recording and saves it to the specified [filePath].

  Future<String?> startRecording(
      {required String filePath, required RecordConfig config}) async {
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop(); // Stop if already recording
        debugPrint(
            "DeviceMediaHandler: Stopped previous recording before starting new one.");
      }
      await _audioRecorder.start(config, path: filePath);
      debugPrint("DeviceMediaHandler: Started audio recording to $filePath");
      return filePath;
    } catch (e) {
      debugPrint("DeviceMediaHandler: Could not start audio recording: $e");
      return null;
    }
  }

  /// Stops the current audio recording.

  Future<String?> stopRecording() async {
    if (!await _audioRecorder.isRecording()) {
      debugPrint(
          "DeviceMediaHandler: Stop recording called but not currently recording.");
      return null;
    }
    try {
      final path = await _audioRecorder.stop();
      debugPrint("DeviceMediaHandler: Stopped audio recording. Path: $path");

      if (path != null &&
          File(path).existsSync() &&
          await File(path).length() > 100) { // Basic validation
        return path;
      } else {
        debugPrint(
            "DeviceMediaHandler: Audio recording seems empty or was not saved correctly at path: $path. File may be deleted.");
        if (path != null) {
          await deleteTemporaryFile(
              path); // Clean up if deemed invalid
        }
        return null;
      }
    } catch (e) {
      debugPrint("DeviceMediaHandler: Error stopping audio recording: $e");
      return null;
    }
  }

  // --- Image Capture ---

  Future<File?> captureImageFromCamera(
      {double? maxWidth, int? imageQuality}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
      );
      if (pickedFile != null) {
        debugPrint(
            "DeviceMediaHandler: Image captured successfully: ${pickedFile.path}");
        return File(pickedFile.path);
      } else {
        debugPrint("DeviceMediaHandler: Image capture cancelled by user.");
        return null;
      }
    } catch (e) {
      debugPrint("DeviceMediaHandler: Failed to capture image: $e");
      return null;
    }
  }

  // --- NEW: Image Picking ---

  Future<File?> pickImageFromGallery(
      {double? maxWidth, int? imageQuality}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
      );
      if (pickedFile != null) {
        debugPrint(
            "DeviceMediaHandler: Image picked from gallery successfully: ${pickedFile.path}");
        return File(pickedFile.path);
      } else {
        debugPrint("DeviceMediaHandler: Image picking cancelled by user.");
        return null;
      }
    } catch (e) {
      debugPrint("DeviceMediaHandler: Failed to pick image from gallery: $e");
      return null;
    }
  }

  // --- Cleanup ---

  Future<void> disposeAudioRecorder() async {
    if (await _audioRecorder.isRecording()) {
      try {
        await _audioRecorder.stop();
        debugPrint(
            "DeviceMediaHandler: Audio recording stopped during dispose.");
      } catch (e) {
        debugPrint(
            "DeviceMediaHandler: Error stopping audio recorder during dispose: $e");
      }
    }
    try {
      _audioRecorder.dispose();
      debugPrint("DeviceMediaHandler: AudioRecorder disposed.");
    } catch (e) {
      debugPrint("DeviceMediaHandler: Error disposing AudioRecorder: $e");
    }
  }
}