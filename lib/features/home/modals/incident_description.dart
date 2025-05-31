import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/markers.dart';
import '/core/services/speech_service.dart';

// Enum to manage the state of the voice input modal
enum VoiceInputState {
  idle,
  listening,
  processing,
  confirming,
  error,
}

class IncidentVoiceDescriptionModal extends StatefulWidget {
  final MakerType markerType;

  const IncidentVoiceDescriptionModal({
    super.key,
    required this.markerType,
  });

  @override
  State<IncidentVoiceDescriptionModal> createState() =>
      _IncidentVoiceDescriptionModalState();
}

class _IncidentVoiceDescriptionModalState
    extends State<IncidentVoiceDescriptionModal> with TickerProviderStateMixin {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _hasMicPermission = false;

  String _rawSpeechText = '';
  String _geminiProcessedText = '';
  VoiceInputState _currentInputState = VoiceInputState.idle;

  GenerativeModel? _generativeModel;
  ChatSession? _chatSession;

  String _statusText = 'Initializing...'; // Initial status
  String _confirmationPrompt = '';

  late AnimationController _micAnimationController;
  late Animation<double> _micScaleAnimation;

  @override
  void initState() {
    super.initState();
    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndInitializeRecognizers();
      if (mounted && _currentInputState != VoiceInputState.error) { // Avoid overwriting error status
        _updateStatusAndConfirmationText();
      }
      if(mounted) setState(() {});
    });
  }

  Future<void> _checkPermissionsAndInitializeRecognizers() async {
    PermissionStatus micStatus = await Permission.microphone.status;
    _hasMicPermission = micStatus.isGranted;

    if (!_hasMicPermission) {
      debugPrint("IncidentModal: Mic permission not granted at modal init. Status: ${micStatus.name}");
      _handleSpeechError("Microphone permission is required. Please enable it in settings or tap 'Try Again'.");
      return;
    }
    
    // If mic permission is granted, proceed.
    await _initializeSpeechRecognizer(); // This will set _speechEnabled
    await _initializeGemini();
  }

  Future<void> _initializeSpeechRecognizer() async {
    if (!_hasMicPermission) {
      _handleSpeechError("Cannot initialize speech recognizer: Microphone permission denied.");
      return;
    }
    debugPrint("IncidentModal: Initializing local SpeechToText instance...");
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: _handleSpeechStatus,
        onError: (errorNotification) => _handleSpeechError("STT Init Error: ${errorNotification.errorMsg}"),
      );
      if (_speechEnabled) {
        debugPrint("IncidentModal: Local SpeechToText instance initialized successfully.");
      } else {
        // Check mic permission again as STT init can fail due to it.
        PermissionStatus currentMicStatus = await Permission.microphone.status;
        _hasMicPermission = currentMicStatus.isGranted;
        if (!_hasMicPermission) {
            _handleSpeechError("Speech recognition unavailable: Microphone permission denied.");
        } else {
            _handleSpeechError("Speech recognition service is not available or failed to initialize.");
        }
      }
    } catch (e) {
      _handleSpeechError("Exception initializing local speech recognizer: $e");
    }
    if(mounted) _updateStatusAndConfirmationText(); // Update text based on init result
  }

  void _handleSpeechError(String errorMessage) {
    if (mounted) {
      _micAnimationController.reset();
      setState(() {
        _currentInputState = VoiceInputState.error;
        _statusText = errorMessage; 
        _updateStatusAndConfirmationText(); 
      });
    }
  }

  void _handleSpeechStatus(String status) {
    if (mounted) {
      debugPrint("IncidentModal: Speech status: $status");
      VoiceInputState nextState = _currentInputState;
      bool shouldProcess = false;

      if (status == 'listening') {
        nextState = VoiceInputState.listening;
        if (!_micAnimationController.isAnimating) {
          _micAnimationController.repeat(reverse: true);
        }
      } else if (status == 'notListening' || status == 'done') {
        if (_micAnimationController.isAnimating) {
          _micAnimationController.forward().then((_) {
              if(mounted) _micAnimationController.reverse();
          });
        }
        if (_currentInputState == VoiceInputState.listening) {
          if (_rawSpeechText.isNotEmpty) {
            nextState = VoiceInputState.processing;
            shouldProcess = true; // Flag to process after state update
          } else {
            nextState = VoiceInputState.idle;
            _statusText = "No speech detected. Tap mic to try again.";
          }
        }
      }
      
      if (nextState != _currentInputState || shouldProcess) {
        setState(() {
          _currentInputState = nextState;
          _updateStatusAndConfirmationText();
        });
        if(shouldProcess){
          _processTextWithGemini();
        }
      } else {
        // If only status text changed for idle state without actual state change
        setState(() { _updateStatusAndConfirmationText();});
      }
    }
  }

  Future<void> _initializeGemini() async {
    final apiKey = dotenv.env['HARKI_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _handleGeminiError("Gemini API Key not found.");
      return;
    }
    debugPrint("IncidentModal: Initializing Gemini...");
    try {
      final String systemPrompt =
          "You are an AI assistant for Harkai, a citizen security app. "
          "Your task is to refine user-spoken incident descriptions. "
          "Focus on clarity, conciseness, and relevant details for a security context. "
          "Correct speech-to-text errors. Identify the key elements of the incident. "
          "The user is reporting an incident of type: ${widget.markerType.name}. "
          "Keep the refined description brief and factual. "
          "For example, if the user says 'uhm like there's a big fire over by the main street shops it's kinda smoky', "
          "you might refine it to 'Large fire near Main Street shops, significant smoke.' "
          "Some users will speak in Spanish, so you should also be able to understand and process Spanish text; do not translate it to English, just refine it in Spanish.";

      _generativeModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(systemPrompt),
        generationConfig: GenerationConfig(temperature: 0.6, maxOutputTokens: 100),
      );
      _chatSession = _generativeModel!.startChat();
      debugPrint("IncidentModal: Gemini initialized successfully.");
    } catch (e) {
      _handleGeminiError("Failed to initialize Gemini: ${e.toString()}");
    }
      if(mounted) _updateStatusAndConfirmationText();
  }

  void _handleGeminiError(String errorMessage) {
    if (mounted) {
      setState(() {
        _currentInputState = VoiceInputState.error;
        _statusText = "Gemini Error: $errorMessage";
        _updateStatusAndConfirmationText();
      });
    }
  }

  void _startListening() async {
    PermissionStatus currentMicStatus = await Permission.microphone.status;
    _hasMicPermission = currentMicStatus.isGranted;

    if (!_hasMicPermission) {
      if (mounted) {
        debugPrint("IncidentModal: Mic permission not granted. Attempting to request again via SpeechPermissionService.");
        bool permissionGrantedViaService = await SpeechPermissionService().requestMicrophonePermission(openSettingsOnError: true);
        
        if (mounted) {
          _hasMicPermission = permissionGrantedViaService;
          if (!permissionGrantedViaService) {
            currentMicStatus = await Permission.microphone.status; // Re-check for accurate message
            String errMsg = "Microphone permission not granted. Current status: ${currentMicStatus.name}.";
            if (currentMicStatus.isPermanentlyDenied) {
              errMsg += " Please enable it in app settings.";
            }
            _handleSpeechError(errMsg);
            setState(() {}); // Update UI based on this attempt
            return;
          }
          debugPrint("IncidentModal: Mic permission granted after re-request via service.");
          setState(() {}); // Update UI to reflect permission change
        } else { return; }
      } else { return; }
    }
    
    if (!_speechEnabled) {
      _handleSpeechError("Speech recognizer instance not ready. Trying to re-initialize...");
      await _initializeSpeechRecognizer(); 
      if (!_speechEnabled || !mounted) { // Add mounted check after await
        if(mounted) _handleSpeechError("Speech recognizer could not be enabled.");
        if (mounted) setState((){_updateStatusAndConfirmationText();}); // Update text if still mounted
          return;
      }
    }

    if (_speechToText.isListening) {
      await _speechToText.stop();
    } else {
      _rawSpeechText = '';
      _geminiProcessedText = '';
      if (mounted) {
        setState(() {
          _currentInputState = VoiceInputState.listening;
          _updateStatusAndConfirmationText();
        });
      }
      
      if (!_speechToText.isAvailable && mounted) {
        _handleSpeechError("Speech recognition service is currently not available.");
        return;
      }
      
      String currentLocaleId = 'en_US'; 
      if (mounted) {
        try {
          currentLocaleId = Localizations.localeOf(context).toString();
        } catch (e) {
          debugPrint("IncidentModal: Could not get locale from context for STT, using default 'en_US'. Error: $e");
        }
      }

      bool available = await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() { _rawSpeechText = result.recognizedWords; });
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        localeId: currentLocaleId,
      );

      if (available) {
        if (mounted && _currentInputState == VoiceInputState.listening) {
          if (!_micAnimationController.isAnimating) {
              _micAnimationController.repeat(reverse: true);
          }
        }
      } else {
        _handleSpeechError("Speech listener failed to start or is not available.");
      }
    }
  }

  Future<void> _processTextWithGemini() async {
    if (!mounted || _currentInputState != VoiceInputState.processing) return;

    if (_generativeModel == null || _chatSession == null) {
      _handleGeminiError("Gemini not ready for processing.");
      return;
    }
    if (_rawSpeechText.isEmpty) {
      setState(() {
        _geminiProcessedText = "No speech was detected to process.";
        _currentInputState = VoiceInputState.confirming; 
        _updateStatusAndConfirmationText();
      });
      return;
    }

    debugPrint("IncidentModal: Processing with Gemini: '$_rawSpeechText'");
    try {
      final response = await _chatSession!.sendMessage(Content.text(_rawSpeechText));
      final text = response.text;
      if (mounted) {
        setState(() {
          _geminiProcessedText = text ?? "Gemini couldn't process the text.";
          _currentInputState = VoiceInputState.confirming;
          _updateStatusAndConfirmationText();
        });
      }
    } catch (e) {
      _handleGeminiError("Gemini processing failed: ${e.toString()}");
      if (mounted) { // Fallback to raw text on Gemini error
        setState(() {
          _geminiProcessedText = _rawSpeechText; 
          _currentInputState = VoiceInputState.confirming;
          _updateStatusAndConfirmationText();
        });
      }
    }
  }

  void _confirmDescription() {
    Navigator.pop(context, _geminiProcessedText.trim().isNotEmpty ? _geminiProcessedText.trim() : null);
  }

  void _retryDescription() {
    if (mounted) {
      setState(() {
        _currentInputState = VoiceInputState.idle;
        _rawSpeechText = '';
        _geminiProcessedText = '';
        _updateStatusAndConfirmationText();
        // No auto-listen, let user tap mic again. 
        // _startListening will re-check permissions if needed.
      });
    }
  }

  void _cancelInput() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    Navigator.pop(context, null);
  }

  void _updateStatusAndConfirmationText() {
    // final AppLocalizations? loc = AppLocalizations.of(context); // For localized strings
    final markerDetails = getMarkerInfo(widget.markerType);
    final incidentName = markerDetails?.title ?? widget.markerType.name.capitalizeAllWords();

    switch (_currentInputState) {
      case VoiceInputState.idle:
        _statusText = _hasMicPermission && _speechEnabled
            ? 'Tap the mic to describe the $incidentName'
            : (_hasMicPermission ? 'Speech service initializing...' : 'Microphone permission needed.');
        _confirmationPrompt = '';
        break;
      case VoiceInputState.listening:
        _statusText = 'Listening for $incidentName details...';
        _confirmationPrompt = '';
        break;
      case VoiceInputState.processing:
        _statusText = 'Processing your description...';
        _confirmationPrompt = '';
        break;
      case VoiceInputState.confirming:
        _statusText = 'AI understood:';
        _confirmationPrompt = 'Is this correct for the $incidentName?';
        break;
      case VoiceInputState.error:
        // _statusText is set by _handleSpeechError or _handleGeminiError.
        _confirmationPrompt = 'An error occurred. Please try again or cancel.';
        break;
    }
  }

  @override
  void dispose() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _speechToText.cancel();
    _micAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MarkerInfo? markerDetails = getMarkerInfo(widget.markerType);
    final Color accentColor = markerDetails?.color ?? Colors.blueGrey;
    final String title = markerDetails?.title ?? widget.markerType.name.capitalizeAllWords();

    bool canListen = _hasMicPermission && _speechEnabled;

    return Dialog(
      backgroundColor: const Color(0xFF001F3F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: accentColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Report: $title', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor)),
            const SizedBox(height: 20),
            // Status text is always visible
            Text(_statusText, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)), textAlign: TextAlign.center),
            const SizedBox(height: 10),

            if ((_currentInputState == VoiceInputState.confirming || (_currentInputState == VoiceInputState.error && _geminiProcessedText.isNotEmpty)) && _geminiProcessedText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withOpacity(0.5))
                ),
                child: Text(_geminiProcessedText, style: const TextStyle(fontSize: 16, color: Colors.white), textAlign: TextAlign.center),
              ),

            if (_currentInputState == VoiceInputState.confirming && _geminiProcessedText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 15.0),
                child: Text(_confirmationPrompt, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8)), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 10),

            // Action Area: Mic, Processing, Confirmation, or Error+Retry
            if (_currentInputState == VoiceInputState.processing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
                    const SizedBox(height: 15),
                    // Text(_statusText, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)), textAlign: TextAlign.center), // Already shown above
                  ],
                ),
              )
            else if (_currentInputState == VoiceInputState.idle || _currentInputState == VoiceInputState.listening)
              ScaleTransition(
                scale: _micScaleAnimation,
                child: ElevatedButton(
                  onPressed: canListen ? _startListening : null, // Use canListen
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canListen ? accentColor : Colors.grey.shade700,
                    disabledBackgroundColor: Colors.grey.shade700.withOpacity(0.5),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  child: Icon(
                    _currentInputState == VoiceInputState.listening ? Icons.stop_circle_outlined : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              )
            else if (_currentInputState == VoiceInputState.confirming)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    label: const Text('No, Retry', style: TextStyle(color: Colors.redAccent)),
                    onPressed: _retryDescription,
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.check, color: Colors.greenAccent),
                    label: const Text('Yes, Add', style: TextStyle(color: Colors.greenAccent)),
                    onPressed: _confirmDescription,
                  ),
                ],
              )
            else if (_currentInputState == VoiceInputState.error)
              Padding(
                padding: const EdgeInsets.only(top: 15.0),
                child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh, color: Colors.white,),
                label: const Text('Try Again',style: TextStyle(color: Colors.white)), 
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  onPressed: () async { 
                    if(mounted) {
                      setState(() {
                        _currentInputState = VoiceInputState.idle; 
                        _rawSpeechText = '';
                        _geminiProcessedText = '';
                        _updateStatusAndConfirmationText();
                      });
                      await _checkPermissionsAndInitializeRecognizers(); // This now handles both mic and STT init logic
                      if(mounted) _updateStatusAndConfirmationText(); // Update text based on result of re-init
                      
                      if (mounted && _hasMicPermission && _speechEnabled && _currentInputState == VoiceInputState.idle) {
                        _startListening();
                      } else if (mounted) {
                        setState((){});
                      }
                    }
                  },
                ),
              ),
            const SizedBox(height: 10),

            // Cancel button visibility
            if (_currentInputState != VoiceInputState.confirming && _currentInputState != VoiceInputState.processing)
              TextButton(
                onPressed: _cancelInput,
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}

Future<String?> showIncidentVoiceDescriptionDialog({
  required BuildContext context,
  required MakerType markerType,
}) async {
  return await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return IncidentVoiceDescriptionModal(markerType: markerType);
    },
  );
}

extension StringExtension on String {
  String capitalizeAllWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }
}
