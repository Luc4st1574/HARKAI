import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'markers.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import

/// A data class to represent a heat point retrieved from Firestore.
class IncidenceData {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final MakerType type;
  final String description;
  final String? imageUrl;
  final Timestamp timestamp;
  final bool isVisible;

  IncidenceData({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.description,
    this.imageUrl,
    required this.timestamp,
    required this.isVisible,
  });

  /// Factory constructor to create a IncidenceData instance from a Firestore document.
  factory IncidenceData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return IncidenceData(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      type: MakerType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () {
          // Fallback if type string doesn't match any enum value
          debugPrint("Unknown MakerType encountered in Firestore: ${data['type']}, defaulting to 'none'.");
          return MakerType.none;
        }
      ),
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(), // Provide a default if null
      isVisible: data['isVisible'] as bool? ?? true, // Default to true if null
    );
  }

  @override
  String toString() {
    return 'IncidenceData(id: $id, userId: $userId, lat: $latitude, lng: $longitude, type: ${type.name}, desc: "$description", imageUrl: $imageUrl, timestamp: $timestamp, isVisible: $isVisible)';
  }
}

/// Utility function to create a [Marker] from [IncidenceData].
Marker createMarkerFromIncidence(
  IncidenceData incidence,
  AppLocalizations localizations,
  {
    Function(IncidenceData)? onImageMarkerTapped,
  }) {
  final MarkerInfo? incidentInfoForMarker = getMarkerInfo(incidence.type, localizations);

  return Marker(
    markerId: MarkerId(incidence.id),
    position: LatLng(incidence.latitude, incidence.longitude),
    icon: BitmapDescriptor.defaultMarkerWithHue(getMarkerHue(incidence.type)),
    infoWindow: (incidence.imageUrl == null)
        ? InfoWindow(
            title: incidentInfoForMarker?.title ?? incidence.type.name.capitalize(),
            snippet: incidence.description.isNotEmpty ? incidence.description : null,
          )
        : InfoWindow.noText,
    onTap: (incidence.imageUrl != null && onImageMarkerTapped != null)
        ? () => onImageMarkerTapped(incidence)
        : null,
  );
}

/// Utility function to create a [Circle] from [IncidenceData].
Circle createCircleFromIncidence(IncidenceData incidence, AppLocalizations localizations) {
  final MarkerInfo? markerInfo = getMarkerInfo(incidence.type, localizations);
  final Color baseColor = markerInfo?.color ?? Colors.grey;

  return Circle(
    circleId: CircleId('circle_${incidence.id}'),
    center: LatLng(incidence.latitude, incidence.longitude),
    radius: 80, // Consider making this configurable or dynamic
    fillColor: baseColor.withAlpha((0.25 * 255).round()),
    strokeColor: baseColor.withAlpha((0.7 * 255).round()),
    strokeWidth: 1,
  );
}

// Helper function to normalize city names for Firestore Document ID matching
String _normalizeCityNameForFirestoreQuery(String cityName) {
  if (cityName.isEmpty) return "";

  // 1. Remove common accents
  String withoutAccents = cityName
      .replaceAll('á', 'a').replaceAll('Á', 'A')
      .replaceAll('é', 'e').replaceAll('É', 'E')
      .replaceAll('í', 'i').replaceAll('Í', 'I')
      .replaceAll('ó', 'o').replaceAll('Ó', 'O')
      .replaceAll('ú', 'u').replaceAll('Ú', 'U')
      .replaceAll('ü', 'u').replaceAll('Ü', 'U')
      .replaceAll('ñ', 'n').replaceAll('Ñ', 'N');

  // 2. Convert to lowercase
  String lowerCaseName = withoutAccents.toLowerCase();

  // 3. Replace multiple spaces with a single space and trim
  String normalized = lowerCaseName.replaceAll(RegExp(r'\s+'), ' ').trim();

  return normalized; // e.g., "víctor larco herrera"
}

/// Service class to manage interactions with Firestore collections.
class FirestoreService {
  final CollectionReference _heatPointsCollection =
      FirebaseFirestore.instance.collection('HeatPoints');
  final CollectionReference _numbersCollection = // Added for the "Numbers" collection
      FirebaseFirestore.instance.collection('Numbers');
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  FirestoreService();

