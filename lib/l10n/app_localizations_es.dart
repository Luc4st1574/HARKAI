// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Mi Increíble Aplicación';

  @override
  String get helloWorld => '¡Hola Mundo!';

  @override
  String welcomeMessage(Object name) {
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
}
