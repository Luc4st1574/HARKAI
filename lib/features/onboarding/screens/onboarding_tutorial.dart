import 'package:flutter/material.dart';
import 'package:harkai/l10n/app_localizations.dart';

class OnboardingTutorial extends StatefulWidget {
  const OnboardingTutorial({super.key});

  @override
  State<OnboardingTutorial> createState() => _OnboardingTutorialState();
}

class _OnboardingTutorialState extends State<OnboardingTutorial> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final tutorialPages = [
      _buildTutorialPage(
        imagePath: 'assets/images/bot.png',
        title: localizations.onboardingWelcomeTitle,
        description: localizations.onboardingWelcomeDescription,
      ),
      _buildTutorialPage(
        imagePath: 'assets/images/incident_buttons.jpg',
        title: localizations.onboardingIncidentsTitle,
        description: localizations.onboardingIncidentsDescription,
      ),
      _buildTutorialPage(
        imagePath: 'assets/images/tap_position_marker.png',
        title: localizations.onboardingMapTitle,
        description: localizations.onboardingMapDescription,
      ),
      // New page for location permission
      _buildTutorialPage(
        imagePath: 'assets/images/alert.png', // Using the alert icon for emphasis
        title: localizations.onboardingLocationTitle,
        description: localizations.onboardingLocationDescription,
      ),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              // Increased height slightly to ensure content fits comfortably
              height: MediaQuery.of(context).size.height * 0.45,
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: tutorialPages,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                tutorialPages.length,
                (index) => _buildDot(index: index, context: context),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF001F3F),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  if (_currentPage == tutorialPages.length - 1) {
                    Navigator.of(context).pop();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    );
                  }
                },
                child: Text(
                  _currentPage == tutorialPages.length - 1
                      ? localizations.onboardingGotIt
                      : localizations.onboardingNext,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot({required int index, required BuildContext context}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: _currentPage == index ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: _currentPage == index ? const Color(0xFF001F3F) : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }

  Widget _buildTutorialPage({
    required String imagePath,
    required String title,
    required String description,
  }) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(imagePath, height: 150, fit: BoxFit.contain),
          const SizedBox(height: 30),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 15),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.4, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}