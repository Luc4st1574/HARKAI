import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:harkai/core/models/geofence_model.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadDataManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  static const String _incidentCacheKey = 'incident_cache';

  Future<void> fetchAndCacheAllIncidents() async {
    try {
      final querySnapshot = await _firestore.collection('HeatPoints').get();

      final incidents = querySnapshot.docs
          .map((doc) => GeofenceModel.fromFirestore(doc))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      final incidentsJson =
          jsonEncode(incidents.map((i) => i.toMap()).toList());
      await prefs.setString(_incidentCacheKey, incidentsJson);

      debugPrint('Downloaded and cached ${incidents.length} total incidents.');
    } catch (e) {
      debugPrint('Error fetching and caching all incidents: $e');
    }
  }

  Future<List<GeofenceModel>> getCachedIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    final incidentsJson = prefs.getString(_incidentCacheKey);
    if (incidentsJson != null) {
      final List<dynamic> incidentList = jsonDecode(incidentsJson);
      return incidentList.map((map) => GeofenceModel.fromMap(map)).toList();
    }
    return [];
  }
  
  /// NEW: Removes incidents from the cache that are marked as invisible in Firestore.
  Future<void> cleanupInvisibleIncidentsFromCache() async {
    debugPrint("Starting cache cleanup of invisible incidents...");
    final cachedIncidents = await getCachedIncidents();
    if (cachedIncidents.isEmpty) {
      debugPrint("Cache is empty. No cleanup needed.");
      return;
    }

    final List<String> cachedIds = cachedIncidents.map((i) => i.id).toList();
    
    // Fetch the current visibility state of these incidents from Firestore.
    final visibleIncidentsMap = await _firestoreService.getIncidentsVisibility(cachedIds);

    final stillVisibleIncidents = cachedIncidents.where((incident) {
      return visibleIncidentsMap[incident.id] ?? false;
    }).toList();

    int removedCount = cachedIncidents.length - stillVisibleIncidents.length;

    if (removedCount > 0) {
        // Save the cleaned list back to the cache.
        final prefs = await SharedPreferences.getInstance();
        final cleanedJson = jsonEncode(stillVisibleIncidents.map((i) => i.toMap()).toList());
        await prefs.setString(_incidentCacheKey, cleanedJson);
        debugPrint("Cache cleanup complete. Removed $removedCount invisible incidents.");
    } else {
        debugPrint("Cache cleanup complete. No incidents needed to be removed.");
    }
  }
  
  Future<void> checkForNewIncidents() async {
    await fetchAndCacheAllIncidents();
  }
}