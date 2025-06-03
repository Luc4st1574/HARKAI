import 'dart:async';
import 'dart:typed_data'; // For Uint8List
import 'dart:io'; // For File operations

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:harkai/core/services/storage_service.dart';
import '../utils/markers.dart';
import '/core/services/speech_service.dart';

// Enum to manage the state of the media input modal
enum MediaInputState {
  // Step 1: Audio
  idle, // Initial state, ready for audio recording
  recordingAudio,
  audioRecordedReadyToSend, // Audio recorded, ready to send to Gemini
  sendingAudioToGemini,
  audioDescriptionReadyForConfirmation, // Gemini processed audio (MATCH), user needs to confirm

  // Step 2: Image (Optional)
  displayingConfirmedAudio, // Confirmed audio shown, user decides to add image or submit audio only
  awaitingImageCapture, // User chose to add image, camera action
  imagePreview, // Image captured, ready for analysis or retake/remove
  sendingImageToGemini, // Sending image to Gemini
  imageAnalyzed, // Image analyzed by Gemini (approved or not), user can submit with image, retake, or remove

  // Shared States
  uploadingMedia, // Final submission process (uploading image if exists)
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
  // Audio specific
  late AudioRecorder _audioRecorder;
  String? _recordedAudioPath;
  String _geminiAudioProcessedText = ''; // Holds the raw response from Gemini for audio
  String _confirmedAudioDescription = ''; // Holds the user-confirmed audio description

  // Image specific
  final ImagePicker _imagePicker = ImagePicker();
  File? _capturedImageFile;
  String _geminiImageAnalysisResultText = ''; // Feedback from Gemini about the image
  bool _isImageApprovedByGemini = false;
  String? _uploadedImageUrl;

  // Shared
  MediaInputState _currentInputState = MediaInputState.idle;
  GenerativeModel? _generativeModel;
  bool _hasMicPermission = false;
  String _statusText = 'Initializing...';
  String _userInstructionText = '';
  late AnimationController _micAnimationController;
  late Animation<double> _micScaleAnimation;

