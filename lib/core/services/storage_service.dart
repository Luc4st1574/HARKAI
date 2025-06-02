import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(bucket: 'harkaibd.firebasestorage.app');

  Future<String?> uploadIncidentImage({
    required File imageFile,
    required String userId,
    required String incidentType, // To help organize, e.g. "fire", "theft"
  }) async {
    try {
      String fileExtension = p.extension(imageFile.path);
      // Create a unique file name
      String fileName = 'incident_images/$userId/$incidentType/${DateTime.now().millisecondsSinceEpoch}_${p.basename(imageFile.path)}';
      
      Reference ref = _storage.ref().child(fileName);
      
      // Define metadata for the image (optional, but good practice)
      final metadata = SettableMetadata(
        contentType: 'image/${fileExtension.replaceAll('.', '')}', // e.g., 'image/jpeg' or 'image/png'
        customMetadata: {
          'user_id': userId,
          'incident_type': incidentType,
        },
      );

      UploadTask uploadTask = ref.putFile(imageFile, metadata);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint("Image uploaded successfully: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image to Firebase Storage: $e');
      return null;
    }
  }
}