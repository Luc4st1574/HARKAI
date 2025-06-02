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
      final String systemPrompt =
          "You are an AI assistant for Harkai, a citizen security app. "
          "You will receive an audio input from a user describing an incident. "
          "Your task is to listen to the audio and provide a very short, concise text summary of the incident. "
          "This summary will be used as a marker description on a map. Keep it brief and factual. "
          "The user is reporting an incident of type: ${widget.markerType.name}. "
          "For example, if the audio describes 'there's a lot of smoke and flames coming from the bakery on Elm Street', "
          "you might refine it to 'Fire at bakery on Elm Street, heavy smoke.' "
          "If the audio is unclear or too short, indicate that. Respond in the language of the audio if possible, otherwise English."
          "Some user will use the app in Spanish, so you should be able to understand and respond in Spanish if the audio is in that language.";

      _generativeModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(systemPrompt),
        generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 60),
      );
      debugPrint("IncidentModal: Gemini initialized successfully for audio.");
    } catch (e) {
      _handleError("Failed to initialize Gemini: ${e.toString()}");
    }
    if(mounted) _updateStatusAndInstructionText();
  }

  void _handleError(String errorMessage, {bool isGeminiError = false}) {
    if (mounted) {
      _micAnimationController.reverse();
      setState(() {
        _currentInputState = VoiceInputState.error;
        _statusText = isGeminiError ? "Gemini Error: $errorMessage" : errorMessage;
        _updateStatusAndInstructionText();
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
        // Verify file size to ensure something was recorded
        final audioFile = File(path);
        if (await audioFile.exists() && await audioFile.length() > 0) {
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
             _recordedAudioPath = null; // Ensure path is null if recording failed
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
      
      const String mimeType = "audio/aac";

      final response = await _generativeModel!.generateContent([
          Content.data(mimeType, audioBytes)
      ]);

      final text = response.text;
      if (mounted) {
        setState(() {
          _geminiProcessedText = text ?? "Gemini couldn't process the audio or returned no text.";
          _currentInputState = VoiceInputState.confirmingDescription;
          _updateStatusAndInstructionText();
        });
      }
    } catch (e) {
      _handleError("Gemini audio processing failed: ${e.toString()}", isGeminiError: true);
      if (mounted) {
        setState(() {
          _geminiProcessedText = "Could not get description.";
          _currentInputState = VoiceInputState.confirmingDescription;
          _updateStatusAndInstructionText();
        });
      }
    }
  }

  void _confirmDescription() {
    Navigator.pop(context, _geminiProcessedText.trim().isNotEmpty ? _geminiProcessedText.trim() : null);
  }

  void _retryFullSequence() {
    if (mounted) {
      // Clean up previous recording if it exists
      if (_recordedAudioPath != null) {
        final file = File(_recordedAudioPath!);
        file.exists().then((exists) {
          if (exists) file.delete();
        });
      }
      setState(() {
        _currentInputState = VoiceInputState.idle;
        _recordedAudioPath = null;
        _geminiProcessedText = '';
        // Re-check permissions and Gemini init if an error occurred there
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
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    await _cleanupRecordedFile(); // Clean up the file on cancel
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
        _userInstructionText = 'Press "Send" to get a description.';
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
        _userInstructionText = 'Please try again or cancel.';
        break;
    }
  }

  @override
  void dispose() async {
    if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
    }
    _audioRecorder.dispose();
    _micAnimationController.dispose();
    await _cleanupRecordedFile(); // Ensure cleanup on dispose as well
    super.dispose();
  }

  Widget _buildMicInputControl(Color accentColor) {
    bool canRecord = _hasMicPermission && (_currentInputState == VoiceInputState.idle || _currentInputState == VoiceInputState.recording);
    return GestureDetector(
      onLongPressStart: canRecord && _currentInputState == VoiceInputState.idle ? (details) => _startRecording() : null,
      onLongPressEnd: _currentInputState == VoiceInputState.recording ? (details) => _stopRecording() : null,
      onTap: () {
        if (canRecord && _currentInputState == VoiceInputState.idle) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hold to record, release to stop.")));
        } else if (!canRecord && _currentInputState == VoiceInputState.idle) {
            _checkPermissionsAndInitializeServices(); // Attempt to re-check/request if tapped in error state
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
      label: const Text('SEND', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
        ],
      ),
    );
  }

  Widget _buildConfirmationControls(Color accentColor) {
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
        Text(_userInstructionText, style: TextStyle(fontSize: 15, color: Colors.white.withAlpha((0.8 * 255).toInt())), textAlign: TextAlign.center),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top:10.0, bottom: 15.0),
          child: Text(_userInstructionText, style: TextStyle(fontSize: 15, color: Colors.white.withAlpha((0.8 * 255).toInt())), textAlign: TextAlign.center),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Try Again', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          onPressed: _retryFullSequence,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final MarkerInfo? markerDetails = getMarkerInfo(widget.markerType);
    final Color accentColor = markerDetails?.color ?? Colors.blueGrey;

    return PopScope( // Was WillPopScope
      canPop: _currentInputState != VoiceInputState.recording && _currentInputState != VoiceInputState.sendingToGemini,
      onPopInvokedWithResult: (bool didPop, dynamic result) async { // Was onWillPop
        if (didPop) return; // If already popped by system (e.g. back button)
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
                _statusText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _currentInputState == VoiceInputState.error ? Colors.redAccent : accentColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
                if (_currentInputState != VoiceInputState.sendingToGemini &&
                    _currentInputState != VoiceInputState.confirmingDescription &&
                    _currentInputState != VoiceInputState.error && 
                    _userInstructionText.isNotEmpty)
                Text(
                  _userInstructionText,
                  style: TextStyle(fontSize: 16, color: Colors.white.withAlpha((0.9 * 255).toInt())),
                  textAlign: TextAlign.center,
                ),
              
              const SizedBox(height: 25),

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