  // Services
  final StorageService _storageService = StorageService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

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
      }
    });
  }

  Future<void> _checkPermissionsAndInitializeServices() async {
    PermissionStatus micStatus = await Permission.microphone.status;
    _hasMicPermission = micStatus.isGranted;

    if (!_hasMicPermission) {
      _hasMicPermission = await SpeechPermissionService().requestMicrophonePermission(openSettingsOnError: true);
      if (!_hasMicPermission && mounted) {
        _handleError("Microphone permission is required for audio recording. Please restart the report to enable it if you wish to use audio.");
      }
    }
    await _initializeGemini();
    if (mounted) _updateStatusAndInstructionText();
  }

  Future<void> _initializeGemini() async {
    final apiKey = dotenv.env['HARKI_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _handleError("Harki AI Key not found. Media processing unavailable.");
      return;
    }
    try {
      const systemInstruction =
          "You are Harki, an AI assistant for the Harkai citizen security app. "
          "Analyze user-provided media (audio or image) based on their specific instructions which will include a pre-selected incident type. "
          "Provide concise responses in the specified formats (MATCH, MISMATCH, INAPPROPRIATE, UNCLEAR). "
          "Prioritize safety and relevance. Respond in the language of the input if identifiable (Spanish/English), else English."
          "Most user inputs will be in Spanish, so prioritize that language unless specified otherwise and do not translate your response to english if spanish was the used languaje by the user.";

      _generativeModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(systemInstruction),
        generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 150),
      );
      debugPrint("IncidentModal: Gemini initialized.");
    } catch (e) {
      _handleError("Failed to initialize Harki AI: ${e.toString()}");
    }
    if (mounted) _updateStatusAndInstructionText();
  }

  void _handleError(String errorMessage, {bool isGeminiError = false, bool isMismatch = false, bool isUnclear = false}) {
    if (mounted) {
      _micAnimationController.reverse();
      setState(() {
        _currentInputState = MediaInputState.error;
        if (isMismatch) {
          _statusText = "Type Mismatch";
        } else if (isUnclear) {
          _statusText = "Input Unclear/Invalid";
        } else if (isGeminiError) {
          _statusText = "Harki Processing Error";
        } else {
          _statusText = "Error";
        }
        _userInstructionText = errorMessage;
      });
    }
  }

  Future<String> _getTempFilePath(String extension) async {
    final directory = await getTemporaryDirectory();
    return '${directory.path}/incident_media_${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  // --- Audio Methods (Step 1) ---
  Future<void> _startRecording() async {
    _clearAllMediaData(clearAudioProcessingResults: true, clearImageProcessingResults: true, updateState: false);
    if (!_hasMicPermission) {
      _handleError("Microphone permission not granted. Cannot record audio.");
      return;
    }
    if (await _audioRecorder.isRecording()) await _audioRecorder.stop();

    try {
      _recordedAudioPath = await _getTempFilePath("m4a");
      const config = RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 48000);
      await _audioRecorder.start(config, path: _recordedAudioPath!);
      if (mounted) {
        _micAnimationController.forward();
        setState(() {
          _currentInputState = MediaInputState.recordingAudio;
          _updateStatusAndInstructionText();
        });
      }
    } catch (e) { _handleError("Could not start recording: $e"); }
  }

  Future<void> _stopRecording() async {
    if (!await _audioRecorder.isRecording()) return;
    try {
      final path = await _audioRecorder.stop();
      if (path != null && File(path).existsSync() && await File(path).length() > 100) {
        _recordedAudioPath = path;
        if (mounted) {
          _micAnimationController.reverse();
          setState(() { _currentInputState = MediaInputState.audioRecordedReadyToSend; _updateStatusAndInstructionText(); });
        }
      } else { _handleError("Audio recording seems empty or was not saved correctly."); _recordedAudioPath = null; }
    } catch (e) { _handleError("Error stopping audio recording: $e"); }
  }

  Future<void> _sendAudioToGemini() async {
    if (_recordedAudioPath == null || _generativeModel == null) {
      _handleError("No audio recorded or Harki AI not ready.", isGeminiError: _generativeModel == null);
      return;
    }
    setState(() { _currentInputState = MediaInputState.sendingAudioToGemini; _updateStatusAndInstructionText(); });

    try {
      final audioFile = File(_recordedAudioPath!);
      final Uint8List audioBytes = await audioFile.readAsBytes();
      final String incidentTypeName = widget.markerType.name.toString().split('.').last.capitalizeAllWords();

      final audioUserInstruction = "Incident Type: '$incidentTypeName'. Process the following audio. "
          "Expected response formats: 'MATCH: [Short summary, max 15 words, of the audio content related to the incident type.]', "
          "'MISMATCH: This audio seems to describe a [Correct Incident Type] incident. Please confirm this type or re-record for the $incidentTypeName incident.', "
          "'UNCLEAR: The audio was not clear enough or did not describe a reportable incident for '$incidentTypeName'. Please try recording again with more details.'";

      final response = await _generativeModel!.generateContent([
          Content('user', [
            TextPart(audioUserInstruction),
            DataPart("audio/aac", audioBytes)
          ])
      ]);
      final text = response.text;
      _geminiAudioProcessedText = text ?? "Harki AI couldn't process the audio."; // Store raw Gemini response

      if (mounted) {
        if (text != null && text.isNotEmpty) {
          if (text.startsWith("MATCH:")) {
            // Don't set _confirmedAudioDescription yet, just store Gemini's suggestion
            _geminiAudioProcessedText = text.substring("MATCH:".length).trim();
            setState(() { _currentInputState = MediaInputState.audioDescriptionReadyForConfirmation; _updateStatusAndInstructionText(); });
          } else if (text.startsWith("MISMATCH:") || text.startsWith("UNCLEAR:")) {
            _handleError(_geminiAudioProcessedText, isMismatch: text.startsWith("MISMATCH:"), isUnclear: text.startsWith("UNCLEAR:"));
          } else {
             // Unexpected but show response
            _handleError("Harki AI audio response format was unexpected: $_geminiAudioProcessedText. Please review or retry.", isGeminiError: true);
          }
        } else { _handleError("Harki AI returned no actionable text for audio.", isGeminiError: true); }
      }
    } catch (e) { _handleError("Harki AI audio processing failed: ${e.toString()}", isGeminiError: true); }
  }

  void _confirmAudioAndProceed() {
    if (_geminiAudioProcessedText.isNotEmpty) {
      _confirmedAudioDescription = _geminiAudioProcessedText; // Now it's confirmed
      _geminiAudioProcessedText = ''; // Clear the raw Gemini text as it's now confirmed
      if (mounted) {
        setState(() {
          _currentInputState = MediaInputState.displayingConfirmedAudio;
          _updateStatusAndInstructionText();
        });
      }
    } else {
      _handleError("No audio description to confirm.");
    }
  }


  // --- Image Methods (Step 2) ---
  Future<void> _captureImage() async {
    // _clearImageData only, keep confirmed audio
    _clearImageData(updateState: false);

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.camera, maxWidth: 1024, imageQuality: 70);
      if (pickedFile != null) {
        setState(() {
          _capturedImageFile = File(pickedFile.path);
          _currentInputState = MediaInputState.imagePreview;
          _geminiImageAnalysisResultText = '';
          _isImageApprovedByGemini = false;
          _uploadedImageUrl = null;
          _updateStatusAndInstructionText();
        });
      } else {
         // If user cancels picker, go back to decision state for image
        setState(() {
          _currentInputState = MediaInputState.displayingConfirmedAudio;
          _updateStatusAndInstructionText();
        });
      }
    } catch (e) { _handleError("Failed to capture image: $e"); }
  }

  Future<void> _sendImageToGemini() async {
    if (_capturedImageFile == null || _generativeModel == null) {
      _handleError("No image captured or Harki AI not ready.", isGeminiError: _generativeModel == null);
      return;
    }
    setState(() { _currentInputState = MediaInputState.sendingImageToGemini; _updateStatusAndInstructionText(); });

    try {
      final Uint8List imageBytes = await _capturedImageFile!.readAsBytes();
      final String mimeType = _capturedImageFile!.path.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final String incidentTypeName = widget.markerType.name.toString().split('.').last.capitalizeAllWords();

      final imageUserInstruction = "Incident Type: '$incidentTypeName'. Process the following image. "
          "1. SAFETY: If image contains explicit sexual content or excessive gore, respond EXACTLY with 'INAPPROPRIATE: The image contains content that cannot be posted.'. "
          "2. RELEVANCE (If safe): Does image genuinely match '$incidentTypeName'? "
          "3. RESPONSE (If safe): "
          "IF MATCHES INCIDENT TYPE: Respond EXACTLY 'MATCH:'. "
          "IF MISMATCH (but valid other type like Fire, Crash, Theft, Pet, Emergency): Respond EXACTLY 'MISMATCH: This image looks more like a [Correct Incident Type] alert. Please confirm this type or retake image for $incidentTypeName incident.'. "
          "IF IRRELEVANT/UNCLEAR: Respond EXACTLY 'UNCLEAR: The image is not clear enough or does not seem to describe a reportable incident for '$incidentTypeName'. Please try retaking the picture.'.";

      final response = await _generativeModel!.generateContent([
          Content('user', [
            TextPart(imageUserInstruction),
            DataPart(mimeType, imageBytes)
          ])
      ]);
      final text = response.text;
      _geminiImageAnalysisResultText = text ?? "Harki AI couldn't process the image.";
      debugPrint("Gemini Image Response: $_geminiImageAnalysisResultText");

      if (mounted) {
        if (text != null && text.isNotEmpty) {
          if (text.startsWith("MATCH:")) {
            _isImageApprovedByGemini = true;
            _geminiImageAnalysisResultText = "Image approved by Harki AI.";
          } else { // INAPPROPRIATE, UNCLEAR, MISMATCH, or unexpected
            _isImageApprovedByGemini = false;
            // _geminiImageAnalysisResultText is already Gemini's response
          }
        } else {
            _isImageApprovedByGemini = false;
            _geminiImageAnalysisResultText = "Harki AI returned no actionable text for image.";
        }
        setState(() { _currentInputState = MediaInputState.imageAnalyzed; _updateStatusAndInstructionText(); });
      }
    } catch (e) {
      _isImageApprovedByGemini = false;
      _handleError("Harki AI image processing failed: ${e.toString()}", isGeminiError: true);
    }
  }

  void _removeImageAndGoBackToDecision() {
    _clearImageData(updateState: false);
    if(mounted) {
      setState(() {
        _currentInputState = MediaInputState.displayingConfirmedAudio;
        _updateStatusAndInstructionText();
      });
    }
  }


  // --- Data Clearing and Final Submission ---
  void _clearImageData({bool updateState = true}) {
    if(mounted){
      setState(() {
        _capturedImageFile = null;
        _geminiImageAnalysisResultText = '';
        _isImageApprovedByGemini = false;
        _uploadedImageUrl = null;
        if (updateState && !_currentInputState.name.startsWith("step2_")) { // Only reset to idle if not in step 2
            _currentInputState = MediaInputState.idle;
            _updateStatusAndInstructionText();
        } else if (updateState && _currentInputState.name.startsWith("step2_")){
            // If in step 2 and clearing image, go back to the decision point of step 2
            _currentInputState = MediaInputState.displayingConfirmedAudio;
            _updateStatusAndInstructionText();
        }
      });
    }
  }

  void _clearAllMediaData({bool clearAudioProcessingResults = true, bool clearImageProcessingResults = true, bool updateState = true}) {
    if (mounted) {
      setState(() {
        _recordedAudioPath = null;
        _capturedImageFile = null;
        _uploadedImageUrl = null;

        if (clearAudioProcessingResults) {
          _geminiAudioProcessedText = '';
          _confirmedAudioDescription = '';
        }
        if (clearImageProcessingResults) {
          _geminiImageAnalysisResultText = '';
          _isImageApprovedByGemini = false;
        }
        if (updateState) {
          _currentInputState = MediaInputState.idle;
          _updateStatusAndInstructionText();
        }
      });
    }
  }


  Future<void> _finalSubmitIncident() async {
    // Image Upload if an approved image exists and hasn't been uploaded
    if (_capturedImageFile != null && _isImageApprovedByGemini && _uploadedImageUrl == null) {
      if (_currentUser?.uid != null) {
        setState(() { _currentInputState = MediaInputState.uploadingMedia; _updateStatusAndInstructionText(); });
        _uploadedImageUrl = await _storageService.uploadIncidentImage(
            imageFile: _capturedImageFile!,
            userId: _currentUser!.uid,
            incidentType: widget.markerType.name);
        if (_uploadedImageUrl == null && mounted) {
          _handleError("Failed to upload image. Please try again or submit without image.");
          // Go back to a state where user can decide to submit without image or retry upload
          setState(() { _currentInputState = MediaInputState.imageAnalyzed; _updateStatusAndInstructionText();});
          return;
        }
      } else {
        _handleError("User not logged in. Cannot upload image.");
        setState(() { _currentInputState = MediaInputState.imageAnalyzed; _updateStatusAndInstructionText();});
        return;
      }
    }

    // Final check: must have confirmed audio description. Image is optional.
    if (_confirmedAudioDescription.isNotEmpty) {
        if (mounted) {
            debugPrint("Submitting: Audio='$_confirmedAudioDescription', ImageUrl='$_uploadedImageUrl'");
            Navigator.pop(context, {'description': _confirmedAudioDescription, 'imageUrl': _uploadedImageUrl});
        }
    } else {
        // This case should ideally not be reached if flow is correct, as audio must be confirmed first.
        _handleError("No confirmed audio description available to submit. Please complete audio step first or cancel.");
         setState(() { _currentInputState = MediaInputState.idle; _updateStatusAndInstructionText();}); // Go back to start
    }
  }

  Future<void> _deleteTempFiles() async {
    if (_recordedAudioPath != null) {
      try { final file = File(_recordedAudioPath!); if(await file.exists()) await file.delete(); } catch (e) { debugPrint("Error deleting temp audio: $e");}
      _recordedAudioPath = null;
    }
  }

  void _retryFullProcess() async { 
    await _deleteTempFiles();
    _clearAllMediaData(updateState: false); // Clears everything including confirmed audio
    if (mounted) {
      setState(() {
        _currentInputState = MediaInputState.idle;
        if (!_hasMicPermission || _generativeModel == null) {
            _checkPermissionsAndInitializeServices();
        } else {
            _updateStatusAndInstructionText();
        }
      });
    }
  }

  void _cancelInput() async {
    if (mounted && await _audioRecorder.isRecording()) {
      try { await _audioRecorder.stop(); } catch (e) { debugPrint("Error stopping recorder on cancel: $e"); }
    }
    await _deleteTempFiles();
    _clearAllMediaData(updateState: false);
    if (mounted) Navigator.pop(context, null);
  }

  void _updateStatusAndInstructionText() {
    final markerDetails = getMarkerInfo(widget.markerType);
    final incidentName = markerDetails?.title ?? widget.markerType.name.capitalizeAllWords();

    switch (_currentInputState) {
      // Step 1: Audio
      case MediaInputState.idle:
        _statusText = 'Step 1: Report Audio for $incidentName';
        _userInstructionText = 'Hold Mic to record audio description.';
        if (!_hasMicPermission) _userInstructionText = 'Mic permission needed. You can grant it in settings or restart the report process.';
        if (_generativeModel == null) _userInstructionText = "Harki AI is initializing. Please wait.";
        break;
      case MediaInputState.recordingAudio:
        _statusText = 'Recording Audio...';
        _userInstructionText = 'Release Mic to stop.';
        break;
      case MediaInputState.audioRecordedReadyToSend:
        _statusText = 'Audio Recorded!';
        _userInstructionText = 'Tap "Send Audio to Harki" for analysis.';
        break;
      case MediaInputState.sendingAudioToGemini:
        _statusText = 'Harki Analyzing Audio...';
        _userInstructionText = 'Please wait.';
        break;
      case MediaInputState.audioDescriptionReadyForConfirmation:
        _statusText = 'Confirm Audio Description:';
        _userInstructionText = 'Harki suggests: "$_geminiAudioProcessedText".\nIs this correct?';
        break;

      // Step 2: Image (Optional)
      case MediaInputState.displayingConfirmedAudio:
        _statusText = 'Step 2: Add Image (Optional)';
        _userInstructionText = 'Confirmed Audio: "$_confirmedAudioDescription"\nAdd an image or submit with audio only.';
        break;
      case MediaInputState.awaitingImageCapture: 
        _statusText = 'Step 2: Capturing Image...';
        _userInstructionText = 'Please use the camera.';
        break;
      case MediaInputState.imagePreview:
        _statusText = 'Step 2: Image Preview';
        _userInstructionText = 'Analyze this image with Harki, retake it, or remove it to proceed with audio only.';
        if (_confirmedAudioDescription.isNotEmpty) {
            _userInstructionText = 'Confirmed Audio: "$_confirmedAudioDescription"\n\nThen: $_userInstructionText';
        }
        break;
      case MediaInputState.sendingImageToGemini:
        _statusText = 'Harki Analyzing Image...';
        _userInstructionText = 'Please wait.';
        if (_confirmedAudioDescription.isNotEmpty) {
            _userInstructionText = 'Confirmed Audio: "$_confirmedAudioDescription"\n\nThen: $_userInstructionText';
        }
        break;
      case MediaInputState.imageAnalyzed:
        _statusText = 'Step 2: Image Analyzed';
        if (_isImageApprovedByGemini) {
          _userInstructionText = "Image approved by Harki!\n";
        } else {
          _userInstructionText = "Image Feedback from Harki: $_geminiImageAnalysisResultText\n";
        }
        _userInstructionText += "Submit with current details, retake image, or remove image.";
        if (_confirmedAudioDescription.isNotEmpty) {
            _userInstructionText = 'Confirmed Audio: "$_confirmedAudioDescription"\n\n$_userInstructionText';
        }
        break;

      // Shared
      case MediaInputState.uploadingMedia:
        _statusText = "Submitting Incident...";
        _userInstructionText = "Uploading media, please wait.";
        break;
      case MediaInputState.error:
        // Status and instruction text already set by _handleError
        break;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _performAsyncCleanupTasks();
    try { _micAnimationController.dispose(); } catch (e) { debugPrint("Error disposing _micAnimationController: $e");}
    try { _audioRecorder.dispose(); } catch (e) { debugPrint("Error disposing _audioRecorder: $e");}
    super.dispose();
  }

  Future<void> _performAsyncCleanupTasks() async {
    // Simplified cleanup
    try {
      if (mounted && await _audioRecorder.isRecording()) { // Check mounted before async gap
        await _audioRecorder.stop();
      }
      await _deleteTempFiles();
    } catch (e) {
      debugPrint("Error during async cleanup: $e");
    }
  }

  // --- UI Builder Methods ---
  Widget _buildMicInputControl(Color accentColor) {
    bool canRecordAudio = _hasMicPermission && _generativeModel != null &&
                          _currentInputState == MediaInputState.idle; // Mic only in idle state for Step 1

    return GestureDetector(
      onLongPressStart: canRecordAudio ? (details) => _startRecording() : null,
      onLongPressEnd: _currentInputState == MediaInputState.recordingAudio ? (details) => _stopRecording() : null,
      onTap: () {
        if (canRecordAudio && _currentInputState != MediaInputState.recordingAudio) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hold to record, release to stop.")));
        } else if (!canRecordAudio && _currentInputState == MediaInputState.idle) { 
            _checkPermissionsAndInitializeServices();
        }
      },
      child: ScaleTransition(
        scale: _micScaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: canRecordAudio ? accentColor : Colors.grey.shade700,
            shape: BoxShape.circle,
            boxShadow: [ BoxShadow( color: Colors.black.withAlpha((0.3 * 255).toInt()), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1),) ],
          ),
          child: Icon(
            _currentInputState == MediaInputState.recordingAudio ? Icons.stop_circle_outlined : Icons.mic,
            color: Colors.white, size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraInputControlForStep2(Color accentColor) {
    bool canCaptureImage = _generativeModel != null &&
                            (_currentInputState == MediaInputState.displayingConfirmedAudio ||
                            _currentInputState == MediaInputState.imagePreview ||
                            _currentInputState == MediaInputState.imageAnalyzed);

    if (!canCaptureImage) return const SizedBox.shrink();

    // Determine the label based on whether an image already exists
    String cameraButtonLabel = _capturedImageFile == null ? "Add Picture" : "Retake Picture";

    return Column( // Use a Column to place the label below the button
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.camera_alt, size: 36),
          color: accentColor, // Icon color
          padding: const EdgeInsets.all(16), // Adjusted padding
          style: IconButton.styleFrom(
            backgroundColor: accentColor.withAlpha((0.15 * 255).toInt()), // Slightly more subtle background
            shape: const CircleBorder(),
            side: BorderSide(color: accentColor.withOpacity(0.7), width: 1.5),
            elevation: 2,
          ),
          onPressed: _captureImage,
          tooltip: cameraButtonLabel, // Tooltip also uses the dynamic label
        ),
        const SizedBox(height: 4), // Space between button and label
        Text(
          cameraButtonLabel,
          style: TextStyle(
            color: accentColor, // Label color matches accent
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Color accentColor) {
    List<Widget> buttons = [];

    switch (_currentInputState) {
      // Step 1 Actions
      case MediaInputState.audioRecordedReadyToSend:
        buttons.add(ElevatedButton.icon(
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          label: const Text('Send Audio to Harki', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          onPressed: _sendAudioToGemini,
        ));
        break;
      case MediaInputState.audioDescriptionReadyForConfirmation:
        buttons.add(ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
          label: const Text('Confirm Audio & Proceed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed: _confirmAudioAndProceed,
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(TextButton(
            onPressed: _retryFullProcess, 
            child: Text('Re-record Audio', style: TextStyle(color: accentColor))
        ));
        break;

      // Step 2 Actions
      case MediaInputState.displayingConfirmedAudio:
        buttons.add(ElevatedButton.icon(
          icon: const Icon(Icons.send_outlined, color: Colors.white, size: 20), 
          label: const Text('Submit with Audio Only', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed: _finalSubmitIncident, 
        ));
        break;
      case MediaInputState.imagePreview:
        buttons.add(ElevatedButton.icon(
          icon: const Icon(Icons.science_outlined, color: Colors.white, size: 18),
          label: const Text('Analyze Image with Harki', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          onPressed: _sendImageToGemini,
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(TextButton(
            onPressed: _removeImageAndGoBackToDecision,
            child: Text('Use Audio Only (Remove Image)', style: TextStyle(color: Colors.grey.shade400))
        ));
        break;
      case MediaInputState.imageAnalyzed:
        if (_isImageApprovedByGemini) {
          buttons.add(ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            label: const Text('Submit with Audio & Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            onPressed: _finalSubmitIncident,
          ));
            buttons.add(const SizedBox(height: 10));
            buttons.add(TextButton( // Option to submit audio only even if image was approved
            onPressed: () {
              _clearImageData(updateState:false); // Clear image data but don't change state yet
              _finalSubmitIncident(); // Submit with only audio
            },
            child: Text('Submit Audio Only Instead', style: TextStyle(color: Colors.grey.shade400))
          ));
        } else {
              buttons.add(ElevatedButton.icon(
                icon: const Icon(Icons.send_outlined, color: Colors.white, size: 20),
                label: const Text('Submit with Audio Only', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                onPressed: _finalSubmitIncident, // This will submit audio only as image is not approved/present
            ));
        }
        // "Retake Image" is implicitly handled by the camera button still being visible.
        // "Remove Image" is handled by the 'X' button on the preview.
        break;
      default:
        break;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: buttons);
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

  Widget _buildErrorControls(Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Text(_userInstructionText, style: TextStyle(fontSize: 15, color: Colors.white.withAlpha((0.9 * 255).toInt())), textAlign: TextAlign.center),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Try Again from Start', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
          onPressed: _retryFullProcess,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final MarkerInfo? markerDetails = getMarkerInfo(widget.markerType);
    final Color accentColor = markerDetails?.color ?? Colors.blueGrey;

    bool isProcessingAny = _currentInputState == MediaInputState.sendingAudioToGemini ||
                          _currentInputState == MediaInputState.sendingImageToGemini ||
                          _currentInputState == MediaInputState.uploadingMedia;

    bool isStep1Active = _currentInputState == MediaInputState.idle ||
                        _currentInputState == MediaInputState.recordingAudio ||
                        _currentInputState == MediaInputState.audioRecordedReadyToSend ||
                        _currentInputState == MediaInputState.sendingAudioToGemini ||
                        _currentInputState == MediaInputState.audioDescriptionReadyForConfirmation;

    bool isStep2Active = _currentInputState.name.startsWith("step2_");


    return PopScope(
      canPop: !isProcessingAny && _currentInputState != MediaInputState.recordingAudio,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return; 
        if (isProcessingAny || _currentInputState == MediaInputState.recordingAudio) {
          // Prevent popping
        } else {
          _cancelInput(); 
        }
      },
      child: Dialog(
        backgroundColor: const Color(0xFF001F3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0), side: BorderSide(color: accentColor, width: 2)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _statusText,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _currentInputState == MediaInputState.error && !(_statusText == "Type Mismatch" || _statusText == "Input Unclear/Invalid") ? Colors.redAccent : accentColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(_userInstructionText, style: TextStyle(fontSize: 14, color: Colors.white.withAlpha((0.8 * 255).toInt())), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 15),

              // Display Confirmed Audio Description in Step 2
              if (isStep2Active && _confirmedAudioDescription.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Column(
                    children: [
                      Text("Confirmed Audio:", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(5)),
                        child: Text(_confirmedAudioDescription, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                      ),
                      const SizedBox(height:10),
                      Divider(color: accentColor.withOpacity(0.3)),
                      const SizedBox(height:10),
                    ],
                  ),
                ),


              // Image Preview Area for Step 2
              if (_capturedImageFile != null && isStep2Active)
                Padding(
                  padding: const EdgeInsets.only(bottom:10.0),
                  child: Column(
                    children: [
                      Text("Image for Incident:", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 5),
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_capturedImageFile!, height: 120, fit: BoxFit.contain)
                          ),
                            if (_currentInputState == MediaInputState.imagePreview || _currentInputState == MediaInputState.imageAnalyzed)
                            Padding( // Add padding to make the icon easier to tap
                              padding: const EdgeInsets.all(4.0),
                              child: Tooltip(
                                message: "Remove Image",
                                child: InkWell( // Use InkWell for better tap feedback
                                  onTap: _removeImageAndGoBackToDecision,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.cancel, color: Colors.white, size: 24),
                                  ),
                                ),
                              ),
                            )
                        ],
                      ),

                      if (_currentInputState == MediaInputState.imageAnalyzed)
                        Padding(
                          padding: const EdgeInsets.only(top:4.0),
                          child: Text(
                            _isImageApprovedByGemini ? "Harki: Image looks good!" : (_geminiImageAnalysisResultText.isNotEmpty ? "Harki: $_geminiImageAnalysisResultText" : "Harki: Analysis complete."),
                            style: TextStyle(color: _isImageApprovedByGemini ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height:10),
                        Divider(color: accentColor.withOpacity(0.3)),
                        const SizedBox(height:10),
                    ],
                  ),
                ),
              // --- End of Display Areas ---

              const SizedBox(height: 10),

              if (isProcessingAny)
                _buildProcessingIndicator(accentColor)
              else if (_currentInputState == MediaInputState.error)
                _buildErrorControls(accentColor)
              else
                Column( // Main controls column
                  children: [
                    if (isStep1Active) 
                      _buildMicInputControl(accentColor),
                    if (isStep2Active && 
                        _currentInputState != MediaInputState.sendingImageToGemini && 
                        _currentInputState != MediaInputState.uploadingMedia) 
                        _buildCameraInputControlForStep2(accentColor),

                    const SizedBox(height: 15),
                    _buildActionButtons(accentColor),
                  ],
                ),

              const SizedBox(height: 20),
              if (!isProcessingAny && _currentInputState != MediaInputState.recordingAudio)
                TextButton(
                  onPressed: _cancelInput,
                  child: const Text('Cancel Report', style: TextStyle(color: Colors.grey, fontSize: 15)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<Map<String, String?>?> showIncidentVoiceDescriptionDialog({
  required BuildContext context,
  required MakerType markerType,
}) async {
  return await showDialog<Map<String, String?>?>(
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