import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:harkai/core/config/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:harkai/core/services/background_service.dart';
import 'package:harkai/features/splash/screens/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final List<Locale> deviceLocalesList = WidgetsBinding.instance.platformDispatcher.locales;
  final Locale devicePrimaryLocale = WidgetsBinding.instance.platformDispatcher.locale;
  debugPrint('FLUTTER DETECTED DEVICE LOCALES LIST: $deviceLocalesList');
  debugPrint('FLUTTER DETECTED PRIMARY DEVICE LOCALE: $devicePrimaryLocale');

  try {
    await dotenv.load(fileName: ".env");
    debugPrint("Environment variables loaded successfully.");
  } catch (e) {
    debugPrint("Failed to load environment variables: $e");
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully.');

      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
      );
      debugPrint('Firebase App Check activated.');

    } else {
      debugPrint('Firebase already initialized: ${Firebase.apps}');
    }

    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    Workmanager().registerPeriodicTask(
      "1",
      backgroundTask,
      frequency: const Duration(minutes: 15),
    );

    runApp(const MyApp());
    
  } catch (e) {
    debugPrint('Error during Firebase initialization or App Check activation: $e');
    runApp(const ErrorApp());
    return;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)?.appTitle ?? 'My App',
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (deviceLocales, supportedLocales) {
        debugPrint('DEVICE PREFERRED LOCALES (from callback): $deviceLocales');
        debugPrint('APP SUPPORTED LOCALES (from callback): $supportedLocales');
        if (deviceLocales != null) {
          for (Locale deviceLocale in deviceLocales) {
            for (Locale supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == deviceLocale.languageCode) {
                if (supportedLocale.countryCode == null ||
                    supportedLocale.countryCode == '' ||
                    supportedLocale.countryCode == deviceLocale.countryCode) {
                  debugPrint('MATCH! Using app locale: $supportedLocale for device locale: $deviceLocale');
                  return supportedLocale;
                }
              }
            }
          }
        }
        debugPrint('NO MATCH from device preferences, defaulting to ${supportedLocales.first}');
        return supportedLocales.first;
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.green,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const SplashScreen(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? localizations = AppLocalizations.of(context);
    final String errorMessage = localizations?.firebaseInitError ??
        'Failed to initialize Firebase. Please restart the app.';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Error',
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (deviceLocales, supportedLocales) {
        if (deviceLocales != null) {
          for (Locale deviceLocale in deviceLocales) {
            for (Locale supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == deviceLocale.languageCode) {
                if (supportedLocale.countryCode == null ||
                    supportedLocale.countryCode == '' ||
                    supportedLocale.countryCode == deviceLocale.countryCode) {
                  return supportedLocale;
                }
              }
            }
          }
        }
        return supportedLocales.first;
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.red,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(
                image: AssetImage('assets/images/logo.png'),
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}