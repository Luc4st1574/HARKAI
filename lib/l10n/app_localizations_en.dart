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
  String welcomeMessage(String name) {
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

  @override
  String get homeScreenLocationInfoText => 'This is happening in your area';

  @override
  String get homeMapLoadingText => 'Loading map data...';

  @override
  String get homeFireAlertButtonTitle => 'Fires';

  @override
  String get homeCrashAlertButtonTitle => 'Crashes';

  @override
  String get homeTheftAlertButtonTitle => 'Thefts';

  @override
  String get homePetAlertButtonTitle => 'Pets';

  @override
  String homeCallAgentButton(String agent) {
    return 'Call $agent';
  }

  @override
  String get homeCallEmergenciesButton => 'Call Emergencies';

  @override
  String get agentFirefighters => 'Firefighters';

  @override
  String get agentSerenazgo => 'Serenazgo';

  @override
  String get agentPolice => 'Police';

  @override
  String get agentShelter => 'Shelter';

  @override
  String get agentEmergencies => 'Emergencies';

  @override
  String get mapLoadingLocation => 'Loading location...';

  @override
  String get mapFetchingLocation => 'Fetching location...';

  @override
  String mapYouAreIn(String location) {
    return 'You are in $location';
  }

  @override
  String get mapinitialFetchingLocation => 'Initial location fetching...';

  @override
  String get mapCouldNotFetchAddress => 'Could not fetch address';

  @override
  String get mapFailedToGetInitialLocation => 'Failed to get initial location';

  @override
  String get mapLocationServicesDisabled => 'Location services are disabled.';

  @override
  String get mapLocationPermissionDenied => 'Location permission denied.';

  @override
  String mapErrorFetchingLocation(String error) {
    return 'Error fetching location: $error';
  }

  @override
  String get mapCurrentUserLocationNotAvailable =>
      'Current user location not available.';

  @override
  String incidentReportedSuccess(String incidentTitle) {
    return '$incidentTitle incident reported!';
  }

  @override
  String incidentReportFailed(String incidentTitle) {
    return 'Failed to report $incidentTitle incident.';
  }

  @override
  String get targetLocationNotSet =>
      'Target location not set. Tap on map or use compass.';

  @override
  String get emergencyReportLocationUnknown =>
      'Unable to report emergency: Target location unknown.';

  @override
  String get enlargedMapDataUnavailable =>
      'Map data is currently unavailable. Please try again.';

  @override
  String incidentModalStep1ReportAudioTitle(String incidentName) {
    return 'Step 1: Report Audio for $incidentName';
  }

  @override
  String get incidentModalStatusInitializing => 'Initializing...';

  @override
  String get incidentModalStatusRecordingAudio => 'Recording Audio...';

  @override
  String get incidentModalStatusAudioRecorded => 'Audio Recorded!';

  @override
  String get incidentModalStatusSendingAudioToHarki =>
      'Harki Analyzing Description...';

  @override
  String get incidentModalStatusConfirmAudioDescription =>
      'Confirm Description:';

  @override
  String get incidentModalStatusStep2AddImage => 'Step 2: Add Image (Optional)';

  @override
  String get incidentModalStatusCapturingImage => 'Step 2: Capturing Image...';

  @override
  String get incidentModalStatusImagePreview => 'Step 2: Image Preview';

  @override
  String get incidentModalStatusSendingImageToHarki =>
      'Harki Analyzing Image...';

  @override
  String get incidentModalStatusImageAnalyzed => 'Step 2: Image Analyzed';

  @override
  String get incidentModalStatusSubmittingIncident => 'Submitting Incident...';

  @override
  String get incidentModalStatusError => 'Error';

  @override
  String get incidentModalStatusTypeMismatch => 'Type Mismatch';

  @override
  String get incidentModalStatusInputUnclearInvalid => 'Input Unclear/Invalid';

  @override
  String get incidentModalStatusHarkiProcessingError =>
      'Harki Processing Error';

  @override
  String get incidentModalInstructionHoldMic =>
      'Hold Mic to record audio description.';

  @override
  String get incidentModalInstructionMicPermissionNeeded =>
      'Mic permission needed. Tap Mic to check/grant or grant in settings.';

  @override
  String get incidentModalInstructionHarkiInitializing =>
      'Harki AI is initializing. Please wait or tap Mic to retry.';

  @override
  String get incidentModalInstructionMicPermAndHarkiInit =>
      'Mic permission needed & Harki AI initializing. Tap Mic to proceed.';

  @override
  String get incidentModalInstructionReleaseMic => 'Release Mic to stop.';

  @override
  String get incidentModalInstructionSendAudioToHarki =>
      'Tap \"Send Audio to Harki\" for analysis.';

  @override
  String get incidentModalInstructionPleaseWait => 'Please wait.';

  @override
  String incidentModalInstructionConfirmAudio(String audioDescription) {
    return 'Harki suggests: \"$audioDescription\".\nIs this correct?';
  }

  @override
  String incidentModalInstructionAddImageOrSubmit(
    String confirmedAudioDescription,
  ) {
    return 'Confirmed Audio: \"$confirmedAudioDescription\"\nAdd an image or submit with description only.';
  }

  @override
  String get incidentModalInstructionUseCamera =>
      'Please use the camera to capture an image.';

  @override
  String get incidentModalInstructionAnalyzeRetakeRemoveImage =>
      'Analyze this image with Harki, retake it, or remove it to proceed with audio only.';

  @override
  String get incidentModalInstructionImageApproved =>
      'Image approved by Harki!\nSubmit with current details, retake image, or remove image.';

  @override
  String incidentModalInstructionImageFeedback(String imageFeedback) {
    return 'Image Feedback from Harki: $imageFeedback\nSubmit with current details, retake image, or remove image.';
  }

  @override
  String get incidentModalInstructionUploadingMedia =>
      'Uploading media, please wait.';

  @override
  String get incidentModalErrorMicPermissionRequired =>
      'Microphone permission is required for audio recording. Please grant it in settings or restart the report process.';

  @override
  String get incidentModalErrorFailedToInitHarki =>
      'Failed to initialize Harki AI. Media processing unavailable.';

  @override
  String get incidentModalErrorMicNotGranted =>
      'Microphone permission not granted. Cannot record audio.';

  @override
  String get incidentModalErrorHarkiNotReadyAudio =>
      'Harki AI is not ready. Cannot process audio.';

  @override
  String get incidentModalErrorCouldNotStartRecording =>
      'Could not start recording. Please ensure microphone is available.';

  @override
  String get incidentModalErrorAudioEmptyNotSaved =>
      'Audio recording seems empty or was not saved correctly. Please try again.';

  @override
  String get incidentModalErrorNoAudioOrHarkiNotReady =>
      'No audio recorded or Harki AI not ready.';

  @override
  String incidentModalErrorHarkiAudioResponseFormatUnexpected(
    String responseText,
  ) {
    return 'Harki AI audio response format was unexpected: $responseText. Please review or retry.';
  }

  @override
  String get incidentModalErrorHarkiNoActionableTextAudio =>
      'Harki AI returned no actionable text for audio.';

  @override
  String incidentModalErrorHarkiAudioProcessingFailed(String error) {
    return 'Harki AI audio processing failed: $error';
  }

  @override
  String get incidentModalErrorNoAudioToConfirm =>
      'No audio description to confirm.';

  @override
  String get incidentModalErrorHarkiNotReadyImage =>
      'Harki AI is not ready. Cannot process image.';

  @override
  String get incidentModalErrorNoImageOrHarkiNotReady =>
      'No image captured or Harki AI not ready.';

  @override
  String get incidentModalErrorHarkiNoActionableTextImage =>
      'Harki AI returned no actionable text for image.';

  @override
  String incidentModalErrorHarkiImageProcessingFailed(String error) {
    return 'Harki AI image processing failed: $error';
  }

  @override
  String get incidentModalErrorUserNotLoggedIn =>
      'User not logged in. Cannot submit incident.';

  @override
  String get incidentModalErrorFailedToUploadImage =>
      'Failed to upload image. Please try again or submit without image.';

  @override
  String get incidentModalErrorNoConfirmedAudioDescription =>
      'No confirmed audio description available. Please complete audio step first.';

  @override
  String get incidentModalButtonHoldToRecordReleaseToStop =>
      'Hold to record, release to stop.';

  @override
  String get incidentModalButtonSendAudioToHarki => 'Send Audio to Harki';

  @override
  String get incidentModalButtonConfirmAudioAndProceed => 'Confirm & Proceed';

  @override
  String get incidentModalButtonRerecordAudio => 'Re-record Audio';

  @override
  String get incidentModalButtonSubmitWithAudioOnly =>
      'Submit with Description Only';

  @override
  String get incidentModalButtonAddPicture => 'Add Picture';

  @override
  String get incidentModalButtonRetakePicture => 'Retake Picture';

  @override
  String get incidentModalButtonAnalyzeImageWithHarki =>
      'Analyze Image with Harki';

  @override
  String get incidentModalButtonUseAudioOnlyRemoveImage =>
      'Use Audio Only (Remove Image)';

  @override
  String get incidentModalButtonSubmitWithAudioAndImage =>
      'Submit with Audio & Image';

  @override
  String get incidentModalButtonSubmitAudioOnlyInstead =>
      'Submit Audio Only Instead';

  @override
  String get incidentModalButtonTryAgainFromStart => 'Try Again from Start';

  @override
  String get incidentModalButtonCancelReport => 'Cancel Report';

  @override
  String get incidentModalImageForIncident => 'Image for Incident:';

  @override
  String get incidentModalImageRemoveTooltip => 'Remove Image';

  @override
  String get incidentModalImageHarkiLooksGood => 'Harki: Image looks good!';

  @override
  String incidentModalImageHarkiFeedback(String feedback) {
    return 'Harki: $feedback';
  }

  @override
  String get incidentModalImageHarkiAnalysisComplete =>
      'Harki: Analysis complete.';

  @override
  String get incidentModalAudioConfirmedAudio => 'Confirmed Audio:';

  @override
  String get incidentImageModalDescriptionLabel => 'Description:';

  @override
  String get incidentImageModalNoImage => 'No image for this incident.';

  @override
  String get incidentImageModalNoAdditionalDescription =>
      'No additional description provided for the image.';

  @override
  String get incidentImageModalCloseButton => 'Close';

  @override
  String get incidentImageModalImageUnavailable => 'Image unavailable';

  @override
  String get locationServiceDisabled => 'Location services are disabled.';

  @override
  String get locationServicePermissionDenied => 'Location permission denied.';

  @override
  String get locationServicePermissionPermanentlyDenied =>
      'Location permissions are permanently denied. Please enable them in app settings.';

  @override
  String locationServiceFailedToGetLocation(String error) {
    return 'Failed to get location: $error';
  }

  @override
  String locationServiceGeocodingApiError(String status, String errorMessage) {
    return 'Error from Geocoding API: $status - $errorMessage';
  }

  @override
  String get locationServiceGeocodingFailedDefault =>
      'Failed to fetch address (API status not OK)';

  @override
  String get locationServiceGeocodingNoResults =>
      'No address results found for the given coordinates.';

  @override
  String locationServiceGeocodingLocationLatLonNoAddress(
    String latitude,
    String longitude,
  ) {
    return 'Location: $latitude, $longitude (No address found)';
  }

  @override
  String locationServiceGeocodingLocationLatLonComponentsNotFound(
    String latitude,
    String longitude,
  ) {
    return 'Location: $latitude, $longitude (Address components not found)';
  }

  @override
  String locationServiceGeocodingErrorGeneric(String error) {
    return 'Geocoding error: $error';
  }

  @override
  String get phoneServicePermissionDenied =>
      'Permission denied to make calls. Please enable it in settings.';

  @override
  String phoneServiceCouldNotLaunchDialer(String error) {
    return 'Could not launch dialer: $error';
  }

  @override
  String incidentScreenTitle(String incidentType) {
    return '$incidentType Near You';
  }

  @override
  String incidentFeedNoIncidentsFound(String incidentType) {
    return 'No $incidentType incidents found nearby at the moment.';
  }

  @override
  String get incidentTileDefaultTitle => 'Incident Reported';

  @override
  String incidentTileDistanceMeters(String distance) {
    return '${distance}m away';
  }

  @override
  String incidentTileDistanceKm(String distance) {
    return '${distance}km away';
  }

  @override
  String incidentMapViewTitle(String incidentType) {
    return 'Location of $incidentType';
  }

  @override
  String get incidentMapViewIncidentExpired =>
      'This incident report has expired or is no longer visible.';

  @override
  String get placesScreenTitle => 'Places';

  @override
  String get addPlaceButtonTitle => 'Place';

  @override
  String get placeMarkerName => 'Place';

  @override
  String paymentRequiredMessage(String amount) {
    return 'A \$$amount payment is required to add this place.';
  }

  @override
  String get paymentProcessingMessage => 'Processing payment...';

  @override
  String get paymentSuccessfulMessage => 'Payment successful! Place added.';

  @override
  String get paymentFailedMessage => 'Payment failed. Please try again.';

  @override
  String get photoRequiredMessage => 'A photo is mandatory to add a place.';

  @override
  String get placesIncidentFeedTitle => 'Nearby Places';

  @override
  String get buttonAddPlace => 'Add Place';

  @override
  String get hintSearch => 'Search by description...';

  @override
  String get searchNoResults => 'No description match your search';

  @override
  String get mapMarkerTooFar =>
      'The marker is too far from your current location.';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Harkai!';

  @override
  String get onboardingWelcomeDescription =>
      'Meet Harki, your personal AI assistant. Harki can help you with safety tips and guide you through the app\'s features.';

  @override
  String get onboardingIncidentsTitle => 'Reporting Incidents';

  @override
  String get onboardingIncidentsDescription =>
      'Tap an incident button (like \'Fire\' or \'Theft\') to report something at a specific location. Long-press the button to see a feed of recent, nearby incidents of that type.';

  @override
  String get onboardingMapTitle => 'Pinpointing Locations';

  @override
  String get onboardingMapDescription =>
      'To report an incident, first tap on the map to place the target marker precisely where the event is happening. You can also tap the compass icon to center it on your current location.';

  @override
  String get onboardingGotIt => 'Got it!';

  @override
  String get onboardingNext => 'Next';

  @override
  String get authWeakPassword => 'The password provided is too weak.';

  @override
  String get authEmailInUse => 'The account already exists for that email.';

  @override
  String get authInvalidEmail => 'The email address is not valid.';

  @override
  String get authGenericError => 'An error occurred. Please try again.';

  @override
  String get authUserNotFound => 'No user found for that email.';

  @override
  String get authWrongPassword => 'Wrong password provided for that user.';

  @override
  String get authSignOutError => 'Error signing out. Please try again.';

  @override
  String get profileLogoutMessage =>
      'The user has been logged out successfully.';

  @override
  String get notifFireNearbyTitle => 'Fire Nearby';

  @override
  String get notifFireNearbyBody =>
      'Warning, there is a fire nearby. Please be cautious.';

  @override
  String get notifFireDangerTitle => 'Danger: Fire Ahead';

  @override
  String get notifFireDangerBody =>
      'You are getting very close to the fire. Avoid the area for your safety.';

  @override
  String get notifTheftAlertTitle => 'Theft Alert';

  @override
  String get notifTheftAlertBody =>
      'A theft has been reported nearby. Please be aware of your surroundings.';

  @override
  String get notifTheftSecurityTitle => 'Security Alert';

  @override
  String get notifTheftSecurityBody =>
      'You are very close to a reported theft. Avoid the area and stay safe.';

  @override
  String get notifGenericIncidentTitle => 'Incident Nearby';

  @override
  String get notifGenericIncidentBody =>
      'Take a look around and see if you can help.';

  @override
  String get notifPlaceDiscoveryTitle => 'Discover a New Place';

  @override
  String notifPlaceDiscoveryBody(String placeName) {
    return 'Hey, you are near $placeName! We think you should check it out.';
  }

  @override
  String get notifPlaceAlmostThereTitle => 'You\'re Almost There!';

  @override
  String notifPlaceAlmostThereBody(String placeName) {
    return 'You\'re getting closer to $placeName. Enjoy your visit!';
  }

  @override
  String get notifPlaceWelcomeTitle => 'Welcome!';

  @override
  String notifPlaceWelcomeBody(String placeName) {
    return 'We are glad you came to $placeName. We hope you enjoy your time here!';
  }

  @override
  String incidentModalReportTextTitle(String incidentName) {
    return 'Step 1: Report with Text for $incidentName';
  }

  @override
  String get incidentModalInstructionEnterText =>
      'Please describe the incident in the text box below.';

  @override
  String get incidentModalButtonSendTextToHarki => 'Send Text to Harki';

  @override
  String get incidentModalButtonEnterTextInstead => 'Enter Text Instead';

  @override
  String get onboardingLocationTitle => 'Always-On Location';

  @override
  String get onboardingLocationDescription =>
      'To keep you safe and provide real-time alerts about nearby incidents even when the app is in the background, Harkai needs to access your location at all times. Please grant this permission on applications settings.';

  @override
  String get addplaceTitle => 'Add a Place to Harkai Map';

  @override
  String get incidentModalButtonAddFromGallery => 'Add from Gallery';

  @override
  String get addplaceInfo =>
      'To add a new place, please complete the payment below.';
}
