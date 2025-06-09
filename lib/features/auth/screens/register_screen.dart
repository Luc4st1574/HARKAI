// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../../home/screens/home.dart';

// Import the generated localizations file
import '../../../l10n/app_localizations.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  RegisterState createState() => RegisterState();
}

class RegisterState extends State<Register> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false; // To control loading state

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      print('Existing Firebase apps: ${Firebase.apps}');
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase is not initialized. Check main.dart setup.');
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return; // User cancelled
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.googleSignInSuccess)),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
      );
    } catch (e) {
      print('Error during Google Sign-In: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.googleSignInErrorPrefix}$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleEmailSignup(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await AuthService().signup(
        userName: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        context: context, localizations: localizations,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.emailSignupSuccess)),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
      );
    } catch (e) {
      // Error is displayed by AuthService toast
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackgroundImage(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 30),
                    Text(
                      localizations.registerTitle,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF57D463),
                      ),
                    ),
                    const SizedBox(height: 40),
                    CustomTextField(
                      controller: _usernameController,
                      hintText: localizations.usernameHint,
                      icon: Icons.person,
                      enabled: !_isLoading, // Disable when loading
                    ),
                    const SizedBox(height: 25),
                    CustomTextField(
                      controller: _emailController,
                      hintText: localizations.emailHint,
                      icon: Icons.email,
                      enabled: !_isLoading, // Disable when loading
                    ),
                    const SizedBox(height: 25),
                    CustomTextField(
                      controller: _passwordController,
                      hintText: localizations.passwordHint,
                      icon: Icons.lock,
                      obscureText: !_isPasswordVisible,
                      enabled: !_isLoading, // Disable when loading
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: const Color(0xFF57D463),
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 45),
                    _buildSignupButton(context, localizations),
                    const SizedBox(height: 25),
                    _buildGoogleSignupButton(context, localizations),
                    const SizedBox(height: 30),
                    _buildSignInLink(context, localizations),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF57D463)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackgroundImage() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo.png',
      width: 150,
      height: 150,
    );
  }

  Widget _buildSignupButton(BuildContext context, AppLocalizations localizations) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _handleEmailSignup(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF011935),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          localizations.signUpButton,
          style: const TextStyle(fontSize: 18, color: Color(0xFF57D463)),
        ),
      ),
    );
  }

  Widget _buildGoogleSignupButton(BuildContext context, AppLocalizations localizations) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _handleGoogleSignIn(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: Image.asset(
          'assets/images/google_logo.png',
          height: 24,
        ),
        label: Text(
          localizations.signUpWithGoogleButton,
          style: const TextStyle(fontSize: 18, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildSignInLink(BuildContext context, AppLocalizations localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(localizations.alreadyHaveAccountPrompt),
        GestureDetector(
          onTap: _isLoading ? null : () {
            Navigator.pop(context);
          },
          child: Text(
            localizations.logInLink,
            style: const TextStyle(color: Color(0xFF57D463)),
          ),
        ),
      ],
    );
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool enabled; // New property

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.enabled = true, // Default to true
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled, // Apply the enabled state
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF57D463)),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withAlpha((0.5 * 255).toInt())),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF57D463)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF57D463)),
        ),
        suffixIcon: suffixIcon,
      ),
      keyboardAppearance: Brightness.dark,
      cursorColor: const Color(0xFF57D463),
    );
  }
}