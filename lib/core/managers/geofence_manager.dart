import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/core/models/geofence_model.dart';
import 'package:harkai/core/managers/download_data_manager.dart';
import 'package:harkai/core/managers/notification_manager.dart';

class GeofenceManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DownloadDataManager _downloadDataManager;
  final NotificationManager _notificationManager;
  List<GeofenceModel> _geofences = [];
  Set<String> _activeGeofences = {};

  GeofenceManager(this._downloadDataManager, this._notificationManager);

  Future<void> initialize(String city) async {
    await _downloadDataManager.fetchAndCacheGeofences(city);
    _geofences = await _downloadDataManager.getCachedGeofences();
  }

  void onLocationUpdate(Position position) {
    if (_geofences.isEmpty) {
      return;
    }

    final currentGeofences = <String>{};
    for (final geofence in _geofences) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        geofence.latitude,
        geofence.longitude,
      );

      if (distance <= geofence.radius) {
        currentGeofences.add(geofence.id);
      }
    }

    final enteredGeofences = currentGeofences.difference(_activeGeofences);
    final exitedGeofences = _activeGeofences.difference(currentGeofences);

    for (final geofenceId in enteredGeofences) {
      final geofence = _geofences.firstWhere((g) => g.id == geofenceId);
      _onEnterGeofence(geofence);
    }

    for (final geofenceId in exitedGeofences) {
      final geofence = _geofences.firstWhere((g) => g.id == geofenceId);
      _onExitGeofence(geofence);
    }

    _activeGeofences = currentGeofences;
  }

  void _onEnterGeofence(GeofenceModel geofence) {
    debugPrint('Entering geofence: ${geofence.id}');
    _writeGeofenceEvent('enter', geofence.id);
    _notificationManager.handleGeofenceEvent('enter', geofence);
  }

  void _onExitGeofence(GeofenceModel geofence) {
    debugPrint('Exiting geofence: ${geofence.id}');
    _writeGeofenceEvent('exit', geofence.id);
    _notificationManager.handleGeofenceEvent('exit', geofence);
  }

  Future<void> _writeGeofenceEvent(String event, String geofenceId) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('geofence_events').add({
          'userId': user.uid,
          'geofenceId': geofenceId,
          'event': event,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error writing geofence event: $e');
      }
    }
  }
}