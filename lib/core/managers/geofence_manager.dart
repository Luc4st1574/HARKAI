import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/core/models/geofence_model.dart';
import 'package:harkai/core/managers/download_data_manager.dart';
import 'package:harkai/features/home/utils/incidences.dart';

// Define a type for the callback function for better readability.
typedef NotificationCallback = void Function(IncidenceData incident, double distance);

class GeofenceManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DownloadDataManager _downloadDataManager;
  final NotificationCallback onNotificationTrigger;

  // MODIFIED: Renamed for clarity, this list holds all incidents for checking.
  List<GeofenceModel> _incidents = [];
  final Set<String> _activeGeofences = {};

  GeofenceManager(this._downloadDataManager, {required this.onNotificationTrigger});

  Future<void> initialize() async {
    await _downloadDataManager.fetchAndCacheAllIncidents();
    _incidents = await _downloadDataManager.getCachedIncidents();
    debugPrint("GeofenceManager initialized with ${_incidents.length} incidents from cache.");
  }

  void onLocationUpdate(Position position) {
    if (_incidents.isEmpty) return;

    final Set<String> previouslyActiveGeofences = Set.from(_activeGeofences);
    _activeGeofences.clear();

    for (final geofence in _incidents) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        geofence.latitude,
        geofence.longitude,
      );

      if (distance <= geofence.radius) {
        _activeGeofences.add(geofence.id);

        // This block is only entered ONCE when the user crosses into the geofence.
        if (!previouslyActiveGeofences.contains(geofence.id)) {
          _onEnterGeofence(geofence, distance);
          onNotificationTrigger(_createIncidenceData(geofence), distance);
        }
      }
    }
  }

  void _onEnterGeofence(GeofenceModel geofence, double distance) {
    debugPrint('Entering geofence: ${geofence.id} at distance: $distance');
    _writeGeofenceEvent('enter', geofence.id);
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

  // Helper to convert GeofenceModel to IncidenceData for the callback
  IncidenceData _createIncidenceData(GeofenceModel geofence) {
    return IncidenceData(
      id: geofence.id,
      latitude: geofence.latitude,
      longitude: geofence.longitude,
      type: geofence.type,
      description: geofence.description,
      timestamp: Timestamp.now(),
      isVisible: true,
      userId: '',
    );
  }
}