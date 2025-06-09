// lib/features/auth/services/auth_service.dart
// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:harkai/features/home/screens/home.dart';
import 'package:harkai/features/auth/screens/login_screen.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  Future<void> signup({
    required String email,
    required String password,
    required String userName,
    required BuildContext context,
    required AppLocalizations localizations,
  }) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await user.updateProfile(displayName: userName);
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_launch', true);

      await Future.delayed(const Duration(seconds: 1));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = localizations.authWeakPassword;
      } else if (e.code == 'email-already-in-use') {
        message = localizations.authEmailInUse;
      } else if (e.code == 'invalid-email') {
        message = localizations.authInvalidEmail;
      } else {
        message = localizations.authGenericError;
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
      throw e; // Re-throw the exception to be caught by the UI
    } catch (e) {
      Fluttertoast.showToast(
        msg: localizations.authGenericError,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
      throw e; // Re-throw the exception
    }
  }

  Future<void> signin({
    required String email,
    required String password,
    required BuildContext context,
    required AppLocalizations localizations,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await Future.delayed(const Duration(seconds: 1));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const Home(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = localizations.authUserNotFound;
      } else if (e.code == 'wrong-password') {
        message = localizations.authWrongPassword;
      } else {
        message = localizations.authGenericError;
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
      throw e; // Re-throw the exception
    }
  }

  Future<void> signout(BuildContext context, AppLocalizations localizations) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
        (route) => false,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: localizations.authSignOutError,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.SNACKBAR,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    }
  }
}