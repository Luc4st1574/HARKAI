import 'dart:async';
import 'dart:typed_data'; // For Uint8List
import 'dart:io'; // For File operations

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart'; 
import 'package:firebase_auth/firebase_auth.dart';

import 'modules/media_services.dart';
import 'modules/media_handler.dart';
import 'modules/ui_builders.dart';

import 'package:harkai/core/services/storage_service.dart';
import '../utils/markers.dart'; // For MakerType and getMarkerInfo

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
  awaitingImageCapture, // User chose to add image, camera action (less explicit state now, part of displayingConfirmedAudio)
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
  String? _recordedAudioPath;
  String _geminiAudioProcessedText = ''; // Holds the raw response from Gemini for audio
  String _confirmedAudioDescription = ''; // Holds the user-confirmed audio description

  // Image specific
  File? _capturedImageFile;
  String _geminiImageAnalysisResultText = ''; // Feedback from Gemini about the image
  bool _isImageApprovedByGemini = false;
  String? _uploadedImageUrl;

  // Shared State
  MediaInputState _currentInputState = MediaInputState.idle;
  GenerativeModel? _generativeModel;
  bool _hasMicPermission = false;
  String _statusText = 'Initializing...';
  String _userInstructionText = '';

  // Animation
  late AnimationController _micAnimationController;
  late Animation<double> _micScaleAnimation;

  // Service and Handler instances
  late IncidentMediaServices _mediaServices;
  late DeviceMediaHandler _deviceMediaHandler;
  final StorageService _storageService = StorageService(); // For uploading image
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    final apiKey = dotenv.env['HARKI_KEY'] ?? "";
    _mediaServices = IncidentMediaServices(apiKey: apiKey);
    _deviceMediaHandler = DeviceMediaHandler();

    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeModal();
    });
  }

  Future<void> _initializeModal() async {
    // Check permissions
    PermissionStatus micStatus =
        await _mediaServices.getMicrophonePermissionStatus();
    _hasMicPermission = micStatus.isGranted;

    if (!_hasMicPermission) {
      _hasMicPermission =
          await _mediaServices.requestMicrophonePermission(openSettingsOnError: true);
      if (!_hasMicPermission && mounted) {
        _handleError(
            "Microphone permission is required for audio recording. Please grant it in settings or restart the report process.");
            // UI will update via _updateStatusAndInstructionText below
      }
    }

    // Initialize Gemini
    if (_generativeModel == null) {
        _generativeModel = _mediaServices.initializeGeminiModel();
        if (_generativeModel == null && mounted) {
            _handleError("Failed to initialize Harki AI. Media processing unavailable.");
        } else if (mounted) {
            debugPrint("IncidentModal: Gemini initialized via MediaServices.");
        }
    }
    
    if (mounted) {
      _updateStatusAndInstructionText(); // Initial UI update
    }
  }

  void _handleError(String errorMessage,
      {bool isGeminiError = false,
      bool isMismatch = false,
      bool isUnclear = false}) {
    if (mounted) {
      _micAnimationController.reverse(); // Ensure mic animation stops
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

  // --- Audio Methods (Step 1) ---
  Future<void> _handleStartRecording() async {
    _clearAllMediaData(clearAudioProcessingResults: true, clearImageProcessingResults: true, updateState: false);
    
    if (!_hasMicPermission) {
      _handleError("Microphone permission not granted. Cannot record audio.");
      await _initializeModal(); // Attempt to re-check/re-ask for permissions
      return;
    }
    if (_generativeModel == null) {
        _handleError("Harki AI is not ready. Cannot process audio.");
        await _initializeModal(); // Attempt to re-initialize
        return;
    }

    _recordedAudioPath = await _deviceMediaHandler.getTemporaryFilePath("m4a");
    const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 48000);

    final successPath = await _deviceMediaHandler.startRecording(
        filePath: _recordedAudioPath!, config: config);

    if (successPath != null) {
      _recordedAudioPath = successPath;
      if (mounted) {
        _micAnimationController.forward();
        setState(() {
          _currentInputState = MediaInputState.recordingAudio;
          _updateStatusAndInstructionText();
        });
      }
    } else {
      _recordedAudioPath = null;
      _handleError("Could not start recording. Please ensure microphone is available.");
    }
  }

  Future<void> _handleStopRecording() async {
    final path = await _deviceMediaHandler.stopRecording();
    if (path != null) {
      _recordedAudioPath = path;
      if (mounted) {
        _micAnimationController.reverse();
        setState(() {
          _currentInputState = MediaInputState.audioRecordedReadyToSend;
          _updateStatusAndInstructionText();
        });
      }
    } else {
      _recordedAudioPath = null; // Clear path if stopping failed or recording was invalid
      if (mounted) _micAnimationController.reverse();
      _handleError( "Audio recording seems empty or was not saved correctly. Please try again.");
      // Stay in a state where user can retry, perhaps idle or error.
      // Forcing back to idle to allow another attempt.
      if (mounted) {
        setState(() {
          _currentInputState = MediaInputState.idle;
          _updateStatusAndInstructionText();
        });
      }
    }
  }

  Future<void> _handleSendAudioToGemini() async {
    if (_recordedAudioPath == null || _generativeModel == null) {
      _handleError("No audio recorded or Harki AI not ready.", isGeminiError: _generativeModel == null);
      return;
    }
    if (mounted) {
      setState(() {
        _currentInputState = MediaInputState.sendingAudioToGemini;
        _updateStatusAndInstructionText();
      });
    }

    try {
      final audioFile = File(_recordedAudioPath!);
      final Uint8List audioBytes = await audioFile.readAsBytes();
      final String incidentTypeName =
          widget.markerType.name.toString().split('.').last.capitalizeAllWords();

      final text = await _mediaServices.analyzeAudioWithGemini(
        model: _generativeModel!,
        audioBytes: audioBytes,
        audioMimeType: "audio/aac", // Mime type for .m4a is typically audio/mp4 or audio/aac
        incidentTypeName: incidentTypeName,
      );

      _geminiAudioProcessedText = text ?? "Harki AI couldn't process the audio.";

      if (mounted) {
        if (text != null && text.isNotEmpty) {
          if (text.startsWith("MATCH:")) {
            _geminiAudioProcessedText = text.substring("MATCH:".length).trim();
            setState(() {
              _currentInputState = MediaInputState.audioDescriptionReadyForConfirmation;
              _updateStatusAndInstructionText();
            });
          } else if (text.startsWith("MISMATCH:") || text.startsWith("UNCLEAR:")) {
            _handleError(_geminiAudioProcessedText,
                isMismatch: text.startsWith("MISMATCH:"),
                isUnclear: text.startsWith("UNCLEAR:"));
          } else {
            _handleError(
                "Harki AI audio response format was unexpected: $_geminiAudioProcessedText. Please review or retry.",
                isGeminiError: true);
          }
        } else {
          _handleError("Harki AI returned no actionable text for audio.",
              isGeminiError: true);
        }
      }
    } catch (e) {
      _handleError("Harki AI audio processing failed: ${e.toString()}",
          isGeminiError: true);
    }
  }

  void _handleConfirmAudioAndProceed() {
    if (_geminiAudioProcessedText.isNotEmpty) {
      _confirmedAudioDescription = _geminiAudioProcessedText;
      _geminiAudioProcessedText = ''; // Clear the raw Gemini text
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
  Future<void> _handleCaptureImage() async {
    _clearImageData(updateState: false); // Clear only image related data before capturing new one

    if (_generativeModel == null) {
        _handleError("Harki AI is not ready. Cannot process image.");
        await _initializeModal(); // Attempt to re-initialize
        return;
    }
    
    // Indicate to user that camera is being launched
    if (mounted) {
        // setState(() {
        //     _currentInputState = MediaInputState.awaitingImageCapture; // This state can be implied
        //     _updateStatusAndInstructionText();
        // });
    }

    final File? capturedFile = await _deviceMediaHandler.captureImageFromCamera(
        maxWidth: 1024, imageQuality: 70);

    if (mounted) {
      if (capturedFile != null) {
        setState(() {
          _capturedImageFile = capturedFile;
          _currentInputState = MediaInputState.imagePreview;
          _geminiImageAnalysisResultText = '';
          _isImageApprovedByGemini = false;
          _uploadedImageUrl = null;
          _updateStatusAndInstructionText();
        });
      } else {
        // User cancelled picker, go back to decision state
        setState(() {
          _currentInputState = MediaInputState.displayingConfirmedAudio;
          _updateStatusAndInstructionText();
        });
      }
    }
  }

  Future<void> _handleSendImageToGemini() async {
    if (_capturedImageFile == null || _generativeModel == null) {
      _handleError("No image captured or Harki AI not ready.", isGeminiError: _generativeModel == null);
      return;
    }
    if (mounted) {
      setState(() {
        _currentInputState = MediaInputState.sendingImageToGemini;
        _updateStatusAndInstructionText();
      });
    }

    try {
      final Uint8List imageBytes = await _capturedImageFile!.readAsBytes();
      final String mimeType = _capturedImageFile!.path.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final String incidentTypeName =
          widget.markerType.name.toString().split('.').last.capitalizeAllWords();

      final text = await _mediaServices.analyzeImageWithGemini(
        model: _generativeModel!,
        imageBytes: imageBytes,
        imageMimeType: mimeType,
        incidentTypeName: incidentTypeName,
      );

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
        setState(() {
          _currentInputState = MediaInputState.imageAnalyzed;
          _updateStatusAndInstructionText();
        });
      }
    } catch (e) {
      _isImageApprovedByGemini = false; // Ensure not approved on error
      _handleError("Harki AI image processing failed: ${e.toString()}", isGeminiError: true);
    }
  }

  void _handleRemoveImageAndGoBackToDecision() {
    _clearImageData(updateState: false); // Clear image data
    // No need to delete _capturedImageFile here, as it's a temp file from picker, OS handles it or it's overwritten.
    if (mounted) {
      setState(() {
        _currentInputState = MediaInputState.displayingConfirmedAudio;
        _updateStatusAndInstructionText();
      });
    }
  }

  // --- Data Clearing and Final Submission ---
  void _clearImageData({bool updateState = true}) {
    if (mounted) {
      _capturedImageFile = null; 
      _geminiImageAnalysisResultText = '';
      _isImageApprovedByGemini = false;
      _uploadedImageUrl = null;
      if (updateState) {
          setState(() {
            // Logic to determine next state after clearing image data
            if (_currentInputState.name.startsWith("image") || _currentInputState == MediaInputState.displayingConfirmedAudio) {
                 _currentInputState = MediaInputState.displayingConfirmedAudio; // Go back to image decision point
            } else {
                 _currentInputState = MediaInputState.idle; // Or appropriate fallback
            }
            _updateStatusAndInstructionText();
          });
      }
    }
  }

  void _clearAllMediaData({bool clearAudioProcessingResults = true, bool clearImageProcessingResults = true, bool updateState = true}) {
    if (mounted) {
      // Delete recorded audio if it exists
      if (_recordedAudioPath != null) {
        _deviceMediaHandler.deleteTemporaryFile(_recordedAudioPath);
        _recordedAudioPath = null;
      }
      // Clear image data (without deleting file, as explained in _clearImageData)
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
        setState(() {
            _currentInputState = MediaInputState.idle;
            _updateStatusAndInstructionText();
        });
      }
    }
  }

  Future<void> _handleFinalSubmitIncident() async {
    if (_currentUser?.uid == null) {
      _handleError("User not logged in. Cannot submit incident.");
       // Go back to a state where user can decide further actions or simply show error.
      if(mounted) setState(() { _currentInputState = _capturedImageFile != null && _isImageApprovedByGemini ? MediaInputState.imageAnalyzed : MediaInputState.displayingConfirmedAudio; _updateStatusAndInstructionText();});
      return;
    }

    // Image Upload if an approved image exists and hasn't been uploaded
    if (_capturedImageFile != null && _isImageApprovedByGemini && _uploadedImageUrl == null) {
      if (mounted) {
        setState(() { _currentInputState = MediaInputState.uploadingMedia; _updateStatusAndInstructionText(); });
      }
      _uploadedImageUrl = await _mediaServices.uploadIncidentImage(
          storageService: _storageService, // Pass the instance
          imageFile: _capturedImageFile!,
          userId: _currentUser!.uid,
          incidentType: widget.markerType.name); // Pass the original enum name string

      if (_uploadedImageUrl == null && mounted) {
        _handleError("Failed to upload image. Please try again or submit without image.");
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
      _handleError("No confirmed audio description available. Please complete audio step first.");
      if(mounted) setState(() { _currentInputState = MediaInputState.idle; _updateStatusAndInstructionText();});
    }
  }

  Future<void> _deleteRecordedAudioFile() async {
    if (_recordedAudioPath != null) {
      await _deviceMediaHandler.deleteTemporaryFile(_recordedAudioPath);
      _recordedAudioPath = null;
    }
  }

  Future<void> _handleRetryFullProcess() async {
    await _deleteRecordedAudioFile();
    _clearAllMediaData(updateState: false); // Clears everything including confirmed audio
    
    // Re-initialize permissions and Gemini if they were problematic
    if (!_hasMicPermission || _generativeModel == null) {
        await _initializeModal(); // This will also call _updateStatusAndInstructionText
    } else if (mounted) {
        setState(() {
          _currentInputState = MediaInputState.idle;
          _updateStatusAndInstructionText();
        });
    }
  }

  Future<void> _handleCancelInput() async {
    if (await _deviceMediaHandler.isAudioRecording()) {
      await _deviceMediaHandler.stopRecording(); // Stop recording if active
    }
    await _deleteRecordedAudioFile();
    _clearAllMediaData(updateState: false); // Clear all data without UI update yet
    if (mounted) {
      Navigator.pop(context, null); // Pop the dialog
    }
  }
  
  void _onTapMicHintOrPermissionRecheck() {
      if (!_hasMicPermission || _generativeModel == null) {
          _initializeModal(); // Attempt to re-check permissions or re-initialize Gemini
      }
      // If it has permission and model, the SnackBar hint is shown by the UI builder's onTap
  }


  void _updateStatusAndInstructionText() {
    final markerDetails = getMarkerInfo(widget.markerType);
    final incidentName =
        markerDetails?.title ?? widget.markerType.name.capitalizeAllWords();

    switch (_currentInputState) {
      case MediaInputState.idle:
        _statusText = 'Step 1: Report Audio for $incidentName';
        _userInstructionText = 'Hold Mic to record audio description.';
        if (!_hasMicPermission) _userInstructionText = 'Mic permission needed. Tap Mic to check/grant or grant in settings.';
        if (_generativeModel == null && _hasMicPermission) _userInstructionText = "Harki AI is initializing. Please wait or tap Mic to retry.";
        if(!_hasMicPermission && _generativeModel == null) _userInstructionText = "Mic permission needed & Harki AI initializing. Tap Mic to proceed.";
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
        _userInstructionText =
            'Harki suggests: "$_geminiAudioProcessedText".\nIs this correct?';
        break;
      case MediaInputState.displayingConfirmedAudio:
        _statusText = 'Step 2: Add Image (Optional)';
        _userInstructionText =
            'Confirmed Audio: "$_confirmedAudioDescription"\nAdd an image or submit with audio only.';
        break;
      case MediaInputState.awaitingImageCapture:
        _statusText = 'Step 2: Capturing Image...';
        _userInstructionText = 'Please use the camera to capture an image.';
        break;
      case MediaInputState.imagePreview:
        _statusText = 'Step 2: Image Preview';
        _userInstructionText =
            'Analyze this image with Harki, retake it, or remove it to proceed with audio only.';
        // Prepending confirmed audio is handled by the UI builder if needed
        break;
      case MediaInputState.sendingImageToGemini:
        _statusText = 'Harki Analyzing Image...';
        _userInstructionText = 'Please wait.';
        break;
      case MediaInputState.imageAnalyzed:
        _statusText = 'Step 2: Image Analyzed';
        if (_isImageApprovedByGemini) {
          _userInstructionText = "Image approved by Harki!\n";
        } else {
          _userInstructionText =
              "Image Feedback from Harki: $_geminiImageAnalysisResultText\n";
        }
        _userInstructionText +=
            "Submit with current details, retake image, or remove image.";
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
    _micAnimationController.dispose();
    _deviceMediaHandler.disposeAudioRecorder(); // Dispose recorder via handler
    _deleteRecordedAudioFile(); // Clean up any lingering temp audio file
    super.dispose();
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
    
    // Simplified check for Step 2 UI elements visibility
    bool showStep2ImageRelatedUI = _currentInputState == MediaInputState.displayingConfirmedAudio ||
                                  _currentInputState == MediaInputState.imagePreview ||
                                  _currentInputState == MediaInputState.sendingImageToGemini ||
                                  _currentInputState == MediaInputState.imageAnalyzed;


    return PopScope(
      canPop: !isProcessingAny && _currentInputState != MediaInputState.recordingAudio,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (isProcessingAny || _currentInputState == MediaInputState.recordingAudio) {
          // Prevent popping
        } else {
          _handleCancelInput();
        }
      },
      child: Dialog(
        backgroundColor: const Color(0xFF001F3F), // Navy blue background
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: accentColor, width: 2)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _statusText,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: (_currentInputState == MediaInputState.error &&
                            !(_statusText == "Type Mismatch" || _statusText == "Input Unclear/Invalid"))
                        ? Colors.redAccent
                        : accentColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(_userInstructionText,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withAlpha((0.8 * 255).toInt())),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 15),

              IncidentModalUiBuilders.buildConfirmedAudioArea(
                shouldShow: showStep2ImageRelatedUI || _currentInputState == MediaInputState.imagePreview,
                confirmedAudioDescription: _confirmedAudioDescription,
                accentColor: accentColor,
              ),

              IncidentModalUiBuilders.buildImagePreviewArea(
                shouldShow: _capturedImageFile != null && (showStep2ImageRelatedUI || _currentInputState == MediaInputState.imagePreview),
                capturedImageFile: _capturedImageFile,
                currentInputState: _currentInputState,
                isImageApprovedByGemini: _isImageApprovedByGemini,
                geminiImageAnalysisResultText: _geminiImageAnalysisResultText,
                accentColor: accentColor,
                onRemoveImage: _handleRemoveImageAndGoBackToDecision,
              ),
              
              const SizedBox(height: 10),

              if (isProcessingAny)
                IncidentModalUiBuilders.buildProcessingIndicator(
                    accentColor: accentColor,
                    userInstructionText: _userInstructionText)
              else if (_currentInputState == MediaInputState.error)
                IncidentModalUiBuilders.buildErrorControls(
                    accentColor: accentColor,
                    userInstructionText: _userInstructionText,
                    onRetryFullProcess: _handleRetryFullProcess)
              else
                Column(
                  children: [
                    if (isStep1Active) // Mic only visible in step 1 states
                      IncidentModalUiBuilders.buildMicInputControl(
                          context: context,
                          canRecordAudio: _hasMicPermission && _generativeModel != null && _currentInputState == MediaInputState.idle,
                          currentInputState: _currentInputState,
                          micScaleAnimation: _micScaleAnimation,
                          accentColor: accentColor,
                          onLongPressStart: _handleStartRecording,
                          onLongPressEnd: _handleStopRecording,
                          onTapHint: _onTapMicHintOrPermissionRecheck,
                        ),
                    
                    if (showStep2ImageRelatedUI && // Show camera button in relevant step 2 states
                        _currentInputState != MediaInputState.sendingImageToGemini &&
                        _currentInputState != MediaInputState.uploadingMedia)
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0), // Add some space if mic is not shown
                        child: IncidentModalUiBuilders.buildCameraInputControl(
                            capturedImageFile: _capturedImageFile,
                            accentColor: accentColor,
                            onPressedCapture: _handleCaptureImage,
                        ),
                      ),
                    const SizedBox(height: 20),
                    IncidentModalUiBuilders.buildActionButtons(
                      context: context,
                      currentInputState: _currentInputState,
                      accentColor: accentColor,
                      isImageApprovedByGemini: _isImageApprovedByGemini,
                      onSendAudioToGemini: _handleSendAudioToGemini,
                      onConfirmAudioAndProceed: _handleConfirmAudioAndProceed,
                      onRetryFullProcessAudio: _handleRetryFullProcess,
                      onSubmitWithAudioOnlyAfterConfirmation: _handleFinalSubmitIncident,
                      onSendImageToGemini: _handleSendImageToGemini,
                      onRemoveImageAndGoBackToDecision: _handleRemoveImageAndGoBackToDecision,
                      onSubmitWithAudioAndImage: _handleFinalSubmitIncident,
                      onSubmitAudioOnlyFromImageAnalyzed: () {
                          _clearImageData(updateState:false); // Clear image, keep audio
                          _handleFinalSubmitIncident();
                      },
                      onClearImageDataAndSubmitAudioOnlyFromAnalyzed: () {
                          _clearImageData(updateState:false); // Clear image, keep audio
                          _handleFinalSubmitIncident();
                      }
                    ),
                  ],
                ),

              const SizedBox(height: 20),
              if (!isProcessingAny && _currentInputState != MediaInputState.recordingAudio)
                TextButton(
                  onPressed: _handleCancelInput,
                  child: const Text('Cancel Report',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// The helper function to show the dialog
Future<Map<String, String?>?> showIncidentVoiceDescriptionDialog({
  required BuildContext context,
  required MakerType markerType,
}) async {
  return await showDialog<Map<String, String?>?>(
    context: context,
    barrierDismissible: false, // Controlled by PopScope and explicit cancel
    builder: (BuildContext dialogContext) {
      return IncidentVoiceDescriptionModal(markerType: markerType);
    },
  );
}

// String extension remains here
extension StringExtension on String {
  String capitalizeAllWords() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
}