import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/phone_service.dart';
import '../utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import

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
    required BuildContext context, // Keep context to get localizations if not passed directly
    required AppLocalizations localizations, // Added: Pass AppLocalizations
    required MakerType selectedIncident,
  }) async {
    // getCallButtonEmergencyNumber now requires localizations
    final String phoneNumber = getCallButtonEmergencyNumber(selectedIncident, localizations);

    await _phoneService.makePhoneCall(
      phoneNumber: phoneNumber,
      context: context, // PhoneService uses this for ScaffoldMessenger
    );
  }

  void dispose() {
    _authSubscription?.cancel();
  }
}