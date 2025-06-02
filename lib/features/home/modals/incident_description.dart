import 'dart:async';
import 'dart:typed_data'; // For Uint8List
import 'dart:io'; // For File operations

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart'; // Import the record package
import 'package:path_provider/path_provider.dart'; // To get a temporary directory path

import '../utils/markers.dart';
import '/core/services/speech_service.dart';

// Enum to manage the state of the voice input modal
enum VoiceInputState {
  idle,
  recording,
  recordedReadyToSend,
  sendingToGemini,
  confirmingDescription,
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
  late AudioRecorder _audioRecorder;
  bool _hasMicPermission = false;
  String? _recordedAudioPath;

  String _geminiProcessedText = '';
  VoiceInputState _currentInputState = VoiceInputState.idle;

  GenerativeModel? _generativeModel;

  String _statusText = 'Initializing...';
  String _userInstructionText = '';

  late AnimationController _micAnimationController;
  late Animation<double> _micScaleAnimation;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();

    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndInitializeServices();
      if (mounted) {
        _updateStatusAndInstructionText();
        setState(() {});
      }
    });
  }

  Future<void> _checkPermissionsAndInitializeServices() async {
    PermissionStatus micStatus = await Permission.microphone.status;
    _hasMicPermission = micStatus.isGranted;

    if (!_hasMicPermission) {
      debugPrint("IncidentModal: Mic permission not granted at modal init. Status: ${micStatus.name}");
      _hasMicPermission = await SpeechPermissionService().requestMicrophonePermission(openSettingsOnError: true);
      if (!_hasMicPermission && mounted) {
        _handleError("Microphone permission is required. Please enable it in settings and try again.");
        return;
      }
    }
    if (_hasMicPermission) {
      await _initializeGemini();
    }
    if(mounted) _updateStatusAndInstructionText();
  }

  Future<void> _initializeGemini() async {
    final apiKey = dotenv.env['HARKI_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _handleError("Gemini API Key not found. Cannot process audio.");
      return;
    }
    debugPrint("IncidentModal: Initializing Gemini for audio processing...");
    try {
      final String incidentTypeName = widget.markerType.name.toString().split('.').last.capitalizeAllWords();
      final String systemPrompt =
          "You are Harki, an AI assistant for the Harkai citizen security app. "
          "The user has pre-selected an incident type: '$incidentTypeName'. "
          "You will receive an audio input from the user describing this incident. Your tasks are:\n"
          "1. VALIDATION: Determine if the audio description genuinely matches the pre-selected incident type: '$incidentTypeName'.\n"
          "2. RESPONSE GENERATION:\n"
          "   - IF IT MATCHES: Respond EXACTLY with 'MATCH: ' followed by a very short, concise text summary of the incident suitable for a map marker (max 15 words). Example: If type is 'Fire' and audio describes a house fire, respond: 'MATCH: House fire with heavy smoke on Main St.'\n"
          "   - IF IT DOES NOT MATCH but describes another valid incident type (Fire, Crash, Theft, Pet, Emergency): Respond EXACTLY with 'MISMATCH: This sounds more like a [Correct Incident Type] alert. Please confirm this or re-record for $incidentTypeName.' Example: If selected type is 'Fire' but audio is about a lost dog, respond: 'MISMATCH: This sounds more like a Pet alert. Please confirm this or re-record for Fire.'\n"
          "   - IF IT DOES NOT MATCH AND IT'S UNCLEAR or NOT A REPORTABLE INCIDENT (e.g., casual conversation, insufficient detail): Respond EXACTLY with 'UNCLEAR: The audio was not clear enough or did not describe a reportable incident for '$incidentTypeName'. Please try recording again with more details.'\n"
          "Be factual. Respond in the language of the audio if possible (especially Spanish or English), otherwise default to English. Keep summaries very brief.";


      _generativeModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(systemPrompt),
        generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 100), // Increased maxOutputTokens slightly for mismatch messages
      );
      debugPrint("IncidentModal: Gemini initialized successfully for audio.");
    } catch (e) {
      _handleError("Failed to initialize Gemini: ${e.toString()}");
    }
    if(mounted) _updateStatusAndInstructionText();
  }

  void _handleError(String errorMessage, {bool isGeminiError = false, bool isMismatch = false, bool isUnclear = false}) {
    if (mounted) {
      _micAnimationController.reverse();
      setState(() {
        _currentInputState = VoiceInputState.error;
        if (isMismatch) {
          _statusText = "Incident Type Mismatch";
          _userInstructionText = errorMessage; // errorMessage here is Gemini's suggestion
        } else if (isUnclear) {
          _statusText = "Audio Unclear or Invalid";
           _userInstructionText = errorMessage; // errorMessage here is Gemini's feedback
        } else { // General error
          _statusText = isGeminiError ? "Gemini Processing Error" : "Error";
          _userInstructionText = errorMessage; // The original error message string
        }
        // _updateStatusAndInstructionText(); // Not strictly needed as texts are set here directly for error
      });
    }
  }

  Future<String> _getFilePath(String extension) async {
    final directory = await getTemporaryDirectory();
    return '${directory.path}/incident_audio_${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  Future<void> _startRecording() async {
    if (!_hasMicPermission) {
      _handleError("Microphone permission not granted.");
      return;
    }
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    
    try {
      const chosenEncoder = AudioEncoder.aacLc;
      const chosenSampleRate = 16000;
      const chosenNumChannels = 1;
      const chosenBitRate = 48000;
      const fileExtension = "m4a"; 

      _recordedAudioPath = await _getFilePath(fileExtension);
      
      const config = RecordConfig(
          encoder: chosenEncoder,
          sampleRate: chosenSampleRate,
          numChannels: chosenNumChannels,
          bitRate: chosenBitRate,
      );

      await _audioRecorder.start(config, path: _recordedAudioPath!);
      debugPrint("Recording started to path: $_recordedAudioPath with encoder: $chosenEncoder, sampleRate: $chosenSampleRate");
      if (mounted) {
        _micAnimationController.forward();
        setState(() {
          _currentInputState = VoiceInputState.recording;
          _updateStatusAndInstructionText();
        });
      }
    } catch (e) {
      _handleError("Could not start recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (!await _audioRecorder.isRecording()) {
        if (_currentInputState == VoiceInputState.recording && mounted) {
              _micAnimationController.reverse();
              setState(() {
                  _currentInputState = VoiceInputState.idle;
                  _updateStatusAndInstructionText();
            });
        }
        return;
    }
    try {
      final path = await _audioRecorder.stop();
      debugPrint("Recording stopped. File saved at: $path");
      if (path != null) {
        final audioFile = File(path);
        if (await audioFile.exists() && await audioFile.length() > 100) { // Check for a minimal file size
            _recordedAudioPath = path;
            if (mounted) {
              _micAnimationController.reverse();
              setState(() {
                _currentInputState = VoiceInputState.recordedReadyToSend;
                _updateStatusAndInstructionText();
              });
            }
        } else {
            _handleError("Recording seems empty or file not saved correctly.");
            _recordedAudioPath = null;
        }
      } else {
        _handleError("Failed to stop recording or no audio path returned.");
      }
    } catch (e) {
      _handleError("Error stopping recording: $e");
    }
  }

  Future<void> _sendAudioToGemini() async {
    if (_currentInputState != VoiceInputState.recordedReadyToSend || _recordedAudioPath == null) {
      _handleError("No audio recorded or not in a state to send.");
      return;
    }
    if (_generativeModel == null) {
      _handleError("Gemini not ready for processing.", isGeminiError: true);
      return;
    }

    setState(() {
      _currentInputState = VoiceInputState.sendingToGemini;
      _updateStatusAndInstructionText();
    });

    debugPrint("IncidentModal: Reading audio from $_recordedAudioPath and sending to Gemini...");
    try {
      final audioFile = File(_recordedAudioPath!);
      if (!await audioFile.exists()) {
        _handleError("Recorded audio file does not exist at path: $_recordedAudioPath");
        return;
      }
      final Uint8List audioBytes = await audioFile.readAsBytes();

      if (audioBytes.isEmpty) {
          _handleError("Cannot send empty audio file.", isGeminiError: false);
          return;
      }
      
      const String mimeType = "audio/aac"; // Matching the encoder used

      final response = await _generativeModel!.generateContent([
          Content.data(mimeType, audioBytes)
      ]);

      final text = response.text;
      _geminiProcessedText = text ?? "Gemini couldn't process the audio or returned no text."; // Store full response initially

      if (mounted) {
        if (text != null && text.isNotEmpty) {
            if (text.startsWith("MATCH:")) {
                _geminiProcessedText = text.substring("MATCH:".length).trim();
                setState(() {
                    _currentInputState = VoiceInputState.confirmingDescription;
                    _updateStatusAndInstructionText();
                });
            } else if (text.startsWith("MISMATCH:")) {
                // _geminiProcessedText already holds the full mismatch message
                _handleError(_geminiProcessedText, isGeminiError: false, isMismatch: true);
            } else if (text.startsWith("UNCLEAR:")) {
                // _geminiProcessedText already holds the full unclear message
                _handleError(_geminiProcessedText, isGeminiError: false, isUnclear: true);
            } else { // Fallback if Gemini doesn't follow the prefix rule (treat as potential match)
                _geminiProcessedText = text; // Use the full text
                setState(() {
                    _currentInputState = VoiceInputState.confirmingDescription;
                    _updateStatusAndInstructionText(); 
                });
            }
        } else { // text is null or empty from Gemini
            _geminiProcessedText = "Could not get description from Harki."; // Fallback for UI display
            _handleError("Gemini returned no actionable text.", isGeminiError: true);
        }
      }
    } catch (e) {
      _geminiProcessedText = "Error processing with Harki."; // Fallback for UI
      _handleError("Gemini audio processing failed: ${e.toString()}", isGeminiError: true);
    }
  }

  void _confirmDescription() {
    Navigator.pop(context, _geminiProcessedText.trim().isNotEmpty ? _geminiProcessedText.trim() : null);
  }

  void _retryFullSequence() {
    if (mounted) {
      if (_recordedAudioPath != null) {
        final file = File(_recordedAudioPath!);
        file.exists().then((exists) {
          if (exists) {
            file.delete().catchError((e) {
            debugPrint("Error deleting temp file: $e");
            return file;
          });
          }
        });
      }
      setState(() {
        _currentInputState = VoiceInputState.idle;
        _recordedAudioPath = null;
        _geminiProcessedText = '';
        if (!_hasMicPermission || _generativeModel == null) {
            _checkPermissionsAndInitializeServices();
        } else {
            _updateStatusAndInstructionText();
        }
      });
    }
  }

  Future<void> _cleanupRecordedFile() async {
    if (_recordedAudioPath != null) {
      try {
        final file = File(_recordedAudioPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint("Cleaned up temporary audio file: $_recordedAudioPath");
        }
      } catch (e) {
        debugPrint("Error cleaning up audio file: $e");
      }
      _recordedAudioPath = null;
    }
  }

  void _cancelInput() async {
    if (mounted && await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    await _cleanupRecordedFile(); 
    if (mounted) {
      Navigator.pop(context, null);
    }
  }

  void _updateStatusAndInstructionText() {
    final markerDetails = getMarkerInfo(widget.markerType);
    final incidentName = markerDetails?.title ?? widget.markerType.name.capitalizeAllWords();

    switch (_currentInputState) {
      case VoiceInputState.idle:
        _statusText = 'Report: $incidentName';
        _userInstructionText = _hasMicPermission
            ? 'Hold the Mic button to record a short description.'
            : 'Microphone permission needed to record.';
        break;
      case VoiceInputState.recording:
        _statusText = 'Recording...';
        _userInstructionText = 'Release Mic to stop.';
        break;
      case VoiceInputState.recordedReadyToSend:
        _statusText = 'Audio Recorded!';
        _userInstructionText = 'Press "Send" to get a description from Harki.';
        break;
      case VoiceInputState.sendingToGemini:
        _statusText = 'Harki is analyzing audio...';
        _userInstructionText = 'Please wait.';
        break;
      case VoiceInputState.confirmingDescription:
        _statusText = 'Harki understood:';
        _userInstructionText = 'Is this description correct for the $incidentName?';
        break;
      case VoiceInputState.error:
        // Status and instruction text for error states are now primarily set by _handleError.
        // This ensures specific Gemini feedback (mismatch, unclear) is displayed.
        // We can have a generic fallback if _statusText/userInstructionText hasn't been set by _handleError.
        if (_statusText == 'Initializing...' || _statusText.isEmpty || _statusText == 'Report: $incidentName') { // Check if it's a generic or uninitialized state
            _statusText = 'An Error Occurred';
        }
        if (_userInstructionText.isEmpty || _userInstructionText == 'Hold the Mic button to record a short description.' || _userInstructionText == 'Microphone permission needed to record.'){
            _userInstructionText = 'Please try again or cancel.';
        }
        break;
    }
  }

  @override
  void dispose() async {
    try {
      bool isRecording = false;
      try {
        // It's generally safer to avoid `mounted` checks within async dispose methods,
        isRecording = await _audioRecorder.isRecording();
      } catch (e) {
        debugPrint("Error in dispose: checking _audioRecorder.isRecording(): $e");
        // Assuming not recording if there's an error checking.
      }

      if (isRecording) {
        try {
          await _audioRecorder.stop();
          debugPrint("Audio recorder stopped in dispose.");
        } catch (e) {
          debugPrint("Error in dispose: stopping _audioRecorder: $e");
        }
      }
      // Add null check in case initState didn't complete successfully
      _micAnimationController.dispose();
      // Dispose audio recorder (synchronous, must be called after stop)
      _audioRecorder.dispose();
      // Attempt to clean up the recorded file (asynchronous)
      try {
        await _cleanupRecordedFile();
      } catch (e) {
        debugPrint("Error in dispose: _cleanupRecordedFile(): $e");
      }

    } catch (e) {
      // Catch any other synchronous errors from dispose calls like _micAnimationController.dispose()
      debugPrint("Generic error during dispose operations: $e");
    } finally {
      super.dispose();
    }
  }
  
  Widget _buildMicInputControl(Color accentColor) {
    bool canRecord = _hasMicPermission && _generativeModel != null && (_currentInputState == VoiceInputState.idle || _currentInputState == VoiceInputState.recording);
    return GestureDetector(
      onLongPressStart: canRecord && _currentInputState == VoiceInputState.idle ? (details) => _startRecording() : null,
      onLongPressEnd: _currentInputState == VoiceInputState.recording ? (details) => _stopRecording() : null,
      onTap: () {
        if (canRecord && _currentInputState == VoiceInputState.idle) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hold to record, release to stop.")));
        } else if (!canRecord && _currentInputState == VoiceInputState.idle) {
            _checkPermissionsAndInitializeServices(); 
        }
      },
      child: ScaleTransition(
        scale: _micScaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: canRecord ? accentColor : Colors.grey.shade700,
            shape: BoxShape.circle,
            boxShadow: [ BoxShadow( color: Colors.black.withAlpha((0.3 * 255).toInt()), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1),) ],
          ),
          child: Icon(
            _currentInputState == VoiceInputState.recording ? Icons.stop_circle_outlined : Icons.mic,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildSendToGeminiButton(Color accentColor) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.send_to_mobile, color: Colors.white, size: 18),
      label: const Text('SEND TO HARKI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 3,
      ),
      onPressed: _sendAudioToGemini,
    );
  }
  
  Widget _buildProcessingIndicator(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
          const SizedBox(height: 15),
           Text(_userInstructionText, style: TextStyle(fontSize: 15, color: Colors.white.withAlpha((0.8 * 255).toInt())), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildConfirmationControls(Color accentColor) {
    final markerDetails = getMarkerInfo(widget.markerType);
    final incidentName = markerDetails?.title ?? widget.markerType.name.capitalizeAllWords();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          if (_geminiProcessedText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withAlpha((0.5 * 255).toInt()))
                ),
                child: Text(_geminiProcessedText, style: const TextStyle(fontSize: 16, color: Colors.white), textAlign: TextAlign.center),
              ),
        Text('Is this description correct for the $incidentName?', style: TextStyle(fontSize: 15, color: Colors.white.withAlpha((0.8 * 255).toInt())), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.replay_outlined, color: Colors.orangeAccent, size: 20),
              label: const Text('Retry Rec', style: TextStyle(color: Colors.orangeAccent, fontSize: 15)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10)),
              onPressed: _retryFullSequence,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              label: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 3,
              ),
              onPressed: _confirmDescription,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildErrorControls(Color accentColor) {
    // _statusText and _userInstructionText are set by _handleError for mismatch/unclear cases
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // _statusText is displayed by the main title Text widget already
        Padding(
          padding: const EdgeInsets.only(top:0.0, bottom: 15.0), // Reduced top padding as status is above
          child: Text(
            _userInstructionText, // This will contain Gemini's feedback for mismatch/unclear
            style: TextStyle(fontSize: 15, color: Colors.white.withAlpha((0.9 * 255).toInt())),
            textAlign: TextAlign.center,
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Try Again', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          onPressed: _retryFullSequence, // This will restart recording for the original marker type
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final MarkerInfo? markerDetails = getMarkerInfo(widget.markerType);
    final Color accentColor = markerDetails?.color ?? Colors.blueGrey;

    return PopScope( 
      canPop: _currentInputState != VoiceInputState.recording && _currentInputState != VoiceInputState.sendingToGemini,
      onPopInvokedWithResult: (bool didPop, dynamic result) async { 
        if (didPop) return; 
        if (_currentInputState == VoiceInputState.recording || _currentInputState == VoiceInputState.sendingToGemini) {
          // Prevent popping
        } else {
          await _cleanupRecordedFile();
          if (!context.mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
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
              Text(
                _statusText, // This is updated by _updateStatusAndInstructionText or _handleError
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _currentInputState == VoiceInputState.error && !(_statusText == "Incident Type Mismatch" || _statusText == "Audio Unclear or Invalid")
                        ? Colors.redAccent
                        : accentColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
                if (_currentInputState != VoiceInputState.sendingToGemini &&
                    _currentInputState != VoiceInputState.confirmingDescription &&
                    _currentInputState != VoiceInputState.error && // Error state now shows custom _userInstructionText via _buildErrorControls
                    _userInstructionText.isNotEmpty &&
                    _currentInputState != VoiceInputState.idle && // Idle has its own specific instruction
                    _currentInputState != VoiceInputState.recording && // Recording has its own specific instruction
                    _currentInputState != VoiceInputState.recordedReadyToSend // This also has specific instruction
                    )
                Padding(
                    padding: const EdgeInsets.only(bottom: 10.0), // Add some space before the controls
                    child: Text(
                    _userInstructionText, // General instruction text for non-error, non-confirmation states
                    style: TextStyle(fontSize: 16, color: Colors.white.withAlpha((0.9 * 255).toInt())),
                    textAlign: TextAlign.center,
                                  ),
                  ),
              
              // Specific instructions for idle, recording, recordedReadyToSend are handled within their build methods or implicitly by button presence
              if (_currentInputState == VoiceInputState.idle || _currentInputState == VoiceInputState.recording)
                Padding( // Add instruction text specifically for idle/recording state if mic is available
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    _userInstructionText,
                    style: TextStyle(fontSize: 16, color: Colors.white.withAlpha((0.9 * 255).toInt())),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_currentInputState == VoiceInputState.recordedReadyToSend)
                 Padding( // Instruction for ready to send state
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: Text(
                    _userInstructionText,
                    style: TextStyle(fontSize: 16, color: Colors.white.withAlpha((0.9 * 255).toInt())),
                    textAlign: TextAlign.center,
                  ),
                ),


              const SizedBox(height: 10), // Adjusted spacing

              if (_currentInputState == VoiceInputState.idle || _currentInputState == VoiceInputState.recording)
                _buildMicInputControl(accentColor)
              else if (_currentInputState == VoiceInputState.recordedReadyToSend)
                _buildSendToGeminiButton(accentColor)
              else if (_currentInputState == VoiceInputState.sendingToGemini)
                _buildProcessingIndicator(accentColor)
              else if (_currentInputState == VoiceInputState.confirmingDescription)
                _buildConfirmationControls(accentColor)
              else if (_currentInputState == VoiceInputState.error)
                _buildErrorControls(accentColor),

              const SizedBox(height: 25),

              if (_currentInputState != VoiceInputState.sendingToGemini && _currentInputState != VoiceInputState.recording)
                TextButton(
                  onPressed: _cancelInput,
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 15)),
                ),
            ],
          ),
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
    barrierDismissible: false, // Prevents dismissing by tapping outside, user must use buttons
    builder: (BuildContext dialogContext) {
      return IncidentVoiceDescriptionModal(markerType: markerType);
    },
  );
}

// Keep your StringExtension
extension StringExtension on String {
  String capitalizeAllWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }
}