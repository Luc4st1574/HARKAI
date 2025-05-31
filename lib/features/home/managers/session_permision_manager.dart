import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/phone_service.dart';
import '../utils/markers.dart';

class UserSessionManager { // Renamed from HomeUserSessionManager
  final FirebaseAuth _firebaseAuthInstance;
  final PhoneService _phoneService;
  final Function(User? user) _onAuthChangedCallback;

  User? _currentUser;
  User? get currentUser => _currentUser;

  StreamSubscription<User?>? _authSubscription;

  UserSessionManager({ // Renamed
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
    required MakerType selectedIncident,
  }) async {
    await _phoneService.makePhoneCall(
      phoneNumber: getCallButtonEmergencyNumber(selectedIncident),
      context: context,
    );
  }

  void dispose() {
    _authSubscription?.cancel();
  }
}