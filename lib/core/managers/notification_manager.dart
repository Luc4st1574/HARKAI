import 'package:flutter/foundation.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationManager {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final AppLocalizations _localizations;

  NotificationManager({required AppLocalizations localizations})
      : _localizations = localizations,
        _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  // This is now the single public entry point for this class.
  // It contains all the rules you wanted.
  void handleIncidentNotification(IncidenceData incident, double distance) {
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
      debugPrint('NotificationManager: Sent notification (ID: ${incident.id.hashCode}, Title: "$title")');
    } catch (e) {
      debugPrint('NotificationManager: Failed to show notification: $e');
    }
  }
}