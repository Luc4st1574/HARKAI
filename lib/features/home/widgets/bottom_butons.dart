// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../../chatbot/screens/chatbot.dart'; // For ChatBotScreen
import '../../home/utils/markers.dart';
import 'package:harkai/l10n/app_localizations.dart'; // Added import

/// A widget that displays the main action buttons at the bottom of the screen.
class BottomActionButtonsWidget extends StatelessWidget {
  final String currentServiceName;
  final VoidCallback onEmergencyPressed; // For regular tap
  final VoidCallback? onLongPressEmergency; // New: For long press on emergency button
  final VoidCallback onPhonePressed;

  /// Creates a [BottomActionButtonsWidget].
  const BottomActionButtonsWidget({
    super.key,
    required this.currentServiceName,
    required this.onEmergencyPressed,
    this.onLongPressEmergency, // Added to constructor
    required this.onPhonePressed,
  });

  // --- Size control variables ---
  static const double buttonDiameterAlert = 62.0; 
  static const double imageSizeAlert = 34.0;      

  static const double buttonDiameterBot = 62.0;   
  static const double imageSizeBot = 40.0;        
  // --- End of Size control variables ---

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; 

    final MarkerInfo? emergencyMarkerDetails = getMarkerInfo(MakerType.emergency, localizations);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Emergency Button (Left side)
          SizedBox(
            width: buttonDiameterAlert,
            height: buttonDiameterAlert,
            child: ElevatedButton(
              onPressed: onEmergencyPressed, // Existing tap action
              onLongPress: onLongPressEmergency, // MODIFIED: Added long press action
              style: ElevatedButton.styleFrom(
                backgroundColor: emergencyMarkerDetails?.color ?? Colors.red.shade900,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                elevation: 8,
                side: const BorderSide(color: Colors.white, width: 2),
              ),
              child: Center(
                child: SizedBox(
                  width: imageSizeAlert,
                  height: imageSizeAlert,
                  child: Image.asset(
                    emergencyMarkerDetails?.iconPath ?? 'assets/images/alert.png',
                    height: imageSizeAlert,
                    width: imageSizeAlert,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      print("Error loading emergency button icon: $error");
                      return Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: imageSizeAlert,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Phone Button (Center, Expanded)
          Expanded(
            child: ElevatedButton(
              onPressed: onPhonePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      currentServiceName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Chatbot Button (Right side)
          Stack(
            alignment: Alignment.topLeft,
            clipBehavior: Clip.none, 
            children: [
              SizedBox(
                width: buttonDiameterBot,
                height: buttonDiameterBot,
                child: ElevatedButton(
                  onPressed: () {
                    print("Chatbot button tapped. Navigating to ChatBotScreen.");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ChatBotScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    elevation: 12, 
                    shadowColor: Colors.black.withAlpha((0.45 * 255).toInt()), 
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: imageSizeBot,
                      height: imageSizeBot,
                      child: Image.asset(
                        'assets/images/bot.png',
                        height: imageSizeBot,
                        width: imageSizeBot,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          print("Error loading bot button icon: $error");
                          return Icon(
                            Icons.support_agent,
                            color: Colors.grey.shade700,
                            size: imageSizeBot,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                left: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    size: 18,
                    color: Color(0xFF57D463),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}