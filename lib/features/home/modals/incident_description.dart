import 'dart:async';
import 'dart:typed_data'; // For Uint8List
import 'dart:io'; // For File operations

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:harkai/l10n/app_localizations.dart';

import 'modules/media_services.dart';
import 'modules/media_handler.dart';
import 'modules/ui_builders.dart';

import 'package:harkai/core/services/storage_service.dart';
import '../utils/markers.dart';
import 'package:harkai/features/home/utils/extensions.dart';

// Enum to manage the state of the media input modal
enum MediaInputState {
  idle,
  recordingAudio,
  audioRecordedReadyToSend,
  sendingAudioToGemini,
  audioDescriptionReadyForConfirmation,
  textInput,
  displayingConfirmedAudio,
  awaitingImageCapture,
  imagePreview,
  sendingImageToGemini,
  imageAnalyzed,
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
  String? _recordedAudioPath;
  String _geminiAudioProcessedText = '';
  String _confirmedAudioDescription = '';
  File? _capturedImageFile;
  String _geminiImageAnalysisResultText = '';
  bool _isImageApprovedByGemini = false;
  String? _uploadedImageUrl;

  MediaInputState _currentInputState = MediaInputState.idle;
  final TextEditingController _textEditingController = TextEditingController();
  GenerativeModel? _generativeModel;
  bool _hasMicPermission = false;
  String _statusText = ''; // Will be set by _updateStatusAndInstructionText
  String _userInstructionText = ''; // Will be set

  late AnimationController _micAnimationController;
  late Animation<double> _micScaleAnimation;

