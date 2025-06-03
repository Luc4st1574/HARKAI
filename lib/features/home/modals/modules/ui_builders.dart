import 'dart:io';
import 'package:flutter/material.dart';

import '../incident_description.dart';

class IncidentModalUiBuilders {
  // --- Input Controls ---

  static Widget buildMicInputControl({
    required BuildContext context, // For ScaffoldMessenger
    required bool canRecordAudio,
    required MediaInputState currentInputState,
    required Animation<double> micScaleAnimation,
    required Color accentColor,
    required VoidCallback onLongPressStart,
    required VoidCallback onLongPressEnd,
    required VoidCallback onTapHint, // For tap hint or permission re-check
  }) {
    return GestureDetector(
      onLongPressStart: canRecordAudio ? (_) => onLongPressStart() : null,
      onLongPressEnd:
          currentInputState == MediaInputState.recordingAudio ? (_) => onLongPressEnd() : null,
      onTap: () {
        if (canRecordAudio && currentInputState != MediaInputState.recordingAudio) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Hold to record, release to stop.")));
        } else {
          onTapHint(); // Handles permission re-check or other tap actions if not ready to record
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
            size: 36,
          ),
        ),
      ),
    );
  }

  static Widget buildCameraInputControl({
    // required bool canCaptureImage, // This logic is usually handled by the parent deciding to show this widget
    required File? capturedImageFile, // To change button label
    required Color accentColor,
    required VoidCallback onPressedCapture,
  }) {
    String cameraButtonLabel =
        capturedImageFile == null ? "Add Picture" : "Retake Picture";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.camera_alt, size: 36),
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
    );
  }

  // --- Action Buttons ---
  static Widget buildActionButtons({
    required BuildContext context, // Potentially for styling or theming access
    required MediaInputState currentInputState,
    required Color accentColor,
    required bool isImageApprovedByGemini,
    // Callbacks for different actions
    required VoidCallback? onSendAudioToGemini,
    required VoidCallback? onConfirmAudioAndProceed,
    required VoidCallback? onRetryFullProcessAudio, // For audio confirmation re-record
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
          label: const Text('Send Audio to Harki',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          label: const Text('Confirm Audio & Proceed',
              style: TextStyle(
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
            child: Text('Re-record Audio', style: TextStyle(color: accentColor))));
        break;
      case MediaInputState.displayingConfirmedAudio:
        buttons.add(ElevatedButton.icon(
          icon: const Icon(Icons.send_outlined, color: Colors.white, size: 20),
          label: const Text('Submit with Audio Only',
              style: TextStyle(
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
          label: const Text('Analyze Image with Harki',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
          onPressed: onSendImageToGemini,
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(TextButton(
            onPressed: onRemoveImageAndGoBackToDecision,
            child: Text('Use Audio Only (Remove Image)',
                style: TextStyle(color: Colors.grey.shade400))));
        break;
      case MediaInputState.imageAnalyzed:
        if (isImageApprovedByGemini) {
          buttons.add(ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 20),
            label: const Text('Submit with Audio & Image',
                style: TextStyle(
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
              child: Text('Submit Audio Only Instead',
                  style: TextStyle(color: Colors.grey.shade400))));
        } else {
          // If image not approved (includes mismatch, unclear, inappropriate)
          buttons.add(ElevatedButton.icon(
            icon: const Icon(Icons.send_outlined, color: Colors.white, size: 20),
            label: const Text('Submit with Audio Only',
                style: TextStyle(
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
        // No buttons for other states or handled differently
        break;
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  // --- Indicators and Messages ---

  static Widget buildProcessingIndicator({
    required Color accentColor,
    required String userInstructionText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
          const SizedBox(height: 15),
          Text(userInstructionText,
              style: TextStyle(
                  fontSize: 15, color: Colors.white.withAlpha((0.8 * 255).toInt())),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static Widget buildErrorControls({
    required Color accentColor,
    required String userInstructionText, // This is the main error message
    required VoidCallback onRetryFullProcess,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Text(userInstructionText,
              style: TextStyle(
                  fontSize: 15, color: Colors.white.withAlpha((0.9 * 255).toInt())),
              textAlign: TextAlign.center),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, color: Colors.white),
          label:
              const Text('Try Again from Start', style: TextStyle(color: Colors.white)),
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
    required bool shouldShow,
    required String confirmedAudioDescription,
    required Color accentColor,
  }) {
    if (!shouldShow || confirmedAudioDescription.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        children: [
          Text("Confirmed Audio:",
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
            child: Text(confirmedAudioDescription,
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
    required bool shouldShow,
    required File? capturedImageFile,
    required MediaInputState currentInputState,
    required bool isImageApprovedByGemini,
    required String geminiImageAnalysisResultText,
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
          Text("Image for Incident:",
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
                    message: "Remove Image",
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
                    ? "Harki: Image looks good!"
                    : (geminiImageAnalysisResultText.isNotEmpty
                        ? "Harki: $geminiImageAnalysisResultText"
                        : "Harki: Analysis complete."),
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