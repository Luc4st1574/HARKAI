// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Harkai';

  @override
  String get helloWorld => '¡Hola Mundo!';

  @override
  String welcomeMessage(String name) {
    return '¡Bienvenido, $name!';
  }

  @override
  String get firebaseInitError =>
      'Fallo al inicializar Firebase. Por favor, reinicia la aplicación.';

  @override
  String get splashWelcome => 'BIENVENIDO A HARKAI';

  @override
  String get registerTitle => 'REGISTRARSE';

  @override
  String get usernameHint => 'Nombre de usuario';

  @override
  String get emailHint => 'Correo electrónico';

  @override
  String get passwordHint => 'Contraseña';

  @override
  String get signUpButton => 'REGISTRARSE';

  @override
  String get signUpWithGoogleButton => 'Registrarse con Google';

  @override
  String get alreadyHaveAccountPrompt => '¿Ya tienes una cuenta? ';

  @override
  String get logInLink => 'INICIAR SESIÓN';

  @override
  String get googleSignInSuccess => '¡Inicio de sesión con Google exitoso!';

  @override
  String get googleSignInErrorPrefix => 'Error al iniciar sesión con Google: ';

  @override
  String get emailSignupSuccess => '¡Registro exitoso!';

  @override
  String get emailSignupErrorPrefix => 'Error al registrarse: ';

  @override
  String get profileTitle => 'Perfil de Usuario';

  @override
  String get profileDefaultUsername => 'Usuario';

  @override
  String get profileEmailLabel => 'Correo Electrónico';

  @override
  String get profileValueNotAvailable => 'No disponible';

  @override
  String get profilePasswordLabel => 'Contraseña';

  @override
  String get profilePasswordHiddenText => 'contraseña oculta';

  @override
  String get profileChangePasswordButton => 'Cambiar Contraseña';

  @override
  String get profileBlockCardsButton => 'Bloquear Tarjetas';

  @override
  String get profileLogoutButton => 'Cerrar Sesión';

  @override
  String get profileDialerErrorPrefix => 'Error al abrir el marcador: ';

  @override
  String get profilePhonePermissionDenied =>
      'Permiso denegado para realizar llamadas';

  @override
  String get profileResetPasswordDialogTitle => 'Restablecer Contraseña';

  @override
  String get profileResetPasswordDialogContent =>
      '¿Estás seguro de que quieres restablecer tu contraseña?';

  @override
  String get profileDialogNo => 'No';

  @override
  String get profileDialogYes => 'Sí';

  @override
  String get profilePasswordResetEmailSent =>
      '¡Correo de restablecimiento de contraseña enviado!';

  @override
  String get profileNoEmailForPasswordReset =>
      '¡No se encontró correo para restablecer la contraseña!';

  @override
  String get loginTitle => 'INICIAR SESIÓN';

  @override
  String get loginForgotPasswordLink => '¿Olvidaste tu contraseña?';

  @override
  String get loginSignInButton => 'INICIAR SESIÓN';

  @override
  String get loginSignInWithGoogleButton => 'Iniciar sesión con Google';

  @override
  String get loginDontHaveAccountPrompt => '¿No tienes una cuenta? ';

  @override
  String get loginForgotPasswordDialogTitle => 'Olvidé mi Contraseña';

  @override
  String get loginForgotPasswordDialogContent =>
      'Ingresa tu correo electrónico para recibir un enlace de restablecimiento de contraseña:';

  @override
  String get loginSendButton => 'ENVIAR';

  @override
  String get loginPasswordResetEmailSent =>
      'Correo de restablecimiento de contraseña enviado.';

  @override
  String get commonErrorPrefix => 'Error: ';

  @override
  String get loginEmptyFieldsPrompt =>
      'Por favor, ingresa tu correo electrónico y contraseña.';

  @override
  String get loginFailedErrorPrefix => 'Falló el inicio de sesión: ';

  @override
  String get chatApiKeyNotConfigured =>
      'La clave API para Harki AI no está configurada. Por favor, revisa tu archivo .env.';

  @override
  String get chatHarkiAiInitializedSuccess => 'Harki AI Inicializado.';

  @override
  String get chatHarkiAiInitFailedPrefix =>
      'Fallo al inicializar Harki AI. Revisa la clave API y la red. Error: ';

  @override
  String get chatHarkiAiNotInitializedOnSend =>
      'Harki AI no está inicializado. Por favor espera o revisa la clave API y la red.';

  @override
  String get chatSessionNotStartedOnSend =>
      'La sesión de chat no ha comenzado. Por favor, intenta reinicializar.';

  @override
  String get chatHarkiAiEmptyResponse =>
      'Harki AI devolvió una respuesta vacía.';

  @override
  String get chatHarkiAiEmptyResponseFallbackMessage =>
      'Lo siento, no obtuve una respuesta. Por favor, inténtalo de nuevo.';

  @override
  String get chatSendMessageFailedPrefix =>
      'Fallo al enviar el mensaje a Harki AI. Error: ';

  @override
  String get chatSendMessageErrorFallbackMessage =>
      'Error: No se pudo obtener una respuesta de Harki.';

  @override
  String get chatScreenTitle => 'Chat con Harki AI';

  @override
  String get chatInitializingHarkiAiText => 'Inicializando Harki AI...';

  @override
  String get chatHarkiIsTypingText => 'Harki está escribiendo...';

  @override
  String get chatMessageHintReady => 'Mensaje a Harki...';

  @override
  String get chatMessageHintInitializing => 'Harki AI se está inicializando...';

  @override
  String get chatSenderNameHarki => 'Harki';

  @override
  String get chatSenderNameUserFallback => 'Tú';

  @override
  String get homeScreenLocationInfoText => 'Esto está sucediendo en tu área';

  @override
  String get homeMapLoadingText => 'Cargando datos del mapa...';

  @override
  String get homeFireAlertButtonTitle => 'Incendios';

  @override
  String get homeCrashAlertButtonTitle => 'Choques';

  @override
  String get homeTheftAlertButtonTitle => 'Robos';

  @override
  String get homePetAlertButtonTitle => 'Mascotas';

  @override
  String homeCallAgentButton(String agent) {
    return '$agent';
  }

  @override
  String get homeCallEmergenciesButton => 'Emergencias';

  @override
  String get agentFirefighters => 'Bomberos';

  @override
  String get agentSerenazgo => 'Serenazgo';

  @override
  String get agentPolice => 'Policía';

  @override
  String get agentShelter => 'Refugio';

  @override
  String get agentEmergencies => 'Emergencias';

  @override
  String get mapLoadingLocation => 'Cargando ubicación...';

  @override
  String get mapFetchingLocation => 'Obteniendo ubicación...';

  @override
  String mapYouAreIn(String location) {
    return 'Estás en $location';
  }

  @override
  String get mapinitialFetchingLocation => 'Obteniendo ubicación inicial...';

  @override
  String get mapCouldNotFetchAddress => 'No se pudo obtener la dirección';

  @override
  String get mapFailedToGetInitialLocation =>
      'Error al obtener la ubicación inicial';

  @override
  String get mapLocationServicesDisabled =>
      'Servicios de ubicación desactivados.';

  @override
  String get mapLocationPermissionDenied => 'Permiso de ubicación denegado.';

  @override
  String mapErrorFetchingLocation(String error) {
    return 'Error al obtener la ubicación: $error';
  }

  @override
  String get mapCurrentUserLocationNotAvailable =>
      'Ubicación actual del usuario no disponible.';

  @override
  String incidentReportedSuccess(String incidentTitle) {
    return '¡Incidente de $incidentTitle reportado!';
  }

  @override
  String incidentReportFailed(String incidentTitle) {
    return 'Error al reportar incidente de $incidentTitle.';
  }

  @override
  String get targetLocationNotSet =>
      'Ubicación objetivo no establecida. Toca en el mapa o usa la brújula.';

  @override
  String get emergencyReportLocationUnknown =>
      'No se puede reportar emergencia: Ubicación objetivo desconocida.';

  @override
  String get enlargedMapDataUnavailable =>
      'Datos del mapa no disponibles actualmente. Por favor, inténtalo de nuevo.';

  @override
  String incidentModalStep1ReportAudioTitle(String incidentName) {
    return 'Paso 1: Reportar Audio para $incidentName';
  }

  @override
  String get incidentModalStatusInitializing => 'Inicializando...';

  @override
  String get incidentModalStatusRecordingAudio => 'Grabando Audio...';

  @override
  String get incidentModalStatusAudioRecorded => '¡Audio Grabado!';

  @override
  String get incidentModalStatusSendingAudioToHarki =>
      'Harki Analizando Descripción...';

  @override
  String get incidentModalStatusConfirmAudioDescription =>
      'Confirmar Descripción:';

  @override
  String get incidentModalStatusStep2AddImage =>
      'Paso 2: Añadir Imagen (Opcional)';

  @override
  String get incidentModalStatusCapturingImage =>
      'Paso 2: Capturando Imagen...';

  @override
  String get incidentModalStatusImagePreview =>
      'Paso 2: Vista Previa de Imagen';

  @override
  String get incidentModalStatusSendingImageToHarki =>
      'Harki Analizando Imagen...';

  @override
  String get incidentModalStatusImageAnalyzed => 'Paso 2: Imagen Analizada';

  @override
  String get incidentModalStatusSubmittingIncident => 'Enviando Incidente...';

  @override
  String get incidentModalStatusError => 'Error';

  @override
  String get incidentModalStatusTypeMismatch => 'Tipo no Coincide';

  @override
  String get incidentModalStatusInputUnclearInvalid =>
      'Entrada No Clara/Inválida';

  @override
  String get incidentModalStatusHarkiProcessingError =>
      'Error de Procesamiento de Harki';

  @override
  String get incidentModalInstructionHoldMic =>
      'Mantén presionado el Mic para grabar la descripción de audio.';

  @override
  String get incidentModalInstructionMicPermissionNeeded =>
      'Se necesita permiso de micrófono. Toca el Mic para verificar/otorgar o concédelo en la configuración.';

  @override
  String get incidentModalInstructionHarkiInitializing =>
      'Harki AI se está inicializando. Espera o toca el Mic para reintentar.';

  @override
  String get incidentModalInstructionMicPermAndHarkiInit =>
      'Se necesita permiso de Mic y Harki AI se está inicializando. Toca el Mic para continuar.';

  @override
  String get incidentModalInstructionReleaseMic =>
      'Suelta el Mic para detener.';

  @override
  String get incidentModalInstructionSendAudioToHarki =>
      'Toca \"Enviar Audio a Harki\" para analizar.';

  @override
  String get incidentModalInstructionPleaseWait => 'Por favor espera.';

  @override
  String incidentModalInstructionConfirmAudio(String audioDescription) {
    return 'Harki sugiere: \"$audioDescription\".\n¿Es correcto?';
  }

  @override
  String incidentModalInstructionAddImageOrSubmit(
    String confirmedAudioDescription,
  ) {
    return 'Audio Confirmado: \"$confirmedAudioDescription\"\nAñade una imagen o envía solo con descripcion.';
  }

  @override
  String get incidentModalInstructionUseCamera =>
      'Usa la cámara para capturar una imagen.';

  @override
  String get incidentModalInstructionAnalyzeRetakeRemoveImage =>
      'Analiza esta imagen con Harki, tómala de nuevo o elimínala para continuar solo con audio.';

  @override
  String get incidentModalInstructionImageApproved =>
      '¡Imagen aprobada por Harki!\nEnvía con los detalles actuales, toma la imagen de nuevo o elimínala.';

  @override
  String incidentModalInstructionImageFeedback(String imageFeedback) {
    return 'Comentarios de Harki sobre la imagen: $imageFeedback\nEnvía con los detalles actuales, toma la imagen de nuevo o elimínala.';
  }

  @override
  String get incidentModalInstructionUploadingMedia =>
      'Subiendo multimedia, por favor espera.';

  @override
  String get incidentModalErrorMicPermissionRequired =>
      'Se requiere permiso de micrófono para grabar audio. Otórgalo en la configuración o reinicia el proceso de reporte.';

  @override
  String get incidentModalErrorFailedToInitHarki =>
      'Error al inicializar Harki AI. Procesamiento de multimedia no disponible.';

  @override
  String get incidentModalErrorMicNotGranted =>
      'Permiso de micrófono no otorgado. No se puede grabar audio.';

  @override
  String get incidentModalErrorHarkiNotReadyAudio =>
      'Harki AI no está listo. No se puede procesar audio.';

  @override
  String get incidentModalErrorCouldNotStartRecording =>
      'No se pudo iniciar la grabación. Asegúrate de que el micrófono esté disponible.';

  @override
  String get incidentModalErrorAudioEmptyNotSaved =>
      'La grabación de audio parece vacía o no se guardó correctamente. Inténtalo de nuevo.';

  @override
  String get incidentModalErrorNoAudioOrHarkiNotReady =>
      'No hay audio grabado o Harki AI no está listo.';

  @override
  String incidentModalErrorHarkiAudioResponseFormatUnexpected(
    String responseText,
  ) {
    return 'El formato de respuesta de audio de Harki AI fue inesperado: $responseText. Revisa o reintenta.';
  }

  @override
  String get incidentModalErrorHarkiNoActionableTextAudio =>
      'Harki AI no devolvió texto procesable para el audio.';

  @override
  String incidentModalErrorHarkiAudioProcessingFailed(String error) {
    return 'El procesamiento de audio de Harki AI falló: $error';
  }

  @override
  String get incidentModalErrorNoAudioToConfirm =>
      'No hay descripción de audio para confirmar.';

  @override
  String get incidentModalErrorHarkiNotReadyImage =>
      'Harki AI no está listo. No se puede procesar la imagen.';

  @override
  String get incidentModalErrorNoImageOrHarkiNotReady =>
      'No hay imagen capturada o Harki AI no está listo.';

  @override
  String get incidentModalErrorHarkiNoActionableTextImage =>
      'Harki AI no devolvió texto procesable para la imagen.';

  @override
  String incidentModalErrorHarkiImageProcessingFailed(String error) {
    return 'El procesamiento de imagen de Harki AI falló: $error';
  }

  @override
  String get incidentModalErrorUserNotLoggedIn =>
      'Usuario no ha iniciado sesión. No se puede enviar el incidente.';

  @override
  String get incidentModalErrorFailedToUploadImage =>
      'Error al subir la imagen. Inténtalo de nuevo o envía sin imagen.';

  @override
  String get incidentModalErrorNoConfirmedAudioDescription =>
      'No hay descripción de audio confirmada disponible. Completa primero el paso de audio.';

  @override
  String get incidentModalButtonHoldToRecordReleaseToStop =>
      'Mantén presionado para grabar, suelta para detener.';

  @override
  String get incidentModalButtonSendAudioToHarki => 'Enviar Audio a Harki';

  @override
  String get incidentModalButtonConfirmAudioAndProceed =>
      'Confirmar y Continuar';

  @override
  String get incidentModalButtonRerecordAudio => 'Grabar Audio de Nuevo';

  @override
  String get incidentModalButtonSubmitWithAudioOnly =>
      'Enviar solo con detalle';

  @override
  String get incidentModalButtonAddPicture => 'Añadir Foto';

  @override
  String get incidentModalButtonRetakePicture => 'Tomar Foto de Nuevo';

  @override
  String get incidentModalButtonAnalyzeImageWithHarki =>
      'Analizar Imagen con Harki';

  @override
  String get incidentModalButtonUseAudioOnlyRemoveImage =>
      'Usar Solo Audio (Eliminar Imagen)';

  @override
  String get incidentModalButtonSubmitWithAudioAndImage =>
      'Enviar con Audio e Imagen';

  @override
  String get incidentModalButtonSubmitAudioOnlyInstead =>
      'Enviar Solo Audio en su Lugar';

  @override
  String get incidentModalButtonTryAgainFromStart =>
      'Intentar de Nuevo desde el Inicio';

  @override
  String get incidentModalButtonCancelReport => 'Cancelar Reporte';

  @override
  String get incidentModalImageForIncident => 'Imagen para el Incidente:';

  @override
  String get incidentModalImageRemoveTooltip => 'Eliminar Imagen';

  @override
  String get incidentModalImageHarkiLooksGood =>
      'Harki: ¡La imagen se ve bien!';

  @override
  String incidentModalImageHarkiFeedback(String feedback) {
    return 'Harki: $feedback';
  }

  @override
  String get incidentModalImageHarkiAnalysisComplete =>
      'Harki: Análisis completo.';

  @override
  String get incidentModalAudioConfirmedAudio => 'Audio Confirmado:';

  @override
  String get incidentImageModalDescriptionLabel => 'Descripción:';

  @override
  String get incidentImageModalNoImage => 'No hay imagen para este incidente.';

  @override
  String get incidentImageModalNoAdditionalDescription =>
      'No se proporcionó descripción adicional para la imagen.';

  @override
  String get incidentImageModalCloseButton => 'Cerrar';

  @override
  String get incidentImageModalImageUnavailable => 'Imagen no disponible';

  @override
  String get locationServiceDisabled => 'Servicios de ubicación desactivados.';

  @override
  String get locationServicePermissionDenied =>
      'Permiso de ubicación denegado.';

  @override
  String get locationServicePermissionPermanentlyDenied =>
      'Los permisos de ubicación están denegados permanentemente. Habilítalos en la configuración de la aplicación.';

  @override
  String locationServiceFailedToGetLocation(String error) {
    return 'Error al obtener la ubicación: $error';
  }

  @override
  String locationServiceGeocodingApiError(String status, String errorMessage) {
    return 'Error de la API de Geocodificación: $status - $errorMessage';
  }

  @override
  String get locationServiceGeocodingFailedDefault =>
      'Error al obtener la dirección (estado de API no OK)';

  @override
  String get locationServiceGeocodingNoResults =>
      'No se encontraron resultados de dirección para las coordenadas dadas.';

  @override
  String locationServiceGeocodingLocationLatLonNoAddress(
    String latitude,
    String longitude,
  ) {
    return 'Ubicación: $latitude, $longitude (No se encontró dirección)';
  }

  @override
  String locationServiceGeocodingLocationLatLonComponentsNotFound(
    String latitude,
    String longitude,
  ) {
    return 'Ubicación: $latitude, $longitude (Componentes de dirección no encontrados)';
  }

  @override
  String locationServiceGeocodingErrorGeneric(String error) {
    return 'Error de geocodificación: $error';
  }

  @override
  String get phoneServicePermissionDenied =>
      'Permiso denegado para hacer llamadas. Habilítalo en la configuración.';

  @override
  String phoneServiceCouldNotLaunchDialer(String error) {
    return 'No se pudo iniciar el marcador: $error';
  }

  @override
  String incidentScreenTitle(String incidentType) {
    return '$incidentType cerca a ti';
  }

  @override
  String incidentFeedNoIncidentsFound(String incidentType) {
    return 'No se encontraron incidentes de $incidentType cercanos por el momento.';
  }

  @override
  String get incidentTileDefaultTitle => 'Incidente Reportado';

  @override
  String incidentTileDistanceMeters(String distance) {
    return 'A ${distance}m';
  }

  @override
  String incidentTileDistanceKm(String distance) {
    return 'A ${distance}km';
  }

  @override
  String incidentMapViewTitle(String incidentType) {
    return 'Ubicación de $incidentType';
  }

  @override
  String get incidentMapViewIncidentExpired =>
      'Este reporte de incidente ha expirado o ya no está visible.';

  @override
  String get placesScreenTitle => 'Lugares';

  @override
  String get addPlaceButtonTitle => 'Lugares interesantes';

  @override
  String get placeMarkerName => 'Lugar';

  @override
  String paymentRequiredMessage(String amount) {
    return 'Se requiere un pago de $amount para añadir este lugar.';
  }

  @override
  String get paymentProcessingMessage => 'Procesando pago...';

  @override
  String get paymentSuccessfulMessage => '¡Pago exitoso! Lugar añadido.';

  @override
  String get paymentFailedMessage =>
      'El pago falló. Por favor, inténtalo de nuevo.';

  @override
  String get photoRequiredMessage =>
      'Una foto es obligatoria para añadir un lugar.';

  @override
  String get placesIncidentFeedTitle => 'Lugares Cercanos';

  @override
  String get buttonAddPlace => 'Añadir Lugar';

  @override
  String get hintSearch => 'Busca por descripcion...';

  @override
  String get searchNoResults => 'Ninguna descripcion encontrada.';

  @override
  String get mapMarkerTooFar =>
      'El marcador está demasiado lejos de tu ubicación actual.';

  @override
  String get onboardingWelcomeTitle => '¡Bienvenido a Harkai!';

  @override
  String get onboardingWelcomeDescription =>
      'Conoce a Harki, tu asistente personal de IA. Harki puede ayudarte con consejos de seguridad y guiarte a través de las funciones de la aplicación.';

  @override
  String get onboardingIncidentsTitle => 'Reportando Incidentes';

  @override
  String get onboardingIncidentsDescription =>
      'Toca un botón de incidente (como \'Incendio\' o \'Robo\') para reportar algo en una ubicación específica. Mantén presionado el botón para ver una lista de incidentes recientes y cercanos de ese tipo.';

  @override
  String get onboardingMapTitle => 'Ubicaciones Precisas';

  @override
  String get onboardingMapDescription =>
      'Para reportar un incidente, primero toca en el mapa para colocar el marcador de objetivo precisamente donde está ocurriendo el evento. También puedes tocar el ícono de la brújula para centrarlo en tu ubicación actual.';

  @override
  String get onboardingGotIt => '¡Entendido!';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get authWeakPassword =>
      'La contraseña proporcionada es demasiado débil.';

  @override
  String get authEmailInUse =>
      'La cuenta ya existe para ese correo electrónico.';

  @override
  String get authInvalidEmail =>
      'La dirección de correo electrónico no es válida.';

  @override
  String get authGenericError =>
      'Ocurrió un error. Por favor, inténtalo de nuevo.';

  @override
  String get authUserNotFound =>
      'No se encontró ningún usuario para ese correo electrónico.';

  @override
  String get authWrongPassword =>
      'Contraseña incorrecta proporcionada para ese usuario.';

  @override
  String get authSignOutError =>
      'Error al cerrar la sesión. Por favor, inténtalo de nuevo.';

  @override
  String get profileLogoutMessage => 'Se ha cerrado la sesión correctamente.';

  @override
  String get notifFireNearbyTitle => 'Incendio Cercano';

  @override
  String get notifFireNearbyBody =>
      'Advertencia, hay un incendio cerca. Por favor, ten cuidado.';

  @override
  String get notifFireDangerTitle => 'Peligro: Incendio Adelante';

  @override
  String get notifFireDangerBody =>
      'Te estás acercando mucho al incendio. Evita la zona por tu seguridad.';

  @override
  String get notifTheftAlertTitle => 'Alerta de Robo';

  @override
  String get notifTheftAlertBody =>
      'Se ha reportado un robo cerca. Por favor, mantente alerta.';

  @override
  String get notifTheftSecurityTitle => 'Alerta de Seguridad';

  @override
  String get notifTheftSecurityBody =>
      'Estás muy cerca de un robo reportado. Evita la zona y mantente a salvo.';

  @override
  String get notifGenericIncidentTitle => 'Incidente Cercano';

  @override
  String get notifGenericIncidentBody =>
      'Echa un vistazo y ve si puedes ayudar.';

  @override
  String get notifPlaceDiscoveryTitle => 'Descubre un Nuevo Lugar';

  @override
  String notifPlaceDiscoveryBody(String placeName) {
    return '¡Oye, estás cerca de $placeName! Creemos que deberías echarle un vistazo.';
  }

  @override
  String get notifPlaceAlmostThereTitle => '¡Ya Casi Llegas!';

  @override
  String notifPlaceAlmostThereBody(String placeName) {
    return 'Te estás acercando a $placeName. ¡Disfruta tu visita!';
  }

  @override
  String get notifPlaceWelcomeTitle => '¡Bienvenido!';

  @override
  String notifPlaceWelcomeBody(String placeName) {
    return 'Nos alegra que hayas venido a $placeName. ¡Esperamos que disfrutes tu estancia aquí!';
  }

  @override
  String incidentModalReportTextTitle(String incidentName) {
    return 'Paso 1: Reportar con Texto para $incidentName';
  }

  @override
  String get incidentModalInstructionEnterText =>
      'Por favor, describe el incidente en el cuadro de texto a continuación.';

  @override
  String get incidentModalButtonSendTextToHarki => 'Enviar Texto a Harki';

  @override
  String get incidentModalButtonEnterTextInstead =>
      'Ingresar Texto en su Lugar';

  @override
  String get onboardingLocationTitle => 'Ubicación Siempre Activa';

  @override
  String get onboardingLocationDescription =>
      'Para mantenerte seguro y enviarte alertas en tiempo real sobre incidentes cercanos incluso cuando la aplicación está en segundo plano, Harkai necesita acceder a tu ubicación en todo momento. Por favor, concede este permiso en la configuración interna de la app en los ajustes de aplicaciones.';

  @override
  String get addplaceTitle => 'Añadir Lugar al Mapa de Harkai';

  @override
  String get incidentModalButtonAddFromGallery => 'Añadir desde Galería';

  @override
  String get addplaceInfo =>
      'Para añadir un lugar, completa el pago con el boton de pago';
}
