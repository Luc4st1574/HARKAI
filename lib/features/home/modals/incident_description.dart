// lib/features/home/modals/incident_description.dart

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

  String _statusText = 'Initializing...';
  String _confirmationPrompt = '';

  late AnimationController _micAnimationController;
  late Animation<double> _micScaleAnimation;

  @override
  void initState() {
    super.initState();
    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150), // Faster animation for press/release
    );
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate( // Slightly smaller scale
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndInitializeRecognizers();
      if (mounted && _currentInputState != VoiceInputState.error) {
        _updateStatusAndConfirmationText();
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _checkPermissionsAndInitializeRecognizers() async {
    // ... (keep existing permission check logic)
    PermissionStatus micStatus = await Permission.microphone.status;
    _hasMicPermission = micStatus.isGranted;

    if (!_hasMicPermission) {
      debugPrint("IncidentModal: Mic permission not granted at modal init. Status: ${micStatus.name}");
      _handleSpeechError("Microphone permission is required. Please enable it in settings or tap 'Try Again'.");
      return;
    }
    
    await _initializeSpeechRecognizer();
    await _initializeGemini();
  }

  Future<void> _initializeSpeechRecognizer() async {
    // ... (keep existing speech recognizer init logic)
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
    if(mounted) _updateStatusAndConfirmationText();
  }

  void _handleSpeechError(String errorMessage) {
    // ... (keep existing speech error handling)
    if (mounted) {
      _micAnimationController.reverse(); // Ensure animation is reset
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
        // Animation is handled by onTapDown/Up now
      } else if (status == 'notListening' || status == 'done') {
        // Ensure animation resets if it was somehow active
        if (_micAnimationController.value > 0.0) {
            _micAnimationController.reverse();
        }
        if (_currentInputState == VoiceInputState.listening) {
          if (_rawSpeechText.trim().isNotEmpty) {
            nextState = VoiceInputState.processing;
            shouldProcess = true;
          } else {
            nextState = VoiceInputState.idle;
            _statusText = "No speech detected. Hold mic to try again.";
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
          setState(() { _updateStatusAndConfirmationText();});
      }
    }
  }

  Future<void> _initializeGemini() async {
    // ... (keep existing Gemini init logic)
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
    // ... (keep existing Gemini error handling)
      if (mounted) {
      setState(() {
        _currentInputState = VoiceInputState.error;
        _statusText = "Gemini Error: $errorMessage";
        _updateStatusAndConfirmationText();
      });
    }
  }

  // New method to initiate listening
  Future<void> _initiateListening() async {
    PermissionStatus currentMicStatus = await Permission.microphone.status;
    _hasMicPermission = currentMicStatus.isGranted;

    if (!_hasMicPermission) {
      if (mounted) {
        bool permissionGrantedViaService = await SpeechPermissionService().requestMicrophonePermission(openSettingsOnError: true);
        if (mounted) {
          _hasMicPermission = permissionGrantedViaService;
          if (!permissionGrantedViaService) {
            currentMicStatus = await Permission.microphone.status;
            String errMsg = "Microphone permission not granted. Status: ${currentMicStatus.name}.";
            if (currentMicStatus.isPermanentlyDenied) errMsg += " Enable in app settings.";
            _handleSpeechError(errMsg);
            setState(() {});
            return;
          }
          setState(() {});
        } else { return; }
      } else { return; }
    }
    
    if (!_speechEnabled) {
      _handleSpeechError("Speech recognizer not ready. Re-initializing...");
      await _initializeSpeechRecognizer(); 
      if (!_speechEnabled || !mounted) {
        if(mounted) _handleSpeechError("Speech recognizer could not be enabled.");
        if (mounted) setState((){_updateStatusAndConfirmationText();});
        return;
      }
    }

    if (_speechToText.isListening) { // Should not happen with hold-to-record if logic is correct
      await _speechToText.stop();
    }
    
    _rawSpeechText = '';
    _geminiProcessedText = '';
    if (mounted) {
      setState(() {
        _currentInputState = VoiceInputState.listening;
        _updateStatusAndConfirmationText();
      });
    }
      
    if (!_speechToText.isAvailable && mounted) {
      _handleSpeechError("Speech recognition service currently not available.");
      if (mounted) _micAnimationController.reverse(); // Reset animation if listen fails early
      return;
    }
      
    String currentLocaleId = 'en_US'; 
    if (mounted) {
      try {
        currentLocaleId = Localizations.localeOf(context).toString();
      } catch (e) {
        debugPrint("IncidentModal: Could not get locale for STT, using 'en_US'. Error: $e");
      }
    }

    bool successStarting = false;
    try {
      successStarting = await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() { _rawSpeechText = result.recognizedWords; });
          }
        },
        partialResults: true, // Good for responsive UI
        localeId: currentLocaleId,
        // No listenFor or pauseFor, rely on explicit stop
      );
    } catch (e) {
      if (mounted) {
        _micAnimationController.reverse(); // Reset animation
        _handleSpeechError("Exception during speech listen: ${e.toString()}");
      }
      return;
    }

    if (!successStarting && mounted) {
        _micAnimationController.reverse(); // Reset animation
        _handleSpeechError("Speech listener failed to start.");
    }
    // If successful, animation controller is already handled by onTapDown
  }

  // New method to stop listening
  Future<void> _stopListeningAndProcess() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
      // _handleSpeechStatus will be triggered with 'notListening' or 'done',
      // which will then call _processTextWithGemini if _rawSpeechText is not empty.
    } else {
      // If somehow stop is called when not listening, but we were in listening state UI-wise
      if (_currentInputState == VoiceInputState.listening) {
          if (_rawSpeechText.trim().isNotEmpty) {
            if(mounted) {
              setState(() {
                _currentInputState = VoiceInputState.processing;
                _updateStatusAndConfirmationText();
              });
              _processTextWithGemini();
            }
          } else {
            if(mounted) {
              setState(() {
                _currentInputState = VoiceInputState.idle;
                _statusText = "No speech detected. Hold mic to try again.";
                _updateStatusAndConfirmationText();
              });
            }
          }
      }
    }
  }

  Future<void> _processTextWithGemini() async {
    // ... (keep existing Gemini processing logic)
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
      if (mounted) { 
        setState(() {
          _geminiProcessedText = _rawSpeechText; 
          _currentInputState = VoiceInputState.confirming;
          _updateStatusAndConfirmationText();
        });
      }
    }
  }

  void _confirmDescription() {
    // This is the "Send" action
    Navigator.pop(context, _geminiProcessedText.trim().isNotEmpty ? _geminiProcessedText.trim() : null);
  }

  void _retryInputSequence() {
    // Called by "Retry with Mic"
    if (mounted) {
      setState(() {
        _currentInputState = VoiceInputState.idle;
        _rawSpeechText = '';
        _geminiProcessedText = '';
        _updateStatusAndConfirmationText();
        // User will tap mic again.
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
    // ... (keep existing status/confirmation text update logic)
    final markerDetails = getMarkerInfo(widget.markerType);
    final incidentName = markerDetails?.title ?? widget.markerType.name.capitalizeAllWords();

    switch (_currentInputState) {
      case VoiceInputState.idle:
        _statusText = _hasMicPermission && _speechEnabled
            ? 'Hold the mic to describe the $incidentName' // Updated instruction
            : (_hasMicPermission ? 'Speech service initializing...' : 'Microphone permission needed.');
        _confirmationPrompt = '';
        break;
      case VoiceInputState.listening:
        _statusText = 'Listening for $incidentName details... Release to process.'; // Updated
        _confirmationPrompt = '';
        break;
      case VoiceInputState.processing:
        _statusText = 'Processing your description...';
        _confirmationPrompt = '';
        break;
      case VoiceInputState.confirming:
        _statusText = 'AI understood:';
        _confirmationPrompt = 'Send this description for the $incidentName?'; // Updated
        break;
      case VoiceInputState.error:
        _confirmationPrompt = 'An error occurred. Please try again or cancel.';
        break;
    }
  }

  @override
  void dispose() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _speechToText.cancel(); // Important for STT plugin
    _micAnimationController.dispose();
    super.dispose();
  }
  
  // --- UI Builder Methods ---

  Widget _buildMicInputControl(bool canListen, Color accentColor) {
    return GestureDetector(
      onTapDown: canListen ? (details) {
        _micAnimationController.forward(); // Scale up on press
        _initiateListening();
      } : null,
      onTapUp: canListen ? (details) {
        _micAnimationController.reverse(); // Scale down on release
        _stopListeningAndProcess();
      } : null,
      onTapCancel: canListen ? () { // Handle if tap is cancelled (e.g., drag off)
        _micAnimationController.reverse();
        if (_speechToText.isListening) {
          _stopListeningAndProcess();
        }
      } : null,
      child: ScaleTransition(
        scale: _micScaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: canListen ? accentColor : Colors.grey.shade700,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Icon(
            // Icon could change based on _currentInputState == VoiceInputState.listening
            _currentInputState == VoiceInputState.listening ? Icons.settings_voice : Icons.mic,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0), // Increased padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
          // Status text is already shown above
        ],
      ),
    );
  }

  Widget _buildConfirmationControls(Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.send, color: Colors.white, size: 18),
          label: const Text('Send Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 3,
          ),
          onPressed: _confirmDescription,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.mic_off_outlined, color: Colors.orangeAccent, size: 20),
          label: const Text('Retry with Mic', style: TextStyle(color: Colors.orangeAccent, fontSize: 15)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
          onPressed: _retryInputSequence,
        ),
      ],
    );
  }
  
  Widget _buildErrorControls(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: const Text('Try Again', style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        onPressed: () async {
          if (mounted) {
            setState(() {
              _currentInputState = VoiceInputState.idle;
              _rawSpeechText = '';
              _geminiProcessedText = '';
            });
            await _checkPermissionsAndInitializeRecognizers();
            if (mounted) _updateStatusAndConfirmationText();
            // Do not auto-listen, user must tap mic.
          }
        },
      ),
    );
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
            
            const SizedBox(height: 20), // Space before dynamic action area

            // --- Dynamic Action Area ---
            if (_currentInputState == VoiceInputState.processing)
              _buildProcessingIndicator(accentColor)
            else if (_currentInputState == VoiceInputState.idle || _currentInputState == VoiceInputState.listening)
              _buildMicInputControl(canListen, accentColor)
            else if (_currentInputState == VoiceInputState.confirming)
              _buildConfirmationControls(accentColor)
            else if (_currentInputState == VoiceInputState.error)
              _buildErrorControls(accentColor),

            const SizedBox(height: 20), // Space after dynamic action area

            // --- Cancel Button (conditionally visible) ---
            // Show Cancel unless processing. In confirming state, user has "Retry" or "Send".
            if (_currentInputState != VoiceInputState.processing && _currentInputState != VoiceInputState.confirming) 
              TextButton(
                onPressed: _cancelInput,
                child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 15)),
              ),
          ],
        ),
      ),
    );
  }
}

// showIncidentVoiceDescriptionDialog and StringExtension remain the same
Future<String?> showIncidentVoiceDescriptionDialog({
  required BuildContext context,
  required MakerType markerType,
}) async {
  return await showDialog<String?>(
    context: context,
    barrierDismissible: false, // User must explicitly cancel or confirm
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