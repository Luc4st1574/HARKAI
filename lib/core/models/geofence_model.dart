import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:harkai/features/home/utils/markers.dart';

class GeofenceModel {
  final String id;
  final double latitude;
  final double longitude;
  final double radius;
  final MakerType type;
  final String description;
  final bool isVisible;

  GeofenceModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.type,
    required this.description,
    this.isVisible = true,
  });

  factory GeofenceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GeofenceModel(
      id: doc.id,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      radius: (data['radius'] as num? ?? 500.0).toDouble(), // Default radius
      type: MakerType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MakerType.none,
      ),
      description: data['description'] as String? ?? '',
      isVisible: data['isVisible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'type': type.name,
      'description': description,
      'isVisible': isVisible,
    };
  }

  factory GeofenceModel.fromMap(Map<String, dynamic> map) {
    return GeofenceModel(
      id: map['id'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      radius: map['radius'],
      type: MakerType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MakerType.none,
      ),
      description: map['description'],
      isVisible: map['isVisible'] as bool? ?? true,
    );
  }
}