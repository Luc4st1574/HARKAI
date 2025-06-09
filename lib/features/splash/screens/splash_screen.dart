import 'package:flutter/material.dart';
import '../../auth/services/auth_wrapper.dart';  // Import the new AuthWrapper
import '../../../l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _navigateToAuthWrapper();
  }

  Future<void> _navigateToAuthWrapper() async {
    // Wait for the splash animation to finish
    await Future.delayed(const Duration(seconds: 3));

    // Ensure the widget is still mounted before navigating
    if (!mounted) return;

    // Navigate to the AuthWrapper, which will handle the logic
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? localizations = AppLocalizations.of(context);
    final String welcomeText = localizations?.splashWelcome ?? "WELCOME";

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: FadeTransition(
        opacity: _animation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 20),
              Text(
                welcomeText,
                style: const TextStyle(
                  color: Color(0xFF57D463),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}