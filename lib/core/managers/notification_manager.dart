import 'package:flutter/foundation.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// A private helper class to define the conditions for a notification.
class _NotificationRule {
  final MakerType type;
  final double maxDistance; // The maximum distance in meters for the rule to apply.
  final double? minDistance; // Optional minimum distance to create distance ranges.
  final String Function(AppLocalizations) titleBuilder;
  final String Function(AppLocalizations, String) bodyBuilder;

  _NotificationRule({
    required this.type,
    required this.maxDistance,
    this.minDistance,
    required this.titleBuilder,
    required this.bodyBuilder,
  });

  /// Checks if this rule applies to a given incident and distance.
  bool applies(IncidenceData incident, double distance) {
    if (incident.type != type) return false;
    
    bool inMaxDistance = distance <= maxDistance;
    // The rule applies if there's no minimum distance, or if the distance is greater than the minimum.
    bool inMinDistance = minDistance == null || distance > minDistance!;
    
    return inMaxDistance && inMinDistance;
  }
}


class NotificationManager {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final AppLocalizations _localizations;

  // A list of all notification rules, making it easy to add or change them.
  late final List<_NotificationRule> _notificationRules;

  NotificationManager({required AppLocalizations localizations})
      : _localizations = localizations,
        _notificationsPlugin = FlutterLocalNotificationsPlugin() {
    
    // All notification logic is now defined here in a clear, readable list.
    _notificationRules = [
      // Fire Rules (most urgent first)
      _NotificationRule(
          type: MakerType.fire, maxDistance: 250,
          titleBuilder: (l) => l.notifFireDangerTitle,
          bodyBuilder: (l, d) => l.notifFireDangerBody),
      _NotificationRule(
          type: MakerType.fire, maxDistance: 500, minDistance: 250,
          titleBuilder: (l) => l.notifFireNearbyTitle,
          bodyBuilder: (l, d) => l.notifFireNearbyBody),

      // Theft Rules (most urgent first)
      _NotificationRule(
          type: MakerType.theft, maxDistance: 250,
          titleBuilder: (l) => l.notifTheftSecurityTitle,
          bodyBuilder: (l, d) => l.notifTheftSecurityBody),
      _NotificationRule(
          type: MakerType.theft, maxDistance: 500, minDistance: 250,
          titleBuilder: (l) => l.notifTheftAlertTitle,
          bodyBuilder: (l, d) => l.notifTheftAlertBody),
      
      // Generic Incident Rules for Crash, Pet, and Emergency
      _NotificationRule(
          type: MakerType.crash, maxDistance: 300,
          titleBuilder: (l) => l.notifGenericIncidentTitle,
          bodyBuilder: (l, d) => l.notifGenericIncidentBody),
      _NotificationRule(
          type: MakerType.emergency, maxDistance: 300,
          titleBuilder: (l) => l.notifGenericIncidentTitle,
          bodyBuilder: (l, d) => l.notifGenericIncidentBody),
      _NotificationRule(
          type: MakerType.pet, maxDistance: 300,
          titleBuilder: (l) => l.notifGenericIncidentTitle,
          bodyBuilder: (l, d) => l.notifGenericIncidentBody),

      // Place Rules (closest first)
      _NotificationRule(
          type: MakerType.place, maxDistance: 10,
          titleBuilder: (l) => l.notifPlaceWelcomeTitle,
          bodyBuilder: (l, desc) => l.notifPlaceWelcomeBody(desc)),
      _NotificationRule(
          type: MakerType.place, maxDistance: 100, minDistance: 10,
          titleBuilder: (l) => l.notifPlaceAlmostThereTitle,
          bodyBuilder: (l, desc) => l.notifPlaceAlmostThereBody(desc)),
      _NotificationRule(
          type: MakerType.place, maxDistance: 500, minDistance: 100,
          titleBuilder: (l) => l.notifPlaceDiscoveryTitle,
          bodyBuilder: (l, desc) => l.notifPlaceDiscoveryBody(desc)),
    ];
  }

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notifications');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  /// Iterates through the defined rules and sends a notification for the first one that matches.
  void handleIncidentNotification(IncidenceData incident, double distance) {
    for (final rule in _notificationRules) {
      if (rule.applies(incident, distance)) {
        _sendNotification(
          incident: incident,
          title: rule.titleBuilder(_localizations),
          // Pass incident description, which is used for 'place' notifications
          body: rule.bodyBuilder(_localizations, incident.description),
        );
        // Break after finding the first and most specific rule that applies
        // to prevent sending multiple notifications for the same event.
        break; 
      }
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