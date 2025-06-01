// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Harkai';

  @override
  String get helloWorld => 'Hello World!';

  @override
  String welcomeMessage(Object name) {
    return 'Welcome, $name!';
  }

  @override
  String get firebaseInitError =>
      'Failed to initialize Firebase. Please restart the app.';

  @override
  String get splashWelcome => 'WELCOME TO HARKAI';

  @override
  String get registerTitle => 'REGISTER';

  @override
  String get usernameHint => 'Username';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get signUpButton => 'SIGN UP';

  @override
  String get signUpWithGoogleButton => 'Sign up with Google';

  @override
  String get alreadyHaveAccountPrompt => 'Already have an account? ';

  @override
  String get logInLink => 'LOG IN';

  @override
  String get googleSignInSuccess => 'Google Sign-In successful!';

  @override
  String get googleSignInErrorPrefix => 'Failed to sign in with Google: ';

  @override
  String get emailSignupSuccess => 'Signup successful!';

  @override
  String get emailSignupErrorPrefix => 'Failed to sign up: ';

  @override
  String get profileTitle => 'User Profile';

  @override
  String get profileDefaultUsername => 'User';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profileValueNotAvailable => 'N/A';

  @override
  String get profilePasswordLabel => 'Password';

  @override
  String get profilePasswordHiddenText => 'password hidden';

  @override
  String get profileChangePasswordButton => 'Change Password';

  @override
  String get profileBlockCardsButton => 'Block Cards';

  @override
  String get profileLogoutButton => 'Logout';

  @override
  String get profileDialerErrorPrefix => 'Error launching dialer: ';

  @override
  String get profilePhonePermissionDenied => 'Permission denied to make calls';

  @override
  String get profileResetPasswordDialogTitle => 'Reset Password';

  @override
  String get profileResetPasswordDialogContent =>
      'Are you sure you want to reset your password?';

  @override
  String get profileDialogNo => 'No';

  @override
  String get profileDialogYes => 'Yes';

  @override
  String get profilePasswordResetEmailSent => 'Password reset email sent!';

  @override
  String get profileNoEmailForPasswordReset =>
      'No email found for password reset!';

  @override
  String get loginTitle => 'LOGIN';

  @override
  String get loginForgotPasswordLink => 'Forgot Password?';

  @override
  String get loginSignInButton => 'SIGN IN';

  @override
  String get loginSignInWithGoogleButton => 'Sign in with Google';

  @override
  String get loginDontHaveAccountPrompt => 'Don\'t have an account? ';

  @override
  String get loginForgotPasswordDialogTitle => 'Forgot Password';

  @override
  String get loginForgotPasswordDialogContent =>
      'Enter your email to receive a password reset link:';

  @override
  String get loginSendButton => 'SEND';

  @override
  String get loginPasswordResetEmailSent => 'Password reset email sent.';

  @override
  String get commonErrorPrefix => 'Error: ';

  @override
  String get loginEmptyFieldsPrompt => 'Please enter your email and password.';

  @override
  String get loginFailedErrorPrefix => 'Login failed: ';

  @override
  String get chatApiKeyNotConfigured =>
      'API Key for Harki AI is not configured. Please check your .env file.';

  @override
  String get chatHarkiAiInitializedSuccess => 'Harki AI Initialized.';

  @override
  String get chatHarkiAiInitFailedPrefix =>
      'Failed to initialize Harki AI. Check API Key and network. Error: ';

  @override
  String get chatHarkiAiNotInitializedOnSend =>
      'Harki AI is not initialized. Please wait or check API key & network.';

  @override
  String get chatSessionNotStartedOnSend =>
      'Chat session not started. Please try re-initializing.';

  @override
  String get chatHarkiAiEmptyResponse => 'Harki AI returned an empty response.';

  @override
  String get chatHarkiAiEmptyResponseFallbackMessage =>
      'Sorry, I didn\'t get a response. Please try again.';

  @override
  String get chatSendMessageFailedPrefix =>
      'Failed to send message to Harki AI. Error: ';

  @override
  String get chatSendMessageErrorFallbackMessage =>
      'Error: Could not get a response from Harki.';

  @override
  String get chatScreenTitle => 'Harki AI Chat';

  @override
  String get chatInitializingHarkiAiText => 'Initializing Harki AI...';

  @override
  String get chatHarkiIsTypingText => 'Harki is typing...';

  @override
  String get chatMessageHintReady => 'Message Harki...';

  @override
  String get chatMessageHintInitializing => 'Harki AI is initializing...';

  @override
  String get chatSenderNameHarki => 'Harki';

  @override
  String get chatSenderNameUserFallback => 'You';
}
