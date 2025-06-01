import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Harkai'**
  String get appTitle;

  /// No description provided for @helloWorld.
  ///
  /// In en, this message translates to:
  /// **'Hello World!'**
  String get helloWorld;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String welcomeMessage(Object name);

  /// No description provided for @firebaseInitError.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize Firebase. Please restart the app.'**
  String get firebaseInitError;

  /// No description provided for @splashWelcome.
  ///
  /// In en, this message translates to:
  /// **'WELCOME TO HARKAI'**
  String get splashWelcome;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'REGISTER'**
  String get registerTitle;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameHint;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'SIGN UP'**
  String get signUpButton;

  /// No description provided for @signUpWithGoogleButton.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Google'**
  String get signUpWithGoogleButton;

  /// No description provided for @alreadyHaveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccountPrompt;

  /// No description provided for @logInLink.
  ///
  /// In en, this message translates to:
  /// **'LOG IN'**
  String get logInLink;

  /// No description provided for @googleSignInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In successful!'**
  String get googleSignInSuccess;

  /// No description provided for @googleSignInErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign in with Google: '**
  String get googleSignInErrorPrefix;

  /// No description provided for @emailSignupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signup successful!'**
  String get emailSignupSuccess;

  /// No description provided for @emailSignupErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign up: '**
  String get emailSignupErrorPrefix;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get profileTitle;

  /// No description provided for @profileDefaultUsername.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileDefaultUsername;

  /// No description provided for @profileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// No description provided for @profileValueNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get profileValueNotAvailable;

  /// No description provided for @profilePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get profilePasswordLabel;

  /// No description provided for @profilePasswordHiddenText.
  ///
  /// In en, this message translates to:
  /// **'password hidden'**
  String get profilePasswordHiddenText;

  /// No description provided for @profileChangePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profileChangePasswordButton;

  /// No description provided for @profileBlockCardsButton.
  ///
  /// In en, this message translates to:
  /// **'Block Cards'**
  String get profileBlockCardsButton;

  /// No description provided for @profileLogoutButton.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profileLogoutButton;

  /// No description provided for @profileDialerErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error launching dialer: '**
  String get profileDialerErrorPrefix;

  /// No description provided for @profilePhonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied to make calls'**
  String get profilePhonePermissionDenied;

  /// No description provided for @profileResetPasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get profileResetPasswordDialogTitle;

  /// No description provided for @profileResetPasswordDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset your password?'**
  String get profileResetPasswordDialogContent;

  /// No description provided for @profileDialogNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get profileDialogNo;

  /// No description provided for @profileDialogYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get profileDialogYes;

  /// No description provided for @profilePasswordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent!'**
  String get profilePasswordResetEmailSent;

  /// No description provided for @profileNoEmailForPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'No email found for password reset!'**
  String get profileNoEmailForPasswordReset;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get loginTitle;

  /// No description provided for @loginForgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get loginForgotPasswordLink;

  /// No description provided for @loginSignInButton.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get loginSignInButton;

  /// No description provided for @loginSignInWithGoogleButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginSignInWithGoogleButton;

  /// No description provided for @loginDontHaveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get loginDontHaveAccountPrompt;

  /// No description provided for @loginForgotPasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get loginForgotPasswordDialogTitle;

  /// No description provided for @loginForgotPasswordDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a password reset link:'**
  String get loginForgotPasswordDialogContent;

  /// No description provided for @loginSendButton.
  ///
  /// In en, this message translates to:
  /// **'SEND'**
  String get loginSendButton;

  /// No description provided for @loginPasswordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent.'**
  String get loginPasswordResetEmailSent;

  /// No description provided for @commonErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: '**
  String get commonErrorPrefix;

  /// No description provided for @loginEmptyFieldsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email and password.'**
  String get loginEmptyFieldsPrompt;

  /// No description provided for @loginFailedErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Login failed: '**
  String get loginFailedErrorPrefix;

  /// No description provided for @chatApiKeyNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'API Key for Harki AI is not configured. Please check your .env file.'**
  String get chatApiKeyNotConfigured;

  /// No description provided for @chatHarkiAiInitializedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Harki AI Initialized.'**
  String get chatHarkiAiInitializedSuccess;

  /// No description provided for @chatHarkiAiInitFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize Harki AI. Check API Key and network. Error: '**
  String get chatHarkiAiInitFailedPrefix;

  /// No description provided for @chatHarkiAiNotInitializedOnSend.
  ///
  /// In en, this message translates to:
  /// **'Harki AI is not initialized. Please wait or check API key & network.'**
  String get chatHarkiAiNotInitializedOnSend;

  /// No description provided for @chatSessionNotStartedOnSend.
  ///
  /// In en, this message translates to:
  /// **'Chat session not started. Please try re-initializing.'**
  String get chatSessionNotStartedOnSend;

  /// No description provided for @chatHarkiAiEmptyResponse.
  ///
  /// In en, this message translates to:
  /// **'Harki AI returned an empty response.'**
  String get chatHarkiAiEmptyResponse;

  /// No description provided for @chatHarkiAiEmptyResponseFallbackMessage.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I didn\'t get a response. Please try again.'**
  String get chatHarkiAiEmptyResponseFallbackMessage;

  /// No description provided for @chatSendMessageFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message to Harki AI. Error: '**
  String get chatSendMessageFailedPrefix;

  /// No description provided for @chatSendMessageErrorFallbackMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: Could not get a response from Harki.'**
  String get chatSendMessageErrorFallbackMessage;

  /// No description provided for @chatScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Harki AI Chat'**
  String get chatScreenTitle;

  /// No description provided for @chatInitializingHarkiAiText.
  ///
  /// In en, this message translates to:
  /// **'Initializing Harki AI...'**
  String get chatInitializingHarkiAiText;

  /// No description provided for @chatHarkiIsTypingText.
  ///
  /// In en, this message translates to:
  /// **'Harki is typing...'**
  String get chatHarkiIsTypingText;

  /// No description provided for @chatMessageHintReady.
  ///
  /// In en, this message translates to:
  /// **'Message Harki...'**
  String get chatMessageHintReady;

  /// No description provided for @chatMessageHintInitializing.
  ///
  /// In en, this message translates to:
  /// **'Harki AI is initializing...'**
  String get chatMessageHintInitializing;

  /// No description provided for @chatSenderNameHarki.
  ///
  /// In en, this message translates to:
  /// **'Harki'**
  String get chatSenderNameHarki;

  /// No description provided for @chatSenderNameUserFallback.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get chatSenderNameUserFallback;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
