// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/splash/screens/splash_screen.dart';

// Import for localization
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add these print statements to see what locales Flutter detects from the device
  final List<Locale> deviceLocalesList = WidgetsBinding.instance.platformDispatcher.locales;
  final Locale devicePrimaryLocale = WidgetsBinding.instance.platformDispatcher.locale;
  print('FLUTTER DETECTED DEVICE LOCALES LIST: $deviceLocalesList');
  print('FLUTTER DETECTED PRIMARY DEVICE LOCALE: $devicePrimaryLocale');


  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    print("Environment variables loaded successfully.");
  } catch (e) {
    print("Failed to load environment variables: $e");
  }

  // Ensure Firebase is initialized only once
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('Firebase initialized successfully.');
    } else {
      print('Firebase already initialized: ${Firebase.apps}');
    }
    runApp(const MyApp()); // Run the main app if Firebase init is successful
  } catch (e) {
    print('Error initializing Firebase: $e');
    // If Firebase fails to initialize, run the ErrorApp
    // We still want to provide localizations to ErrorApp if possible
    runApp(const ErrorApp());
    return;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Provide a callback to access AppLocalizations for the title
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)?.appTitle ?? 'My App', // Fallback title

      // List all of the app's supported locales here
      supportedLocales: const [
        Locale('en'), // General English
        Locale('es'), // General Spanish
        // Add other general language locales your app supports (e.g., Locale('fr'))
      ],

      // These delegates make sure that the localization data for the proper language is loaded
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      localeListResolutionCallback: (deviceLocales, supportedLocales) {
        print('DEVICE PREFERRED LOCALES (from callback): $deviceLocales');
        print('APP SUPPORTED LOCALES (from callback): $supportedLocales');

        if (deviceLocales != null) {
          for (Locale deviceLocale in deviceLocales) {
            for (Locale supportedLocale in supportedLocales) {
              // Check if the language codes match
              if (supportedLocale.languageCode == deviceLocale.languageCode) {
                // If language codes match, and our app's supported locale is general (no country code / empty country code)
                if (supportedLocale.countryCode == null ||
                    supportedLocale.countryCode == '' ||
                    supportedLocale.countryCode == deviceLocale.countryCode) {
                  print('MATCH! Using app locale: $supportedLocale for device locale: $deviceLocale');
                  return supportedLocale; // Use this app-supported locale
                }
              }
            }
          }
        }
        // If no match is found from the device's preferred locales, fall back to the first supported locale.
        print('NO MATCH from device preferences, defaulting to ${supportedLocales.first}');
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

// Error fallback widget for Firebase initialization failures
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Attempt to get localizations. It might be null if ErrorApp is run very early
    final AppLocalizations? localizations = AppLocalizations.of(context);
    // Use the firebaseInitError key from your ARB files, with a fallback
    final String errorMessage = localizations?.firebaseInitError ??
        'Failed to initialize Firebase. Please restart the app.';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Provide a callback to access AppLocalizations for the title
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Error', // Fallback title

      // List all of the app's supported locales here
      supportedLocales: const [
        Locale('en'), // English, no country code
        Locale('es'), // Spanish, no country code
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Use the same robust locale resolution for the ErrorApp as well
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
      theme: ThemeData( // Added a basic theme for ErrorApp
        brightness: Brightness.dark,
        primaryColor: Colors.red,
        scaffoldBackgroundColor: Colors.black, // Or any suitable color
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo
              const Image(
                image: AssetImage('assets/images/logo.png'),
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 20), // Space between logo and message
              // Error message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  errorMessage, // Use the localized error message
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