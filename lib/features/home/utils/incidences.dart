import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'markers.dart';

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
          return MakerType.none;
        }
      ),
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      isVisible: data['isVisible'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'IncidenceData(id: $id, userId: $userId, lat: $latitude, lng: $longitude, type: ${type.name}, desc: "$description", imageUrl: $imageUrl, timestamp: $timestamp, isVisible: $isVisible)';
  }
}

/// Utility function to create a [Marker] from [IncidenceData].
Marker createMarkerFromIncidence(
  IncidenceData incidence, {
  Function(IncidenceData)? onImageMarkerTapped, // Callback for markers with images
}) {
  final incidentInfoForMarker = getMarkerInfo(incidence.type);
  return Marker(
    markerId: MarkerId(incidence.id),
    position: LatLng(incidence.latitude, incidence.longitude),
    icon: BitmapDescriptor.defaultMarkerWithHue(getMarkerHue(incidence.type)),
    infoWindow: (incidence.imageUrl == null)
        ? InfoWindow(
            title: incidentInfoForMarker?.title ?? incidence.type.name.capitalize(),
            snippet: incidence.description.isNotEmpty ? incidence.description : null,
          )
        : InfoWindow.noText, // No default InfoWindow if there's an image and custom tap
    onTap: (incidence.imageUrl != null && onImageMarkerTapped != null)
        ? () => onImageMarkerTapped(incidence)
        : null,
  );
}

/// Utility function to create a [Circle] from [IncidenceData].
Circle createCircleFromIncidence(IncidenceData incidence) {
  final MarkerInfo? markerInfo = getMarkerInfo(incidence.type);
  final Color baseColor = markerInfo?.color ?? Colors.grey;

  return Circle(
    circleId: CircleId('circle_${incidence.id}'),
    center: LatLng(incidence.latitude, incidence.longitude),
    radius: 80,
    fillColor: baseColor.withAlpha((0.25 * 255).round()),
    strokeColor: baseColor.withAlpha((0.7 * 255).round()),
    strokeWidth: 1,
  );
}

/// Service class to manage interactions with the Firestore 'HeatPoints' collection.
class FirestoreService {
  final CollectionReference _heatPointsCollection =
      FirebaseFirestore.instance.collection('HeatPoints');
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  FirestoreService();

  Future<bool> addIncidence({
    required MakerType type,
    required double latitude,
    required double longitude,
    String? description,
    String? imageUrl, // New parameter
  }) async {
    if (type == MakerType.none) {
      return false;
    }

    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      return false;
    }

    try {
      await _heatPointsCollection.add({
        'userId': currentUser.uid,
        'latitude': latitude,
        'longitude': longitude,
        'type': type.name,
        'description': description ?? '',
        'imageUrl': imageUrl, // Save imageUrl
        'timestamp': FieldValue.serverTimestamp(),
        'isVisible': true,
      });
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
          debugPrint('Error parsing IncidenceData: $e');
          return null;
        }
      }).whereType<IncidenceData>().toList();
    }).handleError((error) {
      debugPrint('Error in getIncidencesStream: $error');
      return <IncidenceData>[];
    });
  }

  Future<int> markExpiredIncidencesAsInvisible(
      {Duration expiryDuration = const Duration(hours: 1)}) async {
    final DateTime cutoffTime = DateTime.now().subtract(expiryDuration);
    final Timestamp cutoffTimestamp = Timestamp.fromDate(cutoffTime);
    int updatedCount = 0;

    try {
      final QuerySnapshot querySnapshot = await _heatPointsCollection
          .where('timestamp', isLessThan: cutoffTimestamp)
          .where('isVisible', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 0;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isVisible': false});
        updatedCount++;
        if (updatedCount % 499 == 0 && updatedCount > 0) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
        }
      }
      if (updatedCount > 0 && (updatedCount % 499 != 0 || querySnapshot.docs.length < 499) ) {
        await batch.commit();
      }
      return updatedCount;
    } catch (e) {
      debugPrint('Error marking expired incidences: $e');
      return 0;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
    String capitalizeAllWords() { // Added for consistency if used elsewhere
    if (isEmpty) return this;
    return split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }
}