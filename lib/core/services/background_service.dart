import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:harkai/core/services/location_service.dart';
import 'package:harkai/core/managers/notification_manager.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/l10n/app_localizations.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
      autoStart: true,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  // Determine the device's locale to load the correct translations
  final locale = PlatformDispatcher.instance.locale;
  final localizations = lookupAppLocalizations(locale);

  final LocationService locationService = LocationService();
  final FirestoreService firestoreService = FirestoreService();
  
  // Pass the AppLocalizations instance to the NotificationManager
  final NotificationManager notificationManager = NotificationManager(
    locationService: locationService,
    firestoreService: firestoreService,
    localizations: localizations,
  );

  notificationManager.initialize();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}