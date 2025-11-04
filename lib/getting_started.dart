import 'package:flutter/material.dart';
import 'main.dart'; // Importing to get our AppColors extension
// --- Added Imports ---
import 'router/app_router.dart';
// --------------------

class GettingStartedScreen extends StatefulWidget {
  const GettingStartedScreen({super.key});

  @override
  State<GettingStartedScreen> createState() => _GettingStartedScreenState();
}

class _GettingStartedScreenState extends State<GettingStartedScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!.round();
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Helper variable to access your custom colors
    final appColors = AppColors.of(context);

    // Button styles from your theme
    final elevatedButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary, // Primary color fill
      foregroundColor: Theme.of(
        context,
      ).colorScheme.onPrimary, // Text color on primary
      textStyle: Theme.of(context).textTheme.labelLarge,
      minimumSize: const Size(double.infinity, 50), // Full width
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final outlinedButtonStyle = OutlinedButton.styleFrom(
      textStyle: Theme.of(context).textTheme.labelLarge,
      minimumSize: const Size(double.infinity, 50), // Full width
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: Theme.of(context).colorScheme.primary),
    );

    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface, // Corrected from .surface
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  children: const [
                    // --- Page 1 ---
                    OnboardingPageContent(
                      imagePath:
                          'assets/images/wvsu_space_logo.png', // Corrected image path
                      title: 'Share at your own pace',
                      description:
                          'Connect with your university community in complete privacy',
                    ),
                    // --- Page 2 ---
                    OnboardingPageContent(
                      imagePath:
                          'assets/images/wvsu_space_logo.png', // Corrected image path
                      title: 'Chat randomly and freely',
                      description:
                          'Your identity stays private while you build real connections',
                    ),
                    // --- Page 3 ---
                    OnboardingPageContent(
                      imagePath:
                          'assets/images/wvsu_space_logo.png', // Corrected image path
                      title: 'Find your place in this space',
                      description:
                          'Your identity stays private while you build real connections',
                    ),
                    // --- Page 4 (Auth) ---
                    OnboardingPageContent(
                      imagePath:
                          'assets/images/wvsu_space_logo.png', // Corrected image path
                      title: 'Choose',
                      description:
                          'Restricted to WVSU email only. Don\'t worry no one will know your identity',
                    ),
                  ],
                ),
              ),

              // --- Page Indicators (Dots) ---
              // Only show dots for the first 3 pages
              if (_currentPage < 3)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return _buildPageIndicator(
                      isActive: index == _currentPage,
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: appColors.inactive!,
                    );
                  }),
                ),

              const SizedBox(height: 32),

              // --- Buttons (Conditional) ---
              if (_currentPage < 3) ...[
                // --- Pages 1-3 Buttons ---
                ElevatedButton(
                  style: elevatedButtonStyle,
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    );
                  },
                  child: const Text('Continue'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: outlinedButtonStyle,
                  onPressed: () {
                    // Skip to the last page (index 3)
                    _pageController.animateToPage(
                      3,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    );
                  },
                  child: const Text('Skip'),
                ),
              ] else ...[
                // --- Page 4 Buttons ---
                ElevatedButton(
                  style: elevatedButtonStyle,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRouter.login);
                  },
                  child: const Text('Log In'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: outlinedButtonStyle,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRouter.signUp);
                  },
                  child: const Text('Sign Up'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Open dedicated Admin login screen
                    Navigator.pushNamed(context, AppRouter.adminLogin);
                  },
                  child: Text(
                    'Admin Access',
                    // Using your "Log In Text Hint" style
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: 16), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to build the animated dots
  Widget _buildPageIndicator({
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// A reusable widget for the content of an onboarding page
class OnboardingPageContent extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;

  const OnboardingPageContent({
    super.key,
    required this.imagePath,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          imagePath,
          height: 150, // You can adjust the size
        ),
        const SizedBox(height: 48),
        Text(
          title,
          // Using your "Getting Started Headline" style
          style: Theme.of(context).textTheme.headlineLarge!,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          description,
          // Using your "Getting started description" style
          style: Theme.of(context).textTheme.bodyMedium!,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