  late IncidentMediaServices _mediaServices;
  late DeviceMediaHandler _deviceMediaHandler;
  final StorageService _storageService = StorageService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  AppLocalizations? _localizations; // To store AppLocalizations instance

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
    // _localizations will be initialized in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize localizations here as context is available
    if (_localizations == null) {
      _localizations = AppLocalizations.of(context)!;
      // Call _initializeModal only after localizations are set
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _initializeModal();
      });
    }
  }

  Future<void> _initializeModal() async {
    if (_localizations == null) {
      // This might happen if didChangeDependencies hasn't completed or context isn't ready.
      // Attempt to get it one more time.
      if (mounted) {
        _localizations = AppLocalizations.of(context);
      }
      if (_localizations == null) {
        debugPrint("Error: Localizations not available during _initializeModal.");
        // Potentially show a generic error or retry mechanism
        setState(() {
          _statusText = "Error initializing..."; // Non-localized fallback
          _userInstructionText = "Please try again.";
        });
        return;
      }
    }

    _statusText =_localizations!.incidentModalStatusInitializing; // Initial status

    PermissionStatus micStatus =
        await _mediaServices.getMicrophonePermissionStatus();
    _hasMicPermission = micStatus.isGranted;

    if (!_hasMicPermission) {
      _hasMicPermission =
          await _mediaServices.requestMicrophonePermission(openSettingsOnError: true);
      if (!_hasMicPermission && mounted) {
        _handleError(_localizations!.incidentModalErrorMicPermissionRequired);
      }
    }

    if (_generativeModel == null) {
      _generativeModel = _mediaServices.initializeGeminiModel();
      if (_generativeModel == null && mounted) {
        _handleError(_localizations!.incidentModalErrorFailedToInitHarki);
      } else if (mounted) {
        debugPrint("IncidentModal: Gemini initialized via MediaServices.");
      }
    }

    if (mounted) {
      _updateStatusAndInstructionText(); // Initial UI update based on permissions and Gemini status
    }
  }

  void _handleError(String errorMessage,
      {bool isGeminiError = false,
      bool isMismatch = false,
      bool isUnclear = false}) {
    if (mounted && _localizations != null) {
      _micAnimationController.reverse();
      setState(() {
        _currentInputState = MediaInputState.error;
        if (isMismatch) {
          _statusText = _localizations!.incidentModalStatusTypeMismatch;
        } else if (isUnclear) {
          _statusText = _localizations!.incidentModalStatusInputUnclearInvalid;
        } else if (isGeminiError) {
          _statusText = _localizations!.incidentModalStatusHarkiProcessingError;
        } else {
          _statusText = _localizations!.incidentModalStatusError;
        }
        _userInstructionText = errorMessage; // errorMessage should already be localized by the caller
      });
    }
  }

  Future<void> _handleStartRecording() async {
    if (_localizations == null) return;
    _clearAllMediaData(
        clearAudioProcessingResults: true,
        clearImageProcessingResults: true,
        updateState: false);

    if (!_hasMicPermission) {
      _handleError(_localizations!.incidentModalErrorMicNotGranted);
      await _initializeModal();
      return;
    }
    if (_generativeModel == null) {
      _handleError(_localizations!.incidentModalErrorHarkiNotReadyAudio);
      await _initializeModal();
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
      _handleError(_localizations!.incidentModalErrorCouldNotStartRecording);
    }
  }

  Future<void> _handleStopRecording() async {
    if (_localizations == null) return;
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
      _recordedAudioPath = null;
      if (mounted) _micAnimationController.reverse();
      _handleError(_localizations!.incidentModalErrorAudioEmptyNotSaved);
      if (mounted) {
        setState(() {
          _currentInputState = MediaInputState.idle;
          _updateStatusAndInstructionText();
        });
      }
    }
  }

  Future<void> _handleSendAudioToGemini() async {
    if (_localizations == null) return;
    if (_recordedAudioPath == null || _generativeModel == null) {
      _handleError(_localizations!.incidentModalErrorNoAudioOrHarkiNotReady,
          isGeminiError: _generativeModel == null);
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
      final String incidentTypeName = widget.markerType.name
          .toString()
          .split('.')
          .last
          .capitalizeAllWords();

      final text = await _mediaServices.analyzeAudioWithGemini(
        model: _generativeModel!,
        audioBytes: audioBytes,
        audioMimeType: "audio/aac",
        incidentTypeName: incidentTypeName,
      );

      _geminiAudioProcessedText = text ??
          _localizations!
              .incidentModalErrorHarkiAudioProcessingFailed(""); // Provide a generic part

      if (mounted) {
        if (text != null && text.isNotEmpty) {
          if (text.startsWith("MATCH:")) {
            _geminiAudioProcessedText = text.substring("MATCH:".length).trim();
            setState(() {
              _currentInputState =
                  MediaInputState.audioDescriptionReadyForConfirmation;
              _updateStatusAndInstructionText();
            });
          } else if (text.startsWith("MISMATCH:") ||
              text.startsWith("UNCLEAR:")) {
            _handleError(
                _geminiAudioProcessedText, // This text is from Gemini, potentially not localized by ARB
                isMismatch: text.startsWith("MISMATCH:"),
                isUnclear: text.startsWith("UNCLEAR:"));
          } else {
            _handleError(
                _localizations!.incidentModalErrorHarkiAudioResponseFormatUnexpected(
                    _geminiAudioProcessedText),
                isGeminiError: true);
          }
        } else {
          _handleError(
              _localizations!.incidentModalErrorHarkiNoActionableTextAudio,
              isGeminiError: true);
        }
      }
    } catch (e) {
      _handleError(
          _localizations!.incidentModalErrorHarkiAudioProcessingFailed(e.toString()),
          isGeminiError: true);
    }
  }

  void _handleConfirmAudioAndProceed() {
    if (_localizations == null) return;
    if (_geminiAudioProcessedText.isNotEmpty) {
      _confirmedAudioDescription = _geminiAudioProcessedText;
      _geminiAudioProcessedText = '';
      if (mounted) {
        setState(() {
          _currentInputState = MediaInputState.displayingConfirmedAudio;
          _updateStatusAndInstructionText();
        });
      }
    } else {
      _handleError(_localizations!.incidentModalErrorNoAudioToConfirm);
    }
  }

  Future<void> _handleCaptureImage() async {
    if (_localizations == null) return;
    _clearImageData(updateState: false);

    if (_generativeModel == null) {
      _handleError(_localizations!.incidentModalErrorHarkiNotReadyImage);
      await _initializeModal();
      return;
    }

    final File? capturedFile = await _deviceMediaHandler
        .captureImageFromCamera(maxWidth: 1024, imageQuality: 70);

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
        setState(() {
          _currentInputState = MediaInputState.displayingConfirmedAudio;
          _updateStatusAndInstructionText();
        });
      }
    }
  }

  Future<void> _handlePickImageFromGallery() async {
    if (_localizations == null) return;
    _clearImageData(updateState: false);

    if (_generativeModel == null) {
      _handleError(_localizations!.incidentModalErrorHarkiNotReadyImage);
      await _initializeModal();
      return;
    }

    final File? pickedFile = await _deviceMediaHandler
        .pickImageFromGallery(maxWidth: 1024, imageQuality: 70);

    if (mounted) {
      if (pickedFile != null) {
        setState(() {
          _capturedImageFile = pickedFile;
          _currentInputState = MediaInputState.imagePreview;
          _geminiImageAnalysisResultText = '';
          _isImageApprovedByGemini = false;
          _uploadedImageUrl = null;
          _updateStatusAndInstructionText();
        });
      } else {
        setState(() {
          _currentInputState = MediaInputState.displayingConfirmedAudio;
          _updateStatusAndInstructionText();
        });
      }
    }
  }

  Future<void> _handleSendImageToGemini() async {
    if (_localizations == null) return;
    if (_capturedImageFile == null || _generativeModel == null) {
      _handleError(_localizations!.incidentModalErrorNoImageOrHarkiNotReady,
          isGeminiError: _generativeModel == null);
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
      final String mimeType =
          _capturedImageFile!.path.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final String incidentTypeName = widget.markerType.name
          .toString()
          .split('.')
          .last
          .capitalizeAllWords();

      final text = await _mediaServices.analyzeImageWithGemini(
        model: _generativeModel!,
        imageBytes: imageBytes,
        imageMimeType: mimeType,
        incidentTypeName: incidentTypeName,
      );

      _geminiImageAnalysisResultText = text ??
          _localizations!.incidentModalErrorHarkiImageProcessingFailed("");
      debugPrint("Gemini Image Response: $_geminiImageAnalysisResultText");

      if (mounted) {
        if (text != null && text.isNotEmpty) {
          if (text.startsWith("MATCH:")) {
            _isImageApprovedByGemini = true;
            // _geminiImageAnalysisResultText already set
          } else {
            _isImageApprovedByGemini = false;
            // _geminiImageAnalysisResultText already set
          }
        } else {
          _isImageApprovedByGemini = false;
          _geminiImageAnalysisResultText =
              _localizations!.incidentModalErrorHarkiNoActionableTextImage;
        }
        setState(() {
          _currentInputState = MediaInputState.imageAnalyzed;
          _updateStatusAndInstructionText();
        });
      }
    } catch (e) {
      _isImageApprovedByGemini = false;
      _handleError(
          _localizations!.incidentModalErrorHarkiImageProcessingFailed(e.toString()),
          isGeminiError: true);
    }
  }

  Future<void> _handleSendTextToGemini() async {
    if (_localizations == null) return;
    final text = _textEditingController.text;
    if (text.isEmpty || _generativeModel == null) {
      _handleError(_localizations!.incidentModalErrorNoAudioOrHarkiNotReady,
          isGeminiError: _generativeModel == null);
      return;
    }

    if (mounted) {
      setState(() {
        _currentInputState = MediaInputState.sendingAudioToGemini;
        _updateStatusAndInstructionText();
      });
    }

    try {
      final incidentTypeName =
          widget.markerType.name.toString().split('.').last.capitalizeAllWords();

      final response = await _mediaServices.analyzeTextWithGemini(
        model: _generativeModel!,
        text: text,
        incidentTypeName: incidentTypeName,
      );

      _geminiAudioProcessedText = response ??
          _localizations!.incidentModalErrorHarkiAudioProcessingFailed("");

      if (mounted) {
        if (response != null && response.isNotEmpty) {
          if (response.startsWith("MATCH:")) {
            _geminiAudioProcessedText =
                response.substring("MATCH:".length).trim();
            setState(() {
              _currentInputState =
                  MediaInputState.audioDescriptionReadyForConfirmation;
              _updateStatusAndInstructionText();
            });
          } else if (response.startsWith("MISMATCH:") ||
              response.startsWith("UNCLEAR:")) {
            _handleError(_geminiAudioProcessedText,
                isMismatch: response.startsWith("MISMATCH:"),
                isUnclear: response.startsWith("UNCLEAR:"));
          } else {
            _handleError(
                _localizations!
                    .incidentModalErrorHarkiAudioResponseFormatUnexpected(
                        _geminiAudioProcessedText),
                isGeminiError: true);
          }
        } else {
          _handleError(
              _localizations!.incidentModalErrorHarkiNoActionableTextAudio,
              isGeminiError: true);
        }
      }
    } catch (e) {
      _handleError(
          _localizations!.incidentModalErrorHarkiAudioProcessingFailed(e.toString()),
          isGeminiError: true);
    }
  }

  void _handleRemoveImageAndGoBackToDecision() {
    _clearImageData(updateState: false);
    if (mounted) {
      setState(() {
        _currentInputState = MediaInputState.displayingConfirmedAudio;
        _updateStatusAndInstructionText();
      });
    }
  }

  void _clearImageData({bool updateState = true}) {
    if (mounted) {
      _capturedImageFile = null;
      _geminiImageAnalysisResultText = '';
      _isImageApprovedByGemini = false;
      _uploadedImageUrl = null;
      if (updateState) {
        setState(() {
          if (_currentInputState.name.startsWith("image") ||
              _currentInputState == MediaInputState.displayingConfirmedAudio) {
            _currentInputState = MediaInputState.displayingConfirmedAudio;
          } else {
            _currentInputState = MediaInputState.idle;
          }
          _updateStatusAndInstructionText();
        });
      }
    }
  }

  void _clearAllMediaData(
      {bool clearAudioProcessingResults = true,
      bool clearImageProcessingResults = true,
      bool updateState = true}) {
    if (mounted) {
      if (_recordedAudioPath != null) {
        _deviceMediaHandler.deleteTemporaryFile(_recordedAudioPath);
        _recordedAudioPath = null;
      }
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
    if (_localizations == null) return;
    if (_currentUser?.uid == null) {
      _handleError(_localizations!.incidentModalErrorUserNotLoggedIn);
      if (mounted) {
        setState(() {
          _currentInputState =
              _capturedImageFile != null && _isImageApprovedByGemini
                  ? MediaInputState.imageAnalyzed
                  : MediaInputState.displayingConfirmedAudio;
          _updateStatusAndInstructionText();
        });
      }
      return;
    }

    if (_capturedImageFile != null &&
        _isImageApprovedByGemini &&
        _uploadedImageUrl == null) {
      if (mounted) {
        setState(() {
          _currentInputState = MediaInputState.uploadingMedia;
          _updateStatusAndInstructionText();
        });
      }
      _uploadedImageUrl = await _mediaServices.uploadIncidentImage(
          storageService: _storageService,
          imageFile: _capturedImageFile!,
          userId: _currentUser!.uid,
          incidentType: widget.markerType.name);

      if (_uploadedImageUrl == null && mounted) {
        _handleError(_localizations!.incidentModalErrorFailedToUploadImage);
        setState(() {
          _currentInputState = MediaInputState.imageAnalyzed;
          _updateStatusAndInstructionText();
        });
        return;
      }
    }

    if (_confirmedAudioDescription.isNotEmpty) {
      if (mounted) {
        debugPrint(
            "Submitting: Audio='$_confirmedAudioDescription', ImageUrl='$_uploadedImageUrl'");
        Navigator.pop(context, {
          'description': _confirmedAudioDescription,
          'imageUrl': _uploadedImageUrl
        });
      }
    } else {
      _handleError(_localizations!.incidentModalErrorNoConfirmedAudioDescription);
      if (mounted) {
        setState(() {
          _currentInputState = MediaInputState.idle;
          _updateStatusAndInstructionText();
        });
      }
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
    _clearAllMediaData(updateState: false);

    if (!_hasMicPermission || _generativeModel == null) {
      await _initializeModal();
    } else if (mounted) {
      setState(() {
        _currentInputState = MediaInputState.idle;
        _updateStatusAndInstructionText();
      });
    }
  }

  Future<void> _handleCancelInput() async {
    if (await _deviceMediaHandler.isAudioRecording()) {
      await _deviceMediaHandler.stopRecording();
    }
    await _deleteRecordedAudioFile();
    _clearAllMediaData(updateState: false);
    if (mounted) {
      Navigator.pop(context, null);
    }
  }

  void _onTapMicHintOrPermissionRecheck() {
    if (!_hasMicPermission || _generativeModel == null) {
      _initializeModal();
    }
  }

  void _updateStatusAndInstructionText() {
    if (_localizations == null) {
      // Guard against null localizations
      _statusText = "Loading..."; // Non-localized fallback
      _userInstructionText = "Please wait.";
      if (mounted) setState(() {});
      return;
    }

    final markerDetails = getMarkerInfo(widget.markerType, _localizations!);
    final incidentName = markerDetails?.title ??widget.markerType.name.capitalizeAllWords(); // title is now localized from getMarkerInfo

    switch (_currentInputState) {
      case MediaInputState.idle:
        _statusText =
            _localizations!.incidentModalStep1ReportAudioTitle(incidentName);
        _userInstructionText = _localizations!.incidentModalInstructionHoldMic;
        if (!_hasMicPermission) {
          _userInstructionText =
              _localizations!.incidentModalInstructionMicPermissionNeeded;
        }
        if (_generativeModel == null && _hasMicPermission) {
          _userInstructionText =
              _localizations!.incidentModalInstructionHarkiInitializing;
        }
        if (!_hasMicPermission && _generativeModel == null) {
          _userInstructionText =
              _localizations!.incidentModalInstructionMicPermAndHarkiInit;
        }
        break;
      case MediaInputState.textInput:
        _statusText =
            _localizations!.incidentModalReportTextTitle(incidentName);
        _userInstructionText = _localizations!.incidentModalInstructionEnterText;
        break;
      case MediaInputState.recordingAudio:
        _statusText = _localizations!.incidentModalStatusRecordingAudio;
        _userInstructionText = _localizations!.incidentModalInstructionReleaseMic;
        break;
      case MediaInputState.audioRecordedReadyToSend:
        _statusText = _localizations!.incidentModalStatusAudioRecorded;
        _userInstructionText =
            _localizations!.incidentModalInstructionSendAudioToHarki;
        break;
      case MediaInputState.sendingAudioToGemini:
        _statusText = _localizations!.incidentModalStatusSendingAudioToHarki;
        _userInstructionText = _localizations!.incidentModalInstructionPleaseWait;
        break;
      case MediaInputState.audioDescriptionReadyForConfirmation:
        _statusText = _localizations!.incidentModalStatusConfirmAudioDescription;
        _userInstructionText = _localizations!
            .incidentModalInstructionConfirmAudio(_geminiAudioProcessedText);
        break;
      case MediaInputState.displayingConfirmedAudio:
        _statusText = _localizations!.incidentModalStatusStep2AddImage;
        _userInstructionText = _localizations!
            .incidentModalInstructionAddImageOrSubmit(
                _confirmedAudioDescription);
        break;
      case MediaInputState.awaitingImageCapture: // This state might be brief or implicit
        _statusText = _localizations!.incidentModalStatusCapturingImage;
        _userInstructionText = _localizations!.incidentModalInstructionUseCamera;
        break;
      case MediaInputState.imagePreview:
        _statusText = _localizations!.incidentModalStatusImagePreview;
        _userInstructionText =
            _localizations!.incidentModalInstructionAnalyzeRetakeRemoveImage;
        break;
      case MediaInputState.sendingImageToGemini:
        _statusText = _localizations!.incidentModalStatusSendingImageToHarki;
        _userInstructionText = _localizations!.incidentModalInstructionPleaseWait;
        break;
      case MediaInputState.imageAnalyzed:
        _statusText = _localizations!.incidentModalStatusImageAnalyzed;
        String imageAnalysisFeedback =
            _geminiImageAnalysisResultText.isNotEmpty
                ? _geminiImageAnalysisResultText
                : _localizations!.incidentModalImageHarkiAnalysisComplete;
        if (_isImageApprovedByGemini) {
          _userInstructionText =
              "${_localizations!.incidentModalImageHarkiLooksGood}\n${_localizations!.incidentModalInstructionImageApproved.split('\n').sublist(1).join('\n')}";
        } else {
          _userInstructionText =
              "${_localizations!.incidentModalImageHarkiFeedback(imageAnalysisFeedback)}\n${_localizations!.incidentModalInstructionImageFeedback("").split('\n').sublist(1).join('\n')}";
        }
        break;
      case MediaInputState.uploadingMedia:
        _statusText = _localizations!.incidentModalStatusSubmittingIncident;
        _userInstructionText =
            _localizations!.incidentModalInstructionUploadingMedia;
        break;
      case MediaInputState.error:
        // Status and instruction text are set by _handleError using localized strings
        break;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _micAnimationController.dispose();
    _deviceMediaHandler.disposeAudioRecorder();
    _deleteRecordedAudioFile();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure _localizations is initialized, if not, show loading or error
    if (_localizations == null) {
      _localizations =
          AppLocalizations.of(context); // Try to get it here if not already set
      if (_localizations == null) {
        return const Dialog(
            child: Center(
                child: CircularProgressIndicator(
          semanticsLabel: "Loading localization",
        )));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateStatusAndInstructionText();
      });
    }

    final MarkerInfo? markerDetails =
        getMarkerInfo(widget.markerType, _localizations!);
    final Color accentColor = markerDetails?.color ?? Colors.blueGrey;

    bool isProcessingAny =
        _currentInputState == MediaInputState.sendingAudioToGemini ||
            _currentInputState == MediaInputState.sendingImageToGemini ||
            _currentInputState == MediaInputState.uploadingMedia;

    bool isStep1Active = _currentInputState == MediaInputState.idle ||
        _currentInputState == MediaInputState.recordingAudio ||
        _currentInputState == MediaInputState.audioRecordedReadyToSend ||
        _currentInputState == MediaInputState.sendingAudioToGemini ||
        _currentInputState ==
            MediaInputState.audioDescriptionReadyForConfirmation;

    bool isTextInputActive = _currentInputState == MediaInputState.textInput;

    bool showStep2ImageRelatedUI =
        _currentInputState == MediaInputState.displayingConfirmedAudio ||
            _currentInputState == MediaInputState.imagePreview ||
            _currentInputState == MediaInputState.sendingImageToGemini ||
            _currentInputState == MediaInputState.imageAnalyzed;
            
    final bool showGalleryButton = widget.markerType == MakerType.place;


    return PopScope(
      canPop:
          !isProcessingAny && _currentInputState != MediaInputState.recordingAudio,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (!(isProcessingAny ||
            _currentInputState == MediaInputState.recordingAudio)) {
          _handleCancelInput();
        }
      },
      child: Dialog(
        backgroundColor: const Color(0xFF001F3F),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: accentColor, width: 2)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _statusText, // Already localized
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: (_currentInputState == MediaInputState.error &&
                            !(_statusText ==
                                    _localizations!
                                        .incidentModalStatusTypeMismatch ||
                                _statusText ==
                                    _localizations!
                                        .incidentModalStatusInputUnclearInvalid))
                        ? Colors.redAccent
                        : accentColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(_userInstructionText, // Already localized
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withAlpha((0.8 * 255).toInt())),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 15),
              IncidentModalUiBuilders.buildConfirmedAudioArea(
                shouldShow: showStep2ImageRelatedUI ||
                    _currentInputState == MediaInputState.imagePreview,
                confirmedAudioDescription: _confirmedAudioDescription,
                accentColor: accentColor,
                localizations: _localizations!,
              ),
              IncidentModalUiBuilders.buildImagePreviewArea(
                shouldShow: _capturedImageFile != null &&
                    (showStep2ImageRelatedUI ||
                        _currentInputState == MediaInputState.imagePreview),
                capturedImageFile: _capturedImageFile,
                currentInputState: _currentInputState,
                isImageApprovedByGemini: _isImageApprovedByGemini,
                geminiImageAnalysisResultText: _geminiImageAnalysisResultText,
                accentColor: accentColor,
                onRemoveImage: _handleRemoveImageAndGoBackToDecision,
                localizations: _localizations!,
              ),
              const SizedBox(height: 10),
              if (isProcessingAny)
                IncidentModalUiBuilders.buildProcessingIndicator(
                    accentColor: accentColor,
                    userInstructionText: _userInstructionText) // Already localized
              else if (_currentInputState == MediaInputState.error)
                IncidentModalUiBuilders.buildErrorControls(
                  accentColor: accentColor,
                  userInstructionText:
                      _userInstructionText, // Already localized
                  onRetryFullProcess: _handleRetryFullProcess,
                  localizations: _localizations!,
                )
              else
                Column(
                  children: [
                    if (isTextInputActive)
                      Column(
                        children: [
                          TextField(
                            controller: _textEditingController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText:
                                  _localizations!.incidentModalInstructionEnterText,
                              hintStyle:
                                  TextStyle(color: Colors.white.withAlpha(150)),
                              border: const OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            label: Text(_localizations!.incidentModalButtonSendTextToHarki,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                            onPressed: _handleSendTextToGemini,
                          )
                        ],
                      ),
                    if (isStep1Active)
                      IncidentModalUiBuilders.buildMicInputControl(
                        context: context,
                        canRecordAudio: _hasMicPermission &&
                            _generativeModel != null &&
                            _currentInputState == MediaInputState.idle,
                        currentInputState: _currentInputState,
                        micScaleAnimation: _micScaleAnimation,
                        accentColor: accentColor,
                        onLongPressStart: _handleStartRecording,
                        onLongPressEnd: _handleStopRecording,
                        onTapHint: _onTapMicHintOrPermissionRecheck,
                        localizations: _localizations!,
                      ),
                    if (showStep2ImageRelatedUI &&
                        _currentInputState !=
                            MediaInputState.sendingImageToGemini &&
                        _currentInputState != MediaInputState.uploadingMedia)
                      Padding(
                        padding: const EdgeInsets.only(top: 15.0),
                        child: IncidentModalUiBuilders.buildCameraInputControl(
                          capturedImageFile: _capturedImageFile,
                          accentColor: accentColor,
                          onPressedCapture: _handleCaptureImage,
                          localizations: _localizations!,
                          onPressedGallery: _handlePickImageFromGallery,
                          showGalleryButton: showGalleryButton,
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
                      onSubmitWithAudioOnlyAfterConfirmation:
                          _handleFinalSubmitIncident,
                      onSendImageToGemini: _handleSendImageToGemini,
                      onRemoveImageAndGoBackToDecision:
                          _handleRemoveImageAndGoBackToDecision,
                      onSubmitWithAudioAndImage: _handleFinalSubmitIncident,
                      onSubmitAudioOnlyFromImageAnalyzed: () {
                        _clearImageData(updateState: false);
                        _handleFinalSubmitIncident();
                      },
                      onClearImageDataAndSubmitAudioOnlyFromAnalyzed: () {
                        _clearImageData(updateState: false);
                        _handleFinalSubmitIncident();
                      },
                      localizations: _localizations!,
                    ),
                  ],
                ),
                // This is where the spacing is adjusted
                if (_currentInputState == MediaInputState.idle) ...[
                  const SizedBox(height: 0), // Reduced from 10
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentInputState = MediaInputState.textInput;
                        _updateStatusAndInstructionText();
                      });
                    },
                    child: Text(
                        _localizations!.incidentModalButtonEnterTextInstead,
                        style: TextStyle(color: accentColor)),
                  ),
                ],
                const SizedBox(height: 0), // Reduced from 10
                if (!isProcessingAny &&
                    _currentInputState != MediaInputState.recordingAudio)
                  TextButton(
                    onPressed: _handleCancelInput,
                    child: Text(_localizations!.incidentModalButtonCancelReport,
                        style: const TextStyle(color: Colors.grey, fontSize: 15)),
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
