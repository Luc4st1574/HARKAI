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

  /// A welcome message with a placeholder for the user's name.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String welcomeMessage(String name);

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

  /// No description provided for @homeScreenLocationInfoText.
  ///
  /// In en, this message translates to:
  /// **'This is happening in your area'**
  String get homeScreenLocationInfoText;

  /// No description provided for @homeMapLoadingText.
  ///
  /// In en, this message translates to:
  /// **'Loading map data...'**
  String get homeMapLoadingText;

  /// No description provided for @homeFireAlertButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Fires'**
  String get homeFireAlertButtonTitle;

  /// No description provided for @homeCrashAlertButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Crashes'**
  String get homeCrashAlertButtonTitle;

  /// No description provided for @homeTheftAlertButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Thefts'**
  String get homeTheftAlertButtonTitle;

  /// No description provided for @homePetAlertButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get homePetAlertButtonTitle;

  /// No description provided for @homeCallAgentButton.
  ///
  /// In en, this message translates to:
  /// **'Call {agent}'**
  String homeCallAgentButton(String agent);

  /// No description provided for @homeCallEmergenciesButton.
  ///
  /// In en, this message translates to:
  /// **'Call Emergencies'**
  String get homeCallEmergenciesButton;

  /// No description provided for @agentFirefighters.
  ///
  /// In en, this message translates to:
  /// **'Firefighters'**
  String get agentFirefighters;

  /// No description provided for @agentSerenazgo.
  ///
  /// In en, this message translates to:
  /// **'Serenazgo'**
  String get agentSerenazgo;

  /// No description provided for @agentPolice.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get agentPolice;

  /// No description provided for @agentShelter.
  ///
  /// In en, this message translates to:
  /// **'Shelter'**
  String get agentShelter;

  /// No description provided for @agentEmergencies.
  ///
  /// In en, this message translates to:
  /// **'Emergencies'**
  String get agentEmergencies;

  /// No description provided for @mapLoadingLocation.
  ///
  /// In en, this message translates to:
  /// **'Loading location...'**
  String get mapLoadingLocation;

  /// No description provided for @mapFetchingLocation.
  ///
  /// In en, this message translates to:
  /// **'Fetching location...'**
  String get mapFetchingLocation;

  /// No description provided for @mapYouAreIn.
  ///
  /// In en, this message translates to:
  /// **'You are in {location}'**
  String mapYouAreIn(String location);

  /// No description provided for @mapinitialFetchingLocation.
  ///
  /// In en, this message translates to:
  /// **'Initial location fetching...'**
  String get mapinitialFetchingLocation;

  /// No description provided for @mapCouldNotFetchAddress.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch address'**
  String get mapCouldNotFetchAddress;

  /// No description provided for @mapFailedToGetInitialLocation.
  ///
  /// In en, this message translates to:
  /// **'Failed to get initial location'**
  String get mapFailedToGetInitialLocation;

  /// No description provided for @mapLocationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled.'**
  String get mapLocationServicesDisabled;

  /// No description provided for @mapLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get mapLocationPermissionDenied;

  /// No description provided for @mapErrorFetchingLocation.
  ///
  /// In en, this message translates to:
  /// **'Error fetching location: {error}'**
  String mapErrorFetchingLocation(String error);

  /// No description provided for @mapCurrentUserLocationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Current user location not available.'**
  String get mapCurrentUserLocationNotAvailable;

  /// No description provided for @incidentReportedSuccess.
  ///
  /// In en, this message translates to:
  /// **'{incidentTitle} incident reported!'**
  String incidentReportedSuccess(String incidentTitle);

  /// No description provided for @incidentReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to report {incidentTitle} incident.'**
  String incidentReportFailed(String incidentTitle);

  /// No description provided for @targetLocationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Target location not set. Tap on map or use compass.'**
  String get targetLocationNotSet;

  /// No description provided for @emergencyReportLocationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unable to report emergency: Target location unknown.'**
  String get emergencyReportLocationUnknown;

  /// No description provided for @enlargedMapDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map data is currently unavailable. Please try again.'**
  String get enlargedMapDataUnavailable;

  /// No description provided for @incidentModalStep1ReportAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Report Audio for {incidentName}'**
  String incidentModalStep1ReportAudioTitle(String incidentName);

  /// No description provided for @incidentModalStatusInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing...'**
  String get incidentModalStatusInitializing;

  /// No description provided for @incidentModalStatusRecordingAudio.
  ///
  /// In en, this message translates to:
  /// **'Recording Audio...'**
  String get incidentModalStatusRecordingAudio;

  /// No description provided for @incidentModalStatusAudioRecorded.
  ///
  /// In en, this message translates to:
  /// **'Audio Recorded!'**
  String get incidentModalStatusAudioRecorded;

  /// No description provided for @incidentModalStatusSendingAudioToHarki.
  ///
  /// In en, this message translates to:
  /// **'Harki Analyzing Description...'**
  String get incidentModalStatusSendingAudioToHarki;

  /// No description provided for @incidentModalStatusConfirmAudioDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm Description:'**
  String get incidentModalStatusConfirmAudioDescription;

  /// No description provided for @incidentModalStatusStep2AddImage.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Add Image (Optional)'**
  String get incidentModalStatusStep2AddImage;

  /// No description provided for @incidentModalStatusCapturingImage.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Capturing Image...'**
  String get incidentModalStatusCapturingImage;

  /// No description provided for @incidentModalStatusImagePreview.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Image Preview'**
  String get incidentModalStatusImagePreview;

  /// No description provided for @incidentModalStatusSendingImageToHarki.
  ///
  /// In en, this message translates to:
  /// **'Harki Analyzing Image...'**
  String get incidentModalStatusSendingImageToHarki;

  /// No description provided for @incidentModalStatusImageAnalyzed.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Image Analyzed'**
  String get incidentModalStatusImageAnalyzed;

  /// No description provided for @incidentModalStatusSubmittingIncident.
  ///
  /// In en, this message translates to:
  /// **'Submitting Incident...'**
  String get incidentModalStatusSubmittingIncident;

  /// No description provided for @incidentModalStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get incidentModalStatusError;

  /// No description provided for @incidentModalStatusTypeMismatch.
  ///
  /// In en, this message translates to:
  /// **'Type Mismatch'**
  String get incidentModalStatusTypeMismatch;

  /// No description provided for @incidentModalStatusInputUnclearInvalid.
  ///
  /// In en, this message translates to:
  /// **'Input Unclear/Invalid'**
  String get incidentModalStatusInputUnclearInvalid;

  /// No description provided for @incidentModalStatusHarkiProcessingError.
  ///
  /// In en, this message translates to:
  /// **'Harki Processing Error'**
  String get incidentModalStatusHarkiProcessingError;

  /// No description provided for @incidentModalInstructionHoldMic.
  ///
  /// In en, this message translates to:
  /// **'Hold Mic to record audio description.'**
  String get incidentModalInstructionHoldMic;

  /// No description provided for @incidentModalInstructionMicPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Mic permission needed. Tap Mic to check/grant or grant in settings.'**
  String get incidentModalInstructionMicPermissionNeeded;

  /// No description provided for @incidentModalInstructionHarkiInitializing.
  ///
  /// In en, this message translates to:
  /// **'Harki AI is initializing. Please wait or tap Mic to retry.'**
  String get incidentModalInstructionHarkiInitializing;

  /// No description provided for @incidentModalInstructionMicPermAndHarkiInit.
  ///
  /// In en, this message translates to:
  /// **'Mic permission needed & Harki AI initializing. Tap Mic to proceed.'**
  String get incidentModalInstructionMicPermAndHarkiInit;

  /// No description provided for @incidentModalInstructionReleaseMic.
  ///
  /// In en, this message translates to:
  /// **'Release Mic to stop.'**
  String get incidentModalInstructionReleaseMic;

  /// No description provided for @incidentModalInstructionSendAudioToHarki.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Send Audio to Harki\" for analysis.'**
  String get incidentModalInstructionSendAudioToHarki;

  /// No description provided for @incidentModalInstructionPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait.'**
  String get incidentModalInstructionPleaseWait;

  /// No description provided for @incidentModalInstructionConfirmAudio.
  ///
  /// In en, this message translates to:
  /// **'Harki suggests: \"{audioDescription}\".\nIs this correct?'**
  String incidentModalInstructionConfirmAudio(String audioDescription);

  /// No description provided for @incidentModalInstructionAddImageOrSubmit.
  ///
  /// In en, this message translates to:
  /// **'Confirmed Audio: \"{confirmedAudioDescription}\"\nAdd an image or submit with description only.'**
  String incidentModalInstructionAddImageOrSubmit(
      String confirmedAudioDescription);

  /// No description provided for @incidentModalInstructionUseCamera.
  ///
  /// In en, this message translates to:
  /// **'Please use the camera to capture an image.'**
  String get incidentModalInstructionUseCamera;

  /// No description provided for @incidentModalInstructionAnalyzeRetakeRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Analyze this image with Harki, retake it, or remove it to proceed with audio only.'**
  String get incidentModalInstructionAnalyzeRetakeRemoveImage;

  /// No description provided for @incidentModalInstructionImageApproved.
  ///
  /// In en, this message translates to:
  /// **'Image approved by Harki!\nSubmit with current details, retake image, or remove image.'**
  String get incidentModalInstructionImageApproved;

  /// No description provided for @incidentModalInstructionImageFeedback.
  ///
  /// In en, this message translates to:
  /// **'Image Feedback from Harki: {imageFeedback}\nSubmit with current details, retake image, or remove image.'**
  String incidentModalInstructionImageFeedback(String imageFeedback);

  /// No description provided for @incidentModalInstructionUploadingMedia.
  ///
  /// In en, this message translates to:
  /// **'Uploading media, please wait.'**
  String get incidentModalInstructionUploadingMedia;

  /// No description provided for @incidentModalErrorMicPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for audio recording. Please grant it in settings or restart the report process.'**
  String get incidentModalErrorMicPermissionRequired;

  /// No description provided for @incidentModalErrorFailedToInitHarki.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize Harki AI. Media processing unavailable.'**
  String get incidentModalErrorFailedToInitHarki;

  /// No description provided for @incidentModalErrorMicNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission not granted. Cannot record audio.'**
  String get incidentModalErrorMicNotGranted;

  /// No description provided for @incidentModalErrorHarkiNotReadyAudio.
  ///
  /// In en, this message translates to:
  /// **'Harki AI is not ready. Cannot process audio.'**
  String get incidentModalErrorHarkiNotReadyAudio;

  /// No description provided for @incidentModalErrorCouldNotStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Could not start recording. Please ensure microphone is available.'**
  String get incidentModalErrorCouldNotStartRecording;

  /// No description provided for @incidentModalErrorAudioEmptyNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Audio recording seems empty or was not saved correctly. Please try again.'**
  String get incidentModalErrorAudioEmptyNotSaved;

  /// No description provided for @incidentModalErrorNoAudioOrHarkiNotReady.
  ///
  /// In en, this message translates to:
  /// **'No audio recorded or Harki AI not ready.'**
  String get incidentModalErrorNoAudioOrHarkiNotReady;

  /// No description provided for @incidentModalErrorHarkiAudioResponseFormatUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Harki AI audio response format was unexpected: {responseText}. Please review or retry.'**
  String incidentModalErrorHarkiAudioResponseFormatUnexpected(
      String responseText);

  /// No description provided for @incidentModalErrorHarkiNoActionableTextAudio.
  ///
  /// In en, this message translates to:
  /// **'Harki AI returned no actionable text for audio.'**
  String get incidentModalErrorHarkiNoActionableTextAudio;

  /// No description provided for @incidentModalErrorHarkiAudioProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Harki AI audio processing failed: {error}'**
  String incidentModalErrorHarkiAudioProcessingFailed(String error);

  /// No description provided for @incidentModalErrorNoAudioToConfirm.
  ///
  /// In en, this message translates to:
  /// **'No audio description to confirm.'**
  String get incidentModalErrorNoAudioToConfirm;

  /// No description provided for @incidentModalErrorHarkiNotReadyImage.
  ///
  /// In en, this message translates to:
  /// **'Harki AI is not ready. Cannot process image.'**
  String get incidentModalErrorHarkiNotReadyImage;

  /// No description provided for @incidentModalErrorNoImageOrHarkiNotReady.
  ///
  /// In en, this message translates to:
  /// **'No image captured or Harki AI not ready.'**
  String get incidentModalErrorNoImageOrHarkiNotReady;

  /// No description provided for @incidentModalErrorHarkiNoActionableTextImage.
  ///
  /// In en, this message translates to:
  /// **'Harki AI returned no actionable text for image.'**
  String get incidentModalErrorHarkiNoActionableTextImage;

  /// No description provided for @incidentModalErrorHarkiImageProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Harki AI image processing failed: {error}'**
  String incidentModalErrorHarkiImageProcessingFailed(String error);

  /// No description provided for @incidentModalErrorUserNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'User not logged in. Cannot submit incident.'**
  String get incidentModalErrorUserNotLoggedIn;

  /// No description provided for @incidentModalErrorFailedToUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload image. Please try again or submit without image.'**
  String get incidentModalErrorFailedToUploadImage;

  /// No description provided for @incidentModalErrorNoConfirmedAudioDescription.
  ///
  /// In en, this message translates to:
  /// **'No confirmed audio description available. Please complete audio step first.'**
  String get incidentModalErrorNoConfirmedAudioDescription;

  /// No description provided for @incidentModalButtonHoldToRecordReleaseToStop.
  ///
  /// In en, this message translates to:
  /// **'Hold to record, release to stop.'**
  String get incidentModalButtonHoldToRecordReleaseToStop;

  /// No description provided for @incidentModalButtonSendAudioToHarki.
  ///
  /// In en, this message translates to:
  /// **'Send Audio to Harki'**
  String get incidentModalButtonSendAudioToHarki;

  /// No description provided for @incidentModalButtonConfirmAudioAndProceed.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Proceed'**
  String get incidentModalButtonConfirmAudioAndProceed;

  /// No description provided for @incidentModalButtonRerecordAudio.
  ///
  /// In en, this message translates to:
  /// **'Re-record Audio'**
  String get incidentModalButtonRerecordAudio;

  /// No description provided for @incidentModalButtonSubmitWithAudioOnly.
  ///
  /// In en, this message translates to:
  /// **'Submit with Description Only'**
  String get incidentModalButtonSubmitWithAudioOnly;

  /// No description provided for @incidentModalButtonAddPicture.
  ///
  /// In en, this message translates to:
  /// **'Add Picture'**
  String get incidentModalButtonAddPicture;

  /// No description provided for @incidentModalButtonRetakePicture.
  ///
  /// In en, this message translates to:
  /// **'Retake Picture'**
  String get incidentModalButtonRetakePicture;

  /// No description provided for @incidentModalButtonAnalyzeImageWithHarki.
  ///
  /// In en, this message translates to:
  /// **'Analyze Image with Harki'**
  String get incidentModalButtonAnalyzeImageWithHarki;

  /// No description provided for @incidentModalButtonUseAudioOnlyRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Use Audio Only (Remove Image)'**
  String get incidentModalButtonUseAudioOnlyRemoveImage;

  /// No description provided for @incidentModalButtonSubmitWithAudioAndImage.
  ///
  /// In en, this message translates to:
  /// **'Submit with Audio & Image'**
  String get incidentModalButtonSubmitWithAudioAndImage;

  /// No description provided for @incidentModalButtonSubmitAudioOnlyInstead.
  ///
  /// In en, this message translates to:
  /// **'Submit Audio Only Instead'**
  String get incidentModalButtonSubmitAudioOnlyInstead;

  /// No description provided for @incidentModalButtonTryAgainFromStart.
  ///
  /// In en, this message translates to:
  /// **'Try Again from Start'**
  String get incidentModalButtonTryAgainFromStart;

  /// No description provided for @incidentModalButtonCancelReport.
  ///
  /// In en, this message translates to:
  /// **'Cancel Report'**
  String get incidentModalButtonCancelReport;

  /// No description provided for @incidentModalImageForIncident.
  ///
  /// In en, this message translates to:
  /// **'Image for Incident:'**
  String get incidentModalImageForIncident;

  /// No description provided for @incidentModalImageRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove Image'**
  String get incidentModalImageRemoveTooltip;

  /// No description provided for @incidentModalImageHarkiLooksGood.
  ///
  /// In en, this message translates to:
  /// **'Harki: Image looks good!'**
  String get incidentModalImageHarkiLooksGood;

  /// No description provided for @incidentModalImageHarkiFeedback.
  ///
  /// In en, this message translates to:
  /// **'Harki: {feedback}'**
  String incidentModalImageHarkiFeedback(String feedback);

  /// No description provided for @incidentModalImageHarkiAnalysisComplete.
  ///
  /// In en, this message translates to:
  /// **'Harki: Analysis complete.'**
  String get incidentModalImageHarkiAnalysisComplete;

  /// No description provided for @incidentModalAudioConfirmedAudio.
  ///
  /// In en, this message translates to:
  /// **'Confirmed Audio:'**
  String get incidentModalAudioConfirmedAudio;

  /// No description provided for @incidentImageModalDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description:'**
  String get incidentImageModalDescriptionLabel;

  /// No description provided for @incidentImageModalNoImage.
  ///
  /// In en, this message translates to:
  /// **'No image for this incident.'**
  String get incidentImageModalNoImage;

  /// No description provided for @incidentImageModalNoAdditionalDescription.
  ///
  /// In en, this message translates to:
  /// **'No additional description provided for the image.'**
  String get incidentImageModalNoAdditionalDescription;

  /// No description provided for @incidentImageModalCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get incidentImageModalCloseButton;

  /// No description provided for @incidentImageModalImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get incidentImageModalImageUnavailable;

  /// No description provided for @locationServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled.'**
  String get locationServiceDisabled;

  /// No description provided for @locationServicePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get locationServicePermissionDenied;

  /// No description provided for @locationServicePermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied. Please enable them in app settings.'**
  String get locationServicePermissionPermanentlyDenied;

  /// No description provided for @locationServiceFailedToGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Failed to get location: {error}'**
  String locationServiceFailedToGetLocation(String error);

  /// No description provided for @locationServiceGeocodingApiError.
  ///
  /// In en, this message translates to:
  /// **'Error from Geocoding API: {status} - {errorMessage}'**
  String locationServiceGeocodingApiError(String status, String errorMessage);

  /// No description provided for @locationServiceGeocodingFailedDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch address (API status not OK)'**
  String get locationServiceGeocodingFailedDefault;

  /// No description provided for @locationServiceGeocodingNoResults.
  ///
  /// In en, this message translates to:
  /// **'No address results found for the given coordinates.'**
  String get locationServiceGeocodingNoResults;

  /// No description provided for @locationServiceGeocodingLocationLatLonNoAddress.
  ///
  /// In en, this message translates to:
  /// **'Location: {latitude}, {longitude} (No address found)'**
  String locationServiceGeocodingLocationLatLonNoAddress(
      String latitude, String longitude);

  /// No description provided for @locationServiceGeocodingLocationLatLonComponentsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Location: {latitude}, {longitude} (Address components not found)'**
  String locationServiceGeocodingLocationLatLonComponentsNotFound(
      String latitude, String longitude);

  /// No description provided for @locationServiceGeocodingErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Geocoding error: {error}'**
  String locationServiceGeocodingErrorGeneric(String error);

  /// No description provided for @phoneServicePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied to make calls. Please enable it in settings.'**
  String get phoneServicePermissionDenied;

  /// No description provided for @phoneServiceCouldNotLaunchDialer.
  ///
  /// In en, this message translates to:
  /// **'Could not launch dialer: {error}'**
  String phoneServiceCouldNotLaunchDialer(String error);

  /// Title for the incident feed screen, takes incident type name.
  ///
  /// In en, this message translates to:
  /// **'{incidentType} Near You'**
  String incidentScreenTitle(String incidentType);

  /// Message shown when no incidents of a specific type are found.
  ///
  /// In en, this message translates to:
  /// **'No {incidentType} incidents found nearby at the moment.'**
  String incidentFeedNoIncidentsFound(String incidentType);

  /// No description provided for @incidentTileDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Incident Reported'**
  String get incidentTileDefaultTitle;

  /// Distance in meters for incident tile.
  ///
  /// In en, this message translates to:
  /// **'{distance}m away'**
  String incidentTileDistanceMeters(String distance);

  /// Distance in kilometers for incident tile.
  ///
  /// In en, this message translates to:
  /// **'{distance}km away'**
  String incidentTileDistanceKm(String distance);

  /// Title for the incident map view, takes incident type name.
  ///
  /// In en, this message translates to:
  /// **'Location of {incidentType}'**
  String incidentMapViewTitle(String incidentType);

  /// No description provided for @incidentMapViewIncidentExpired.
  ///
  /// In en, this message translates to:
  /// **'This incident report has expired or is no longer visible.'**
  String get incidentMapViewIncidentExpired;

  /// No description provided for @placesScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get placesScreenTitle;

  /// No description provided for @addPlaceButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get addPlaceButtonTitle;

  /// No description provided for @placeMarkerName.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get placeMarkerName;

  /// No description provided for @paymentRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'A \${amount} payment is required to add this place.'**
  String paymentRequiredMessage(String amount);

  /// No description provided for @paymentProcessingMessage.
  ///
  /// In en, this message translates to:
  /// **'Processing payment...'**
  String get paymentProcessingMessage;

  /// No description provided for @paymentSuccessfulMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment successful! Place added.'**
  String get paymentSuccessfulMessage;

  /// No description provided for @paymentFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please try again.'**
  String get paymentFailedMessage;

  /// No description provided for @photoRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'A photo is mandatory to add a place.'**
  String get photoRequiredMessage;

  /// No description provided for @placesIncidentFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby Places'**
  String get placesIncidentFeedTitle;

  /// No description provided for @buttonAddPlace.
  ///
  /// In en, this message translates to:
  /// **'Add Place'**
  String get buttonAddPlace;

  /// No description provided for @hintSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by description...'**
  String get hintSearch;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No description match your search'**
  String get searchNoResults;

  /// No description provided for @mapMarkerTooFar.
  ///
  /// In en, this message translates to:
  /// **'The marker is too far from your current location.'**
  String get mapMarkerTooFar;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Harkai!'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Meet Harki, your personal AI assistant. Harki can help you with safety tips and guide you through the app\'s features.'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingIncidentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reporting Incidents'**
  String get onboardingIncidentsTitle;

  /// No description provided for @onboardingIncidentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap an incident button (like \'Fire\' or \'Theft\') to report something at a specific location. Long-press the button to see a feed of recent, nearby incidents of that type.'**
  String get onboardingIncidentsDescription;

  /// No description provided for @onboardingMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinpointing Locations'**
  String get onboardingMapTitle;

  /// No description provided for @onboardingMapDescription.
  ///
  /// In en, this message translates to:
  /// **'To report an incident, first tap on the map to place the target marker precisely where the event is happening. You can also tap the compass icon to center it on your current location.'**
  String get onboardingMapDescription;

  /// No description provided for @onboardingGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get onboardingGotIt;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'The password provided is too weak.'**
  String get authWeakPassword;

  /// No description provided for @authEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'The account already exists for that email.'**
  String get authEmailInUse;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'The email address is not valid.'**
  String get authInvalidEmail;

  /// No description provided for @authGenericError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get authGenericError;

  /// No description provided for @authUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No user found for that email.'**
  String get authUserNotFound;

  /// No description provided for @authWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password provided for that user.'**
  String get authWrongPassword;

  /// No description provided for @authSignOutError.
  ///
  /// In en, this message translates to:
  /// **'Error signing out. Please try again.'**
  String get authSignOutError;

  /// No description provided for @profileLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The user has been logged out successfully.'**
  String get profileLogoutMessage;

  /// No description provided for @notifFireNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Fire Nearby'**
  String get notifFireNearbyTitle;

  /// No description provided for @notifFireNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'Warning, there is a fire nearby. Please be cautious.'**
  String get notifFireNearbyBody;

  /// No description provided for @notifFireDangerTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger: Fire Ahead'**
  String get notifFireDangerTitle;

  /// No description provided for @notifFireDangerBody.
  ///
  /// In en, this message translates to:
  /// **'You are getting very close to the fire. Avoid the area for your safety.'**
  String get notifFireDangerBody;

  /// No description provided for @notifTheftAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Theft Alert'**
  String get notifTheftAlertTitle;

  /// No description provided for @notifTheftAlertBody.
  ///
  /// In en, this message translates to:
  /// **'A theft has been reported nearby. Please be aware of your surroundings.'**
  String get notifTheftAlertBody;

  /// No description provided for @notifTheftSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Alert'**
  String get notifTheftSecurityTitle;

  /// No description provided for @notifTheftSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'You are very close to a reported theft. Avoid the area and stay safe.'**
  String get notifTheftSecurityBody;

  /// No description provided for @notifGenericIncidentTitle.
  ///
  /// In en, this message translates to:
  /// **'Incident Nearby'**
  String get notifGenericIncidentTitle;

  /// No description provided for @notifGenericIncidentBody.
  ///
  /// In en, this message translates to:
  /// **'Take a look around and see if you can help.'**
  String get notifGenericIncidentBody;

  /// No description provided for @notifPlaceDiscoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover a New Place'**
  String get notifPlaceDiscoveryTitle;

  /// No description provided for @notifPlaceDiscoveryBody.
  ///
  /// In en, this message translates to:
  /// **'Hey, you are near {placeName}! We think you should check it out.'**
  String notifPlaceDiscoveryBody(String placeName);

  /// No description provided for @notifPlaceAlmostThereTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re Almost There!'**
  String get notifPlaceAlmostThereTitle;

  /// No description provided for @notifPlaceAlmostThereBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re getting closer to {placeName}. Enjoy your visit!'**
  String notifPlaceAlmostThereBody(String placeName);

  /// No description provided for @notifPlaceWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get notifPlaceWelcomeTitle;

  /// No description provided for @notifPlaceWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'We are glad you came to {placeName}. We hope you enjoy your time here!'**
  String notifPlaceWelcomeBody(String placeName);

  /// Title for the incident reporting step when using text. Takes incident name as a parameter.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Report with Text for {incidentName}'**
  String incidentModalReportTextTitle(String incidentName);

  /// Instruction for the user to enter a text description for the incident.
  ///
  /// In en, this message translates to:
  /// **'Please describe the incident in the text box below.'**
  String get incidentModalInstructionEnterText;

  /// Button text to submit the text description for analysis.
  ///
  /// In en, this message translates to:
  /// **'Send Text to Harki'**
  String get incidentModalButtonSendTextToHarki;

  /// Button text for the option to switch to text input from the audio input.
  ///
  /// In en, this message translates to:
  /// **'Enter Text Instead'**
  String get incidentModalButtonEnterTextInstead;

  /// No description provided for @onboardingLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Always-On Location'**
  String get onboardingLocationTitle;

  /// No description provided for @onboardingLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'To keep you safe and provide real-time alerts about nearby incidents even when the app is in the background, Harkai needs to access your location at all times. Please grant this permission on applications settings.'**
  String get onboardingLocationDescription;

  /// No description provided for @addplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a Place to Harkai Map'**
  String get addplaceTitle;

  /// No description provided for @incidentModalButtonAddFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Add from Gallery'**
  String get incidentModalButtonAddFromGallery;

  /// No description provided for @addplaceInfo.
  ///
  /// In en, this message translates to:
  /// **'To add a new place, please complete the payment below.'**
  String get addplaceInfo;

  /// No description provided for @donationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Harkai'**
  String get donationSectionTitle;

  /// No description provided for @donationAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter donation amount'**
  String get donationAmountHint;

  /// No description provided for @donationButtonText.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donationButtonText;

  /// No description provided for @donationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Donation'**
  String get donationDialogTitle;

  /// No description provided for @donationDialogContent.
  ///
  /// In en, this message translates to:
  /// **'You are about to donate \${amount} to Harkai. Thank you for your support!'**
  String donationDialogContent(String amount);

  /// No description provided for @donationSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your generous donation!'**
  String get donationSuccessMessage;

  /// No description provided for @donationFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Donation cancelled or failed.'**
  String get donationFailedMessage;

  /// No description provided for @donationInvalidAmountMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid donation amount.'**
  String get donationInvalidAmountMessage;

  /// No description provided for @donationLabel.
  ///
  /// In en, this message translates to:
  /// **'Donation to Harkai'**
  String get donationLabel;

  /// No description provided for @nearbyVetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby Vets'**
  String get nearbyVetsTitle;

  /// No description provided for @noNearbyVetsFound.
  ///
  /// In en, this message translates to:
  /// **'No nearby vets registered as places were found in the area.'**
  String get noNearbyVetsFound;

  /// No description provided for @exitScreenButton.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitScreenButton;

  /// No description provided for @onboardingAlwaysOnLocationPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep You Safe Always'**
  String get onboardingAlwaysOnLocationPromptTitle;

  /// No description provided for @onboardingAlwaysOnLocationPromptDescription.
  ///
  /// In en, this message translates to:
  /// **'To keep you safe and provide real-time alerts about nearby incidents even when the app is in the background, Harkai needs to access your location at all times. Please grant this permission when prompted.'**
  String get onboardingAlwaysOnLocationPromptDescription;

  /// No description provided for @onboardingAlwaysOnLocationPromptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept & Continue'**
  String get onboardingAlwaysOnLocationPromptButton;
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
