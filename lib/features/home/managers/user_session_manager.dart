import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/phone_service.dart';
import '../utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import
import '../utils/incidences.dart';

class UserSessionManager {
  final FirebaseAuth _firebaseAuthInstance;
  final PhoneService _phoneService;
  final Function(User? user) _onAuthChangedCallback;

  User? _currentUser;
  User? get currentUser => _currentUser;

  StreamSubscription<User?>? _authSubscription;

  UserSessionManager({
    required FirebaseAuth firebaseAuthInstance,
    required PhoneService phoneService,
    required Function(User? user) onAuthChangedCallback,
  })  : _firebaseAuthInstance = firebaseAuthInstance,
        _phoneService = phoneService,
        _onAuthChangedCallback = onAuthChangedCallback;

  void initialize() {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription =
        _firebaseAuthInstance.authStateChanges().listen((User? user) {
      _currentUser = user;
      _onAuthChangedCallback(_currentUser);
    });
  }

  Future<void> makePhoneCall({
    required BuildContext context,
    required AppLocalizations localizations,
    required MakerType selectedIncident,
    required String? cityName, // Add cityName parameter
    required FirestoreService firestoreService, // Add FirestoreService parameter
  }) async {
    String phoneNumberToCall =
        getMarkerInfo(MakerType.emergency, localizations)?.emergencyNumber ?? '911'; // Default fallback

    if (cityName != null && cityName.isNotEmpty) {
      debugPrint("Fetching dynamic numbers for city: $cityName, incident: ${selectedIncident.name}");
      final Map<String, String>? cityNumbers =
          await firestoreService.getEmergencyNumbersForCity(cityName);

      if (cityNumbers != null) {
        String? agentKey;
        MakerType effectiveIncident = selectedIncident == MakerType.none ? MakerType.emergency : selectedIncident;

        // Map MakerType to Firestore field keys based on your database structure
        switch (effectiveIncident) {
          case MakerType.fire:
            agentKey = "Firefighters";
            break;
          case MakerType.crash:
            agentKey = "Serenity"; // As per your Firebase structure
            break;
          case MakerType.theft:
            agentKey = "Police";
            break;
          case MakerType.pet:
            agentKey = "Shelter";
            break;
          case MakerType.emergency:
            // For general emergency, prioritize: Police, then Serenity, then a default
            // Adjust this logic based on your needs and available fields
            agentKey = cityNumbers.containsKey("Police") ? "Police"
                    : cityNumbers.containsKey("Serenity") ? "Serenity"
                    : null; // Fallback to general emergency number if specific not found
            break;
          default:
            agentKey = null;
        }
        debugPrint("Determined agentKey: $agentKey for incident: ${effectiveIncident.name}");


        if (agentKey != null && cityNumbers.containsKey(agentKey)) {
          phoneNumberToCall = cityNumbers[agentKey]!;
          debugPrint("Dynamic number found for $agentKey: $phoneNumberToCall");
        } else {
          debugPrint(
              "Dynamic number not found for agentKey: $agentKey in city: $cityName. Using fallback.");
           // Fallback to the number defined in MarkerInfo for the specific incident type if agent key not found
           // or for a general emergency if no specific mapping exists
          final fallbackInfo = getMarkerInfo(effectiveIncident, localizations);
          phoneNumberToCall = fallbackInfo?.emergencyNumber ?? '911';
        }
      } else {
        debugPrint("No dynamic numbers fetched for city: $cityName. Using default fallback.");
         // If cityNumbers is null, use the default fallback (already set)
      }
    } else {
      debugPrint("City name is null or empty. Using default fallback number for incident: ${selectedIncident.name}.");
      // If no city name, use the hardcoded number from MarkerInfo or a global default
      final fallbackInfo = getMarkerInfo(selectedIncident == MakerType.none ? MakerType.emergency : selectedIncident, localizations);
      phoneNumberToCall = fallbackInfo?.emergencyNumber ?? '911';
    }

    debugPrint("Final number to call for ${selectedIncident.name}: $phoneNumberToCall");

    await _phoneService.makePhoneCall(
      phoneNumber: phoneNumberToCall,
      context: context,
      permissionDeniedMessage: localizations.phoneServicePermissionDenied,
      dialerErrorMessage: localizations.phoneServiceCouldNotLaunchDialer(""), // Pass empty or specific error
    );
  }

  void dispose() {
    _authSubscription?.cancel();
  }
}