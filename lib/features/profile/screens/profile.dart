import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:harkai/features/auth/services/auth_service.dart';

// Import the generated localizations file
import '../../../l10n/app_localizations.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  ProfileState createState() => ProfileState();
}

class ProfileState extends State<Profile> {
  bool _obscurePassword = true;
  final user = FirebaseAuth.instance.currentUser;

  // Helper function to truncate the email from the middle
  String _truncateEmail(String email, {int maxLength = 18}) {
    if (email.length <= maxLength) {
      return email;
    }

    final atIndex = email.indexOf('@');
    if (atIndex == -1) {
      // Not a valid email, truncate normally
      return '${email.substring(0, maxLength - 3)}...';
    }

    final name = email.substring(0, atIndex);
    final domain = email.substring(atIndex);

    if (name.length > 8) {
      final truncatedName = '${name.substring(0, 4)}...${name.substring(name.length - 1)}';
      return '$truncatedName$domain';
    }

    return email;
  }

  @override
  Widget build(BuildContext context) {
    // Get localizations instance
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001F3F),
        title: Text(localizations.profileTitle, style: const TextStyle(color: Color(0xFF57D463))), // Localized
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF57D463)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              user?.photoURL != null
                  ? CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(user!.photoURL!),
                    )
                  : const CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFF57D463),
                      child: Icon(Icons.person, size: 50, color: Color(0xFF001F3F)),
                    ),
              const SizedBox(height: 16),
              Text(
                user?.displayName ?? localizations.profileDefaultUsername, // Localized fallback
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF57D463)),
              ),
              const SizedBox(height: 32),
              _buildInfoTile(localizations.profileEmailLabel, user?.email ?? localizations.profileValueNotAvailable, localizations), // Localized
              const SizedBox(height: 16),
              _buildPasswordTile(localizations), // Localized
              const SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUnifiedButton(
                    icon: Icons.lock,
                    label: localizations.profileChangePasswordButton, // Localized
                    onPressed: () {
                      _showPasswordResetDialog(localizations); // Pass localizations
                    },
                    localizations: localizations, // Pass localizations if needed by button itself
                  ),
                  const SizedBox(height: 16),
                  _buildUnifiedButton(
                    icon: Icons.credit_card,
                    label: localizations.profileBlockCardsButton, // Localized
                    onPressed: _handleBlockCard,
                    localizations: localizations,
                  ),
                  const SizedBox(height: 16),
                  _buildUnifiedButton(
                    icon: Icons.logout,
                    label: localizations.profileLogoutButton, // Localized
                    onPressed: () async {
                      final authService = AuthService();
                      await authService.signout(context, localizations);
                    },
                    localizations: localizations,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF011935),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF57D463))), // Title is already localized when passed
          Flexible(
            child: Text(
              _truncateEmail(value),
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTile(AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF011935),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(localizations.profilePasswordLabel, style: const TextStyle(color: Color(0xFF57D463))), // Localized
          Row(
            children: [
              Text(
                _obscurePassword ? '•••••••••••••••' : localizations.profilePasswordHiddenText, // Localized
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF57D463),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedButton({
    required IconData icon,
    required String label, // Expects localized label
    required VoidCallback onPressed,
    required AppLocalizations localizations, // Added to potentially use inside if needed, though label is primary
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFF001F3F)),
      label: Text(label, style: const TextStyle(color: Color(0xFF001F3F))), // Label is already localized when passed
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF57D463),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _handleBlockCard() async {
    final localizations = AppLocalizations.of(context)!; // Get localizations here
    const emergencyNumber = '1820'; // This might need to be configurable or localized if it varies by region
    final phoneNumber = Uri.encodeFull(emergencyNumber);
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);

    var status = await Permission.phone.status;
    if (status.isGranted) {
      try {
        await url_launcher.launchUrl(
          launchUri,
          mode: url_launcher.LaunchMode.externalApplication,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${localizations.profileDialerErrorPrefix}${e.toString()}')), // Localized prefix
          );
        }
      }
    } else {
      var result = await Permission.phone.request();
      if (result.isGranted) {
        try {
          await url_launcher.launchUrl(
            launchUri,
            mode: url_launcher.LaunchMode.externalApplication,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${localizations.profileDialerErrorPrefix}${e.toString()}')), // Localized prefix
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.profilePhonePermissionDenied)), // Localized
          );
        }
      }
    }
  }

  void _showPasswordResetDialog(AppLocalizations localizations) { // Pass localizations
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Use a different context name for the dialog
        return AlertDialog(
          title: Text(localizations.profileResetPasswordDialogTitle), // Localized
          content: Text(localizations.profileResetPasswordDialogContent), // Localized
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
              child: Text(localizations.profileDialogNo), // Localized
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close the dialog first
                if (user?.email != null) {
                  try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
                     if (dialogContext.mounted) { // Check dialogContext before showing SnackBar
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(localizations.profilePasswordResetEmailSent)), // Localized
                        );
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          // Consider a more generic error message or a specific key for this error
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                    }
                  }
                } else {
                  if (dialogContext.mounted) { // Check dialogContext
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(localizations.profileNoEmailForPasswordReset)), // Localized
                    );
                  }
                }
              },
              child: Text(localizations.profileDialogYes), // Localized
            ),
          ],
        );
      },
    );
  }
}