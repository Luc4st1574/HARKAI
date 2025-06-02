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
import '/core/services/speech_service.dart'; // Assuming this path is correct

// Enum to manage the state of the media input modal
enum MediaInputState {
  idle,
  recordingAudio,
  audioRecordedReadyToSend,
  sendingAudioToGemini,
  confirmingAudioDescription, // Audio processed, description ready, NOW camera can be shown

  imagePreview, // After image is captured
  sendingImageToGemini,
  // confirmingImageDescription, // Image processed, approval status known (merged into imagePreview)

  uploadingMedia,
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
  String _geminiAudioProcessedText = '';

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
        // setState(() {}); // _updateStatusAndInstructionText calls setState
      }
    });
  }

  Future<void> _checkPermissionsAndInitializeServices() async {
    PermissionStatus micStatus = await Permission.microphone.status;
    _hasMicPermission = micStatus.isGranted;

    if (!_hasMicPermission) {
      _hasMicPermission = await SpeechPermissionService().requestMicrophonePermission(openSettingsOnError: true);
      if (!_hasMicPermission && mounted) {
        _handleError("Microphone permission is required for audio recording. You can still report with an image if camera permission is granted.");
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
      const systemInstruction = // General persona
          "You are Harki, an AI assistant for the Harkai citizen security app. "
          "Analyze user-provided media (audio or image) based on their specific instructions which will include a pre-selected incident type. "
          "Provide concise responses in the specified formats (MATCH, MISMATCH, INAPPROPRIATE, UNCLEAR). "
          "Prioritize safety and relevance. Respond in the language of the input if identifiable (Spanish/English), else English.";

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

  // --- Audio Methods ---
  Future<void> _startRecording() async {
    _clearImageData(updateState: false); // Clear any previous image attempt if starting audio
    if (!_hasMicPermission) {
      _handleError("Microphone permission not granted. Cannot record audio.");
      return;
    }
    if (await _audioRecorder.isRecording()) await _audioRecorder.stop();
    
    try {
      _recordedAudioPath = await _getTempFilePath("m4a"); // m4a is good for AAC
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
            DataPart("audio/aac", audioBytes) // Ensure mime type matches encoder (m4a -> aac)
          ])
      ]);
      final text = response.text;
      _geminiAudioProcessedText = text ?? "Harki AI couldn't process the audio.";

      if (mounted) {
        if (text != null && text.isNotEmpty) {
          if (text.startsWith("MATCH:")) {
            _geminiAudioProcessedText = text.substring("MATCH:".length).trim();
            setState(() { _currentInputState = MediaInputState.confirmingAudioDescription; _updateStatusAndInstructionText(); });
          } else if (text.startsWith("MISMATCH:") || text.startsWith("UNCLEAR:")) {
            _handleError(_geminiAudioProcessedText, isMismatch: text.startsWith("MISMATCH:"), isUnclear: text.startsWith("UNCLEAR:"));
          } else {
            _geminiAudioProcessedText = text; // Unexpected but show response
            _handleError("Harki AI audio response format was unexpected: $text. Please review or retry.", isGeminiError: true);
          }
        } else { _handleError("Harki AI returned no actionable text for audio.", isGeminiError: true); }
      }
    } catch (e) { _handleError("Harki AI audio processing failed: ${e.toString()}", isGeminiError: true); }
  }

  // --- Image Methods ---
  Future<void> _captureImage() async {
    // If user was in audio flow, stop it.
    if (_currentInputState == MediaInputState.recordingAudio) await _stopRecording();
    // _clearAudioData(updateState: false); // Don't clear audio text if it was already processed. User might want to add image to existing audio desc.

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.camera, maxWidth: 1024, imageQuality: 70);
      if (pickedFile != null) {
        setState(() {
          _capturedImageFile = File(pickedFile.path);
          _currentInputState = MediaInputState.imagePreview;
          _geminiImageAnalysisResultText = ''; // Reset previous image analysis
          _isImageApprovedByGemini = false;   // Reset approval
          _uploadedImageUrl = null;           // Reset uploaded URL
          _updateStatusAndInstructionText();
        });
      }
    } catch (e) { _handleError("Failed to capture image: $e"); }
  }
  
  void _clearImageData({bool updateState = true}) {
    if(mounted){
      setState(() {
        _capturedImageFile = null;
        _geminiImageAnalysisResultText = '';
        _isImageApprovedByGemini = false;
        _uploadedImageUrl = null;
        if (updateState) {
            // If clearing image, and we were in an image state, go back to confirming audio (if audio exists) or idle
            if (_geminiAudioProcessedText.isNotEmpty && _currentInputState != MediaInputState.confirmingAudioDescription) {
                _currentInputState = MediaInputState.confirmingAudioDescription;
            } else if (_currentInputState != MediaInputState.idle && _currentInputState != MediaInputState.error){
                _currentInputState = MediaInputState.idle;
            }
            _updateStatusAndInstructionText();
        }
      });
    }
  }
  
  void _clearAudioData({bool updateState = true}) {
    if(mounted){
      setState(() {
        _recordedAudioPath = null;
        _geminiAudioProcessedText = '';
        if (updateState) {
             // If clearing audio, and we were in an audio state, go back to image preview (if image exists) or idle
            if (_capturedImageFile != null && _currentInputState != MediaInputState.imagePreview) {
                _currentInputState = MediaInputState.imagePreview;
            } else if(_currentInputState != MediaInputState.idle && _currentInputState != MediaInputState.error) {
                _currentInputState = MediaInputState.idle;
            }
            _updateStatusAndInstructionText();
        }
      });
    }
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
            _geminiImageAnalysisResultText = "Image approved by Harki AI."; // User-friendly message
            setState(() { _currentInputState = MediaInputState.imagePreview; _updateStatusAndInstructionText(); });
          } else if (text.startsWith("INAPPROPRIATE:") || text.startsWith("UNCLEAR:") || text.startsWith("MISMATCH:")) {
            _isImageApprovedByGemini = false;
            // _geminiImageAnalysisResultText is already set to Gemini's response
            // Let _updateStatusAndInstructionText show this feedback.
            setState(() { _currentInputState = MediaInputState.imagePreview; _updateStatusAndInstructionText(); });
          } else {
            _isImageApprovedByGemini = false;
            _handleError("Harki AI image response format was unexpected: $text", isGeminiError: true);
          }
        } else { _isImageApprovedByGemini = false; _handleError("Harki AI returned no actionable text for image.", isGeminiError: true); }
      }
    } catch (e) { _isImageApprovedByGemini = false; _handleError("Harki AI image processing failed: ${e.toString()}", isGeminiError: true); }
  }

  // --- Combined Confirmation & Cleanup ---
  Future<void> _confirmAndSubmitData() async {
    if (_capturedImageFile != null && _isImageApprovedByGemini && _uploadedImageUrl == null) {
      if (_currentUser?.uid != null) {
        setState(() { _currentInputState = MediaInputState.uploadingMedia; _updateStatusAndInstructionText(); });
        _uploadedImageUrl = await _storageService.uploadIncidentImage(
            imageFile: _capturedImageFile!,
            userId: _currentUser!.uid,
            incidentType: widget.markerType.name);
        if (_uploadedImageUrl == null && mounted) {
          _handleError("Failed to upload image. Please try again or submit without image.");
          return;
        }
      } else {
        _handleError("User not logged in. Cannot upload image.");
        return;
      }
    }

    final String? finalDescription = _geminiAudioProcessedText.trim().isNotEmpty ? _geminiAudioProcessedText.trim() : null;
    
    if (finalDescription != null || _uploadedImageUrl != null) { // Must have at least one piece of info
        if (mounted) {
            Navigator.pop(context, {'description': finalDescription, 'imageUrl': _uploadedImageUrl});
        }
    } else {
        _handleError("No description or approved image available to submit. Please provide input or cancel.");
    }
  }
  
  Future<void> _deleteTempFiles() async {
    if (_recordedAudioPath != null) {
      try { final file = File(_recordedAudioPath!); if(await file.exists()) await file.delete(); } catch (e) { debugPrint("Error deleting temp audio: $e");}
      _recordedAudioPath = null;
    }
    // _capturedImageFile is handled by image_picker cache or OS. We don't manage its temp file directly after picking.
    // We only care about it if we copied it, which we don't.
  }

  void _retryInputSequence() async {
    await _deleteTempFiles();
    _clearAudioData(updateState: false);
    _clearImageData(updateState: false);
    if (mounted) {
      setState(() {
        _currentInputState = MediaInputState.idle;
        if (!_hasMicPermission || _generativeModel == null) {
             _checkPermissionsAndInitializeServices(); // Re-check if essential services failed
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
    _clearAudioData(updateState: false);
    _clearImageData(updateState: false);
    if (mounted) Navigator.pop(context, null); // Return null indicating cancellation
  }

  void _updateStatusAndInstructionText() {
    final markerDetails = getMarkerInfo(widget.markerType);
    final incidentName = markerDetails?.title ?? widget.markerType.name.capitalizeAllWords();

    switch (_currentInputState) {
      case MediaInputState.idle:
        _statusText = 'Report: $incidentName';
        _userInstructionText = 'Hold Mic for audio. After audio is processed, you can add an image.';
        if (!_hasMicPermission) _userInstructionText = 'Mic permission needed for audio. Camera can be used after audio step if audio is successful.';
        if (_generativeModel == null) _userInstructionText = "Harki AI is initializing or unavailable. Please wait.";
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
      case MediaInputState.confirmingAudioDescription:
        _statusText = 'Audio Processed by Harki:';
        if (_geminiAudioProcessedText.isNotEmpty) {
          _userInstructionText = 'Harki suggests description: "$_geminiAudioProcessedText".\nTap Camera to add an image, or Confirm to submit.';
        } else {
          _userInstructionText = 'Harki could not generate a description from audio. You can try recording audio again, or tap Camera to add an image, then submit.';
        }
        break;
      case MediaInputState.imagePreview:
        _statusText = 'Image Preview';
        if (_isImageApprovedByGemini) {
          _userInstructionText = "Image approved by Harki! Submit now, or re-record audio if needed.";
        } else if (_geminiImageAnalysisResultText.isNotEmpty) {
          // This means Gemini processed image and gave feedback (e.g. mismatch, unclear, inappropriate)
          _userInstructionText = _geminiImageAnalysisResultText;
          _userInstructionText += "\nTap Camera to retake, or Submit with audio only (if available).";
        } else {
          _userInstructionText = 'Tap "Analyze Image with Harki", or Retake. You can submit with audio only.';
        }
        break;
      case MediaInputState.sendingImageToGemini:
        _statusText = 'Harki Analyzing Image...';
        _userInstructionText = 'Please wait.';
        break;
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
    _performAsyncCleanupTasks(); // Defined as in previous response
    try { _micAnimationController.dispose(); } catch (e) { debugPrint("Error disposing _micAnimationController: $e");}
    try { _audioRecorder.dispose(); } catch (e) { debugPrint("Error disposing _audioRecorder: $e");}
    super.dispose();
  }

  Future<void> _performAsyncCleanupTasks() async {
    final recorder = _audioRecorder;
    final audioPath = _recordedAudioPath;
    try {
      bool isRecording = false;
      try { isRecording = await recorder.isRecording(); } catch (e) { debugPrint("Error checking recorder status: $e");}
      if (isRecording) {
        try { await recorder.stop(); } catch (e) { debugPrint("Error stopping recorder in cleanup: $e");}
      }
      if (audioPath != null) {
        try {
          final file = File(audioPath);
          if (await file.exists()) await file.delete();
        } catch (e) { debugPrint("Error deleting temp audio in cleanup: $e");}
      }
    } catch (e) { debugPrint("Generic error during async cleanup: $e");}
  }


  // --- UI Builder Methods ---
  Widget _buildMicInputControl(Color accentColor) {
    // Mic is available in idle, or if image is previewed/approved (to re-record audio)
    bool canRecordAudio = _hasMicPermission && _generativeModel != null &&
                    (_currentInputState == MediaInputState.idle ||
                      _currentInputState == MediaInputState.imagePreview || // Can add/change audio when image is previewed
                      _currentInputState == MediaInputState.confirmingAudioDescription); // Can re-record audio

    return GestureDetector(
      onLongPressStart: canRecordAudio ? (details) => _startRecording() : null,
      onLongPressEnd: _currentInputState == MediaInputState.recordingAudio ? (details) => _stopRecording() : null,
      onTap: () {
        if (canRecordAudio && _currentInputState != MediaInputState.recordingAudio) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hold to record, release to stop.")));
        } else if (!_hasMicPermission) {
            _checkPermissionsAndInitializeServices(); // Try to get permissions again
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

  Widget _buildCameraInputControl(Color accentColor) {
    // Camera button is visible only AFTER audio is processed and description is being confirmed.
    bool canCaptureImage = _generativeModel != null &&
                          _currentInputState == MediaInputState.confirmingAudioDescription ||
                          _currentInputState == MediaInputState.imagePreview; // Allow retake if already in image preview

    if (!canCaptureImage) return SizedBox.shrink(); // Don't show camera button initially

    return IconButton(
      icon: Icon(Icons.camera_alt, size: 36),
      color: accentColor,
      padding: const EdgeInsets.all(20),
      style: IconButton.styleFrom(
        backgroundColor: accentColor.withAlpha((0.2 * 255).toInt()),
        shape: CircleBorder(),
        side: BorderSide(color: accentColor, width: 1.5)
      ),
      onPressed: _captureImage,
      tooltip: "Add/Retake Image",
    );
  }
  
  Widget _buildActionButtons(Color accentColor) {
    bool showSendAudio = _currentInputState == MediaInputState.audioRecordedReadyToSend;
    bool showAnalyzeImage = _currentInputState == MediaInputState.imagePreview && _capturedImageFile != null && !_isImageApprovedByGemini && _geminiImageAnalysisResultText.isEmpty; // Only if not yet analyzed or analysis failed
    bool showConfirmSubmit = (_currentInputState == MediaInputState.confirmingAudioDescription || (_currentInputState == MediaInputState.imagePreview && _isImageApprovedByGemini)) &&
                             (_geminiAudioProcessedText.isNotEmpty || _isImageApprovedByGemini); // Enable if audio desc OR approved image


    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSendAudio)
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            label: const Text('Send Audio to Harki', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            onPressed: _sendAudioToGemini,
          ),
        if (showAnalyzeImage)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.science_outlined, color: Colors.white, size: 18),
              label: const Text('Analyze Image with Harki', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              onPressed: _sendImageToGemini,
            ),
          ),
        if(showConfirmSubmit)
            Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                label: Text(
                    _capturedImageFile != null && _isImageApprovedByGemini ? 'Submit with Image' : 'Submit Audio Description',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                ),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                ),
                onPressed: _confirmAndSubmitData,
              ),
            ),
      ],
    );
  }
  
  Widget _buildProcessingIndicator(Color accentColor) { // Unchanged
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
  
  Widget _buildErrorControls(Color accentColor) { // Unchanged
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Text(_userInstructionText, style: TextStyle(fontSize: 15, color: Colors.white.withAlpha((0.9 * 255).toInt())), textAlign: TextAlign.center),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Try Again', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
          onPressed: _retryInputSequence,
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

    return PopScope(
      canPop: !isProcessingAny && _currentInputState != MediaInputState.recordingAudio,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (isProcessingAny || _currentInputState == MediaInputState.recordingAudio) {
          // Prevent popping
        } else {
          await _deleteTempFiles();
          _clearAudioData(updateState: false);
          _clearImageData(updateState: false);
          if (!mounted) return;
          Navigator.of(context).pop();
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
              Text(_userInstructionText, style: TextStyle(fontSize: 14, color: Colors.white.withAlpha((0.8 * 255).toInt())), textAlign: TextAlign.center),
              const SizedBox(height: 15),

              // --- Combined Display Area ---
              // Audio Description from Gemini
              if (_geminiAudioProcessedText.isNotEmpty && 
                  (_currentInputState == MediaInputState.confirmingAudioDescription || _currentInputState == MediaInputState.imagePreview))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Column(
                    children: [
                      Text("Harki's Audio Summary:", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(5)),
                        child: Text(_geminiAudioProcessedText, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),

              // Image Preview
              if (_capturedImageFile != null &&
                 (_currentInputState == MediaInputState.imagePreview || _currentInputState == MediaInputState.confirmingAudioDescription )) // Show preview if image exists and we are in relevant states
                Padding(
                  padding: const EdgeInsets.only(bottom:10.0),
                  child: Column(
                    children: [
                      Text("Image Preview:", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_capturedImageFile!, height: 100, fit: BoxFit.contain)
                      ),
                      if (_isImageApprovedByGemini)
                            Padding(
                            padding: const EdgeInsets.only(top:4.0),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 14), SizedBox(width: 4),
                              Text("Image approved", style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                            ]),
                            )
                        else if (_geminiImageAnalysisResultText.isNotEmpty && _geminiImageAnalysisResultText != "Image approved by Harki AI.")
                            Padding(
                              padding: const EdgeInsets.only(top:4.0),
                              child: Text(_geminiImageAnalysisResultText, style: TextStyle(color: Colors.orangeAccent, fontSize: 11), textAlign: TextAlign.center),
                            ),
                    ],
                  ),
                ),
              // --- End of Combined Display ---

              const SizedBox(height: 10),

              if (isProcessingAny)
                _buildProcessingIndicator(accentColor)
              else if (_currentInputState == MediaInputState.error)
                _buildErrorControls(accentColor)
              else
                Column( // Main controls column
                  children: [
                    Row( // Mic and Camera buttons
                      mainAxisAlignment: MainAxisAlignment.center, // Center them if only one is visible
                      children: [
                        // Mic is almost always available unless permissions issue
                        _buildMicInputControl(accentColor),
                        // Camera is conditionally available
                        if (_currentInputState == MediaInputState.confirmingAudioDescription || _currentInputState == MediaInputState.imagePreview)
                        ...[ const SizedBox(width: 20), _buildCameraInputControl(accentColor) ],
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildActionButtons(accentColor), // Send Audio, Analyze Image, Confirm & Submit
                  ],
                ),
              
              const SizedBox(height: 20),
              if (!isProcessingAny && _currentInputState != MediaInputState.recordingAudio)
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

Future<Map<String, String?>?> showIncidentVoiceDescriptionDialog({
  required BuildContext context,
  required MakerType markerType,
}) async {
  return await showDialog<Map<String, String?>?>(
    context: context,
    barrierDismissible: false, // User must explicitly cancel or confirm
    builder: (BuildContext dialogContext) {
      return IncidentVoiceDescriptionModal(markerType: markerType);
    },
  );
}

// Ensure StringExtension is accessible
extension StringExtension on String {
  String capitalizeAllWords() {
    if (isEmpty) return this;
    return split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }
}