  Future<bool> addIncidence({
    required MakerType type,
    required double latitude,
    required double longitude,
    String? description,
    String? imageUrl,
  }) async {
    if (type == MakerType.none) {
      debugPrint("Attempted to add incidence with MakerType.none. Operation cancelled.");
      return false;
    }

    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      debugPrint("No authenticated user found. Cannot add incidence.");
      return false;
    }

    try {
      await _heatPointsCollection.add({
        'userId': currentUser.uid,
        'latitude': latitude,
        'longitude': longitude,
        'type': type.name,
        'description': description ?? '',
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isVisible': true,
      });
      debugPrint("Incidence of type ${type.name} added successfully by user ${currentUser.uid}.");
      return true;
    } catch (e) {
      debugPrint('Error adding incidence: $e');
      return false;
    }
  }

  Stream<List<IncidenceData>> getIncidencesStream() {
    return _heatPointsCollection
        .where('isVisible', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return IncidenceData.fromFirestore(doc);
        } catch (e) {
          debugPrint('Error parsing IncidenceData from doc ${doc.id}: $e. Data: ${doc.data()}');
          return null;
        }
      }).whereType<IncidenceData>().toList(); // Filters out nulls from parsing errors
    }).handleError((error) {
      debugPrint('Error in getIncidencesStream: $error');
      return <IncidenceData>[]; // Return an empty list on error
    });
  }

  Future<int> markExpiredIncidencesAsInvisible(
      {Duration expiryDuration = const Duration(hours: 1)}) async { // Default expiry: 1 hour
    final DateTime cutoffTime = DateTime.now().subtract(expiryDuration);
    final Timestamp cutoffTimestamp = Timestamp.fromDate(cutoffTime);
    int updatedCount = 0;

    try {
      final QuerySnapshot querySnapshot = await _heatPointsCollection
          .where('timestamp', isLessThan: cutoffTimestamp)
          .where('isVisible', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint("No expired incidences found to mark as invisible.");
        return 0;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isVisible': false});
        updatedCount++;
        // Firestore batch writes are limited (e.g., 500 operations per batch)
        if (updatedCount % 499 == 0 && updatedCount > 0) {
          await batch.commit();
          debugPrint("Committed a batch of $updatedCount expired incidences.");
          batch = FirebaseFirestore.instance.batch(); // Start a new batch
        }
      }
      // Commit any remaining operations in the last batch
      if (updatedCount > 0 && (updatedCount % 499 != 0 || querySnapshot.docs.length < 499) ) {
        await batch.commit();
        debugPrint("Committed the final batch of expired incidences. Total updated: $updatedCount");
      }
      return updatedCount;
    } catch (e) {
      debugPrint('Error marking expired incidences: $e');
      return 0;
    }
  }

  // Method to get emergency numbers for a city
  Future<Map<String, String>?> getEmergencyNumbersForCity(String cityName) async {
    if (cityName.isEmpty) {
      debugPrint('City name is empty, cannot fetch numbers.');
      return null;
    }

    // Normalize the input city name for the query
    String normalizedQueryCityName = _normalizeCityNameForFirestoreQuery(cityName);
    
    debugPrint('Attempting to fetch numbers for city. Original: "$cityName", Normalized for Query: "$normalizedQueryCityName"');

    try {
      // Query the "Numbers" collection for a document where the "City" field
      final QuerySnapshot querySnapshot = await _numbersCollection
          .where("City", isEqualTo: normalizedQueryCityName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Get the first document found
        final DocumentSnapshot cityNumbersDoc = querySnapshot.docs.first;
        debugPrint('Numbers found for city "$normalizedQueryCityName" in document ID "${cityNumbersDoc.id}": ${cityNumbersDoc.data()}');
        
        final Map<String, dynamic> rawData = cityNumbersDoc.data() as Map<String, dynamic>;
        final Map<String, String> stringData = rawData.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        return stringData;
      } else {
        debugPrint('No emergency numbers document found where "City" field is "$normalizedQueryCityName" (Normalized from: "$cityName")');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching emergency numbers for city "$normalizedQueryCityName": $e');
      return null;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  String capitalizeAllWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }
}