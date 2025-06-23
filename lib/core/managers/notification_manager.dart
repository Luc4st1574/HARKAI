import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart';
import '../services/location_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:harkai/core/managers/geofence_manager.dart';
import 'package:harkai/core/models/geofence_model.dart';

class NotificationManager {
  final LocationService _locationService;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final AppLocalizations _localizations;
  final GeofenceManager _geofenceManager;
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;

  NotificationManager({
    required LocationService locationService,
    required FirestoreService firestoreService,
    required AppLocalizations localizations,
    required GeofenceManager geofenceManager,
  })  : _locationService = locationService,
        _localizations = localizations,
        _geofenceManager = geofenceManager,
        _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);

    _listenToLocationUpdates();
  }

  void _listenToLocationUpdates() {
    _positionStreamSubscription =
        _locationService.getPositionStream().listen((position) {
      _currentPosition = position;
      _geofenceManager.onLocationUpdate(position);
    });
  }

  void handleGeofenceEvent(String eventType, GeofenceModel geofence) {
    if (_currentPosition == null) return;

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      geofence.latitude,
      geofence.longitude,
    );

    _handleIncidentNotification(
      IncidenceData(
        id: geofence.id,
        userId: '', // Not needed for notification
        latitude: geofence.latitude,
        longitude: geofence.longitude,
        type: geofence.type,
        description: geofence.description,
        timestamp: Timestamp.now(), // Not needed for notification, using current time
        isVisible: true, // Not needed for notification
      ),
      distance,
    );
  }

  void _handleIncidentNotification(IncidenceData incident, double distance) {
    switch (incident.type) {
      case MakerType.fire:
        if (distance <= 500 && distance > 250) {
          _sendNotification(
            incident: incident,
            title: _localizations.notifFireNearbyTitle,
            body: _localizations.notifFireNearbyBody,
          );
        } else if (distance <= 250) {
          _sendNotification(
            incident: incident,
            title: _localizations.notifFireDangerTitle,
            body: _localizations.notifFireDangerBody,
          );
        }
        break;
      case MakerType.theft:
        if (distance <= 500 && distance > 250) {
          _sendNotification(
            incident: incident,
            title: _localizations.notifTheftAlertTitle,
            body: _localizations.notifTheftAlertBody,
          );
        } else if (distance <= 250) {
          _sendNotification(
            incident: incident,
            title: _localizations.notifTheftSecurityTitle,
            body: _localizations.notifTheftSecurityBody,
          );
        }
        break;
      case MakerType.pet:
      case MakerType.crash:
      case MakerType.emergency:
        if (distance <= 300) {
          _sendNotification(
            incident: incident,
            title: _localizations.notifGenericIncidentTitle,
            body: _localizations.notifGenericIncidentBody,
          );
        }
        break;
      case MakerType.place:
        if (distance <= 500 && distance > 100) {
          _sendNotification(
            incident: incident,
            title: _localizations.notifPlaceDiscoveryTitle,
            body: _localizations.notifPlaceDiscoveryBody(incident.description),
          );
        } else if (distance <= 100 && distance > 10) {
          _sendNotification(
            incident: incident,
            title: _localizations.notifPlaceAlmostThereTitle,
            body: _localizations.notifPlaceAlmostThereBody(incident.description),
          );
        } else if (distance <= 10) {
          _sendNotification(
            incident: incident,
            title: _localizations.notifPlaceWelcomeTitle,
            body: _localizations.notifPlaceWelcomeBody(incident.description),
          );
        }
        break;
      default:
        break;
    }
  }

  Future<void> _sendNotification({
    required IncidenceData incident,
    required String title,
    required String body,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'harkai_channel_id',
      'Harkai Notifications',
      channelDescription: 'Notifications for Harkai app incidents and places',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    try {
      await _notificationsPlugin.show(
        incident.id.hashCode,
        title,
        body,
        platformChannelSpecifics,
      );
      debugPrint(
          'NotificationManager: Successfully sent notification (ID: ${incident.id.hashCode}, Title: "$title", Body: "$body") for incident type ${incident.type.name} at lat: ${incident.latitude}, lng: ${incident.longitude}.');
    } catch (e) {
      debugPrint('NotificationManager: Failed to show notification: $e');
    }
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}