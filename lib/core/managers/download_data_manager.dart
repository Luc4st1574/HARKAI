import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:harkai/core/models/geofence_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadDataManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _geofenceCacheKey = 'geofence_cache';

  Future<void> fetchAndCacheGeofences(String city) async {
    try {
      final querySnapshot = await _firestore
          .collection('HeatPoints')
          .where('city', isEqualTo: city)
          .get();

      final geofences = querySnapshot.docs
          .map((doc) => GeofenceModel.fromFirestore(doc))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      final geofenceJson = jsonEncode(geofences.map((g) => g.toMap()).toList());
      await prefs.setString(_geofenceCacheKey, geofenceJson);

      debugPrint('Downloaded and cached ${geofences.length} geofences for $city.');
    } catch (e) {
      debugPrint('Error fetching and caching geofences: $e');
    }
  }

  Future<List<GeofenceModel>> getCachedGeofences() async {
    final prefs = await SharedPreferences.getInstance();
    final geofenceJson = prefs.getString(_geofenceCacheKey);
    if (geofenceJson != null) {
      final List<dynamic> geofenceList = jsonDecode(geofenceJson);
      return geofenceList.map((map) => GeofenceModel.fromMap(map)).toList();
    }
    return [];
  }

  Future<void> checkForNewIncidents(String city) async {
    // This method can be called to check for new incidents and update the cache.
    // For simplicity, we'll just re-fetch all geofences for the city.
    await fetchAndCacheGeofences(city);
  }
}