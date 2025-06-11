import 'dart:io';
import 'package:flutter/material.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import
import '../incident_description.dart'; // Assuming MediaInputState is here

class IncidentModalUiBuilders {
  // --- Input Controls ---

  static Widget buildMicInputControl({
    required BuildContext context, // For ScaffoldMessenger
    required AppLocalizations localizations, // Added
    required bool canRecordAudio,
    required MediaInputState currentInputState,
    required Animation<double> micScaleAnimation,
    required Color accentColor,
    required VoidCallback onLongPressStart,
    required VoidCallback onLongPressEnd,
    required VoidCallback onTapHint,
  }) {
    return GestureDetector(
      onLongPressStart: canRecordAudio ? (_) => onLongPressStart() : null,
      onLongPressEnd:
          currentInputState == MediaInputState.recordingAudio ? (_) => onLongPressEnd() : null,
      onTap: () {
        if (canRecordAudio && currentInputState != MediaInputState.recordingAudio) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.incidentModalButtonHoldToRecordReleaseToStop))); // Localized
        } else {
          onTapHint();
        }
      },
      child: ScaleTransition(
        scale: micScaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: canRecordAudio ? accentColor : Colors.grey.shade700,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.3 * 255).toInt()),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Icon(
            currentInputState == MediaInputState.recordingAudio
                ? Icons.stop_circle_outlined
                : Icons.mic,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  static Widget buildCameraInputControl({
    required AppLocalizations localizations, // Added
    required File? capturedImageFile,
    required Color accentColor,
    required VoidCallback onPressedCapture,
    required VoidCallback onPressedGallery, // New callback
    required bool showGalleryButton, // New flag
  }) {
    String cameraButtonLabel = capturedImageFile == null
        ? localizations.incidentModalButtonAddPicture // Localized
        : localizations.incidentModalButtonRetakePicture; // Localized
    String galleryButtonLabel = localizations.incidentModalButtonAddFromGallery;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Camera Button
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt, size: 40),
                  color: accentColor,
                  padding: const EdgeInsets.all(16),
                  style: IconButton.styleFrom(
                    backgroundColor: accentColor.withAlpha((0.15 * 255).toInt()),
                    shape: const CircleBorder(),
                    side: BorderSide(color: accentColor.withAlpha((0.7 * 255).toInt()), width: 1.5),
                    elevation: 2,
                  ),
                  onPressed: onPressedCapture,
                  tooltip: cameraButtonLabel,
                ),
                const SizedBox(height: 4),
                Text(
                  cameraButtonLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Gallery Button (conditionally shown)
            if (showGalleryButton && capturedImageFile == null) ...[
              const SizedBox(width: 20),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_library, size: 40),
                    color: accentColor,
                    padding: const EdgeInsets.all(16),
                    style: IconButton.styleFrom(
                      backgroundColor: accentColor.withAlpha((0.15 * 255).toInt()),
                      shape: const CircleBorder(),
                      side: BorderSide(color: accentColor.withAlpha((0.7 * 255).toInt()), width: 1.5),
                      elevation: 2,
                    ),
                    onPressed: onPressedGallery,
                    tooltip: galleryButtonLabel,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    galleryButtonLabel,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ],
    );
  }

  // --- Action Buttons ---
  static Widget buildActionButtons({
    required BuildContext context,
    required AppLocalizations localizations, // Added
    required MediaInputState currentInputState,
    required Color accentColor,
    required bool isImageApprovedByGemini,
    required VoidCallback? onSendAudioToGemini,
    required VoidCallback? onConfirmAudioAndProceed,
    required VoidCallback? onRetryFullProcessAudio,
    required VoidCallback? onSubmitWithAudioOnlyAfterConfirmation,
    required VoidCallback? onSendImageToGemini,
    required VoidCallback? onRemoveImageAndGoBackToDecision,
    required VoidCallback? onSubmitWithAudioAndImage,
    required VoidCallback? onSubmitAudioOnlyFromImageAnalyzed,
    required VoidCallback? onClearImageDataAndSubmitAudioOnlyFromAnalyzed,
  }) {
    List<Widget> buttons = [];

    switch (currentInputState) {
      case MediaInputState.audioRecordedReadyToSend:
        buttons.add(ElevatedButton.icon(
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          label: Text(localizations.incidentModalButtonSendAudioToHarki, // Localized
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          onPressed: onSendAudioToGemini,
        ));
        break;
      case MediaInputState.audioDescriptionReadyForConfirmation:
        buttons.add(ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline,
              color: Colors.white, size: 20),
          label: Text(localizations.incidentModalButtonConfirmAudioAndProceed, // Localized
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed: onConfirmAudioAndProceed,
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(TextButton(
            onPressed: onRetryFullProcessAudio,
            child: Text(localizations.incidentModalButtonRerecordAudio, style: TextStyle(color: accentColor)))); // Localized
        break;
      case MediaInputState.displayingConfirmedAudio:
        buttons.add(ElevatedButton.icon(
          icon: const Icon(Icons.send_outlined, color: Colors.white, size: 20),
          label: Text(localizations.incidentModalButtonSubmitWithAudioOnly, // Localized
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed: onSubmitWithAudioOnlyAfterConfirmation,
        ));
        break;
      case MediaInputState.imagePreview:
        buttons.add(ElevatedButton.icon(
          icon: const Icon(Icons.science_outlined, color: Colors.white, size: 18),
          label: Text(localizations.incidentModalButtonAnalyzeImageWithHarki, // Localized
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          onPressed: onSendImageToGemini,
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(TextButton(
            onPressed: onRemoveImageAndGoBackToDecision,
            child: Text(localizations.incidentModalButtonUseAudioOnlyRemoveImage, // Localized
                style: TextStyle(color: Colors.grey.shade400))));
        break;
      case MediaInputState.imageAnalyzed:
        if (isImageApprovedByGemini) {
          buttons.add(ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
            label: Text(localizations.incidentModalButtonSubmitWithAudioAndImage, // Localized
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            onPressed: onSubmitWithAudioAndImage,
          ));
          buttons.add(const SizedBox(height: 10));
          buttons.add(TextButton(
              onPressed: onClearImageDataAndSubmitAudioOnlyFromAnalyzed,
              child: Text(localizations.incidentModalButtonSubmitAudioOnlyInstead, // Localized
                  style: TextStyle(color: Colors.grey.shade400))));
        } else {
          buttons.add(ElevatedButton.icon(
            icon: const Icon(Icons.send_outlined, color: Colors.white, size: 20),
            label: Text(localizations.incidentModalButtonSubmitWithAudioOnly, // Localized (reused)
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            onPressed: onSubmitAudioOnlyFromImageAnalyzed,
          ));
        }
        break;
      default:
        break;
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  // --- Indicators and Messages ---

  static Widget buildProcessingIndicator({
    required Color accentColor,
    required String userInstructionText, // This is passed localized from the caller
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
          const SizedBox(height: 15),
          Text(userInstructionText, // Displaying the localized text
              style: TextStyle(
                  fontSize: 15, color: Colors.white.withAlpha((0.8 * 255).toInt())),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static Widget buildErrorControls({
    required AppLocalizations localizations, // Added
    required Color accentColor,
    required String userInstructionText, // This is passed localized from the caller
    required VoidCallback onRetryFullProcess,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Text(userInstructionText, // Displaying the localized text
              style: TextStyle(
                  fontSize: 15, color: Colors.white.withAlpha((0.9 * 255).toInt())),
              textAlign: TextAlign.center),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, color: Colors.white),
          label:
              Text(localizations.incidentModalButtonTryAgainFromStart, style: const TextStyle(color: Colors.white)), // Localized
          style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
          onPressed: onRetryFullProcess,
        ),
      ],
    );
  }

  // --- Media Display Areas ---

  static Widget buildConfirmedAudioArea({
    required AppLocalizations localizations, // Added
    required bool shouldShow,
    required String confirmedAudioDescription, // This is data, not a label
    required Color accentColor,
  }) {
    if (!shouldShow || confirmedAudioDescription.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        children: [
          Text(localizations.incidentModalAudioConfirmedAudio, // Localized
              style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.2 * 255).toInt()),
                borderRadius: BorderRadius.circular(5)),
            child: Text(confirmedAudioDescription, // Displaying data
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 10),
          Divider(color: accentColor.withAlpha((0.3 * 255).toInt())),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  static Widget buildImagePreviewArea({
    required AppLocalizations localizations, // Added
    required bool shouldShow,
    required File? capturedImageFile,
    required MediaInputState currentInputState,
    required bool isImageApprovedByGemini,
    required String geminiImageAnalysisResultText, // This is data from Gemini
    required Color accentColor,
    required VoidCallback onRemoveImage,
  }) {
    if (!shouldShow || capturedImageFile == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        children: [
          Text(localizations.incidentModalImageForIncident, // Localized
              style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 5),
          Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(capturedImageFile,
                      height: 120, fit: BoxFit.contain)),
              if (currentInputState == MediaInputState.imagePreview ||
                  currentInputState == MediaInputState.imageAnalyzed)
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Tooltip(
                    message: localizations.incidentModalImageRemoveTooltip, // Localized
                    child: InkWell(
                      onTap: onRemoveImage,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha((0.5 * 255).toInt()),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.cancel, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                )
            ],
          ),
          if (currentInputState == MediaInputState.imageAnalyzed)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                isImageApprovedByGemini
                    ? localizations.incidentModalImageHarkiLooksGood // Localized
                    : (geminiImageAnalysisResultText.isNotEmpty // geminiImageAnalysisResultText is data from Gemini
                        ? localizations.incidentModalImageHarkiFeedback(geminiImageAnalysisResultText) // Localized parameterized string
                        : localizations.incidentModalImageHarkiAnalysisComplete), // Localized
                style: TextStyle(
                    color: isImageApprovedByGemini
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 10),
          Divider(color: accentColor.withAlpha((0.3 * 255).toInt())),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}