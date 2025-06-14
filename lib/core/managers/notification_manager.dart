import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart';
import '../services/location_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationManager {
  final LocationService _locationService;
  final FirestoreService _firestoreService;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final AppLocalizations _localizations; // Add this

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<List<IncidenceData>>? _incidentsStreamSubscription;

  List<IncidenceData> _incidents = [];
  Position? _currentPosition;

  NotificationManager({
    required LocationService locationService,
    required FirestoreService firestoreService,
    required AppLocalizations localizations, // Add this
  })  : _locationService = locationService,
        _firestoreService = firestoreService,
        _localizations = localizations, // Add this
        _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);

    _listenToLocationUpdates();
    _listenToIncidents();
  }

  void _listenToLocationUpdates() {
    _positionStreamSubscription =
        _locationService.getPositionStream().listen((position) {
      _currentPosition = position;
      _checkForNearbyIncidents();
    });
  }

  void _listenToIncidents() {
    _incidentsStreamSubscription =
        _firestoreService.getIncidencesStream().listen((incidents) {
      _incidents = incidents;
      _checkForNearbyIncidents();
    });
  }

  void _checkForNearbyIncidents() {
    if (_currentPosition == null) return;

    for (final incident in _incidents) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        incident.latitude,
        incident.longitude,
      );

      _handleIncidentNotification(incident, distance);
    }
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

    await _notificationsPlugin.show(
      incident.id.hashCode, // Use a unique ID for each notification
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> checkForNearbyIncidents(Position currentPosition, List<IncidenceData> incidents) async {
        for (final incident in incidents) {
            final distance = Geolocator.distanceBetween(
                currentPosition.latitude,
                currentPosition.longitude,
                incident.latitude,
                incident.longitude,
            );
            _handleIncidentNotification(incident, distance);
        }
    }

  void dispose() {
    _positionStreamSubscription?.cancel();
    _incidentsStreamSubscription?.cancel();
  }
}