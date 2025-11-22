import 'package:flutter/material.dart';
import 'package:wvsu_space/main.dart';
// --- Added Imports ---
import 'package:wvsu_space/router/app_router.dart';
import 'package:wvsu_space/widgets/app_button.dart';
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

    // Route animation drives the fade-in of text/buttons while the Hero
    // flies the logo to its position. If the route animation is not
    // available (tests or direct navigation), fall back to fully visible.
    final routeAnim = ModalRoute.of(context)?.animation ??
        AlwaysStoppedAnimation<double>(1.0) as Animation<double>;
    final contentFade = CurvedAnimation(
      parent: routeAnim,
      curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
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
              FadeTransition(
                opacity: contentFade,
                child: Column(
                  children: [
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
                      AppButton(
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
                      // Use a feedback-disabled InkWell to avoid platform feedback
                      // causing crashes in some environments.
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        child: InkWell(
                          enableFeedback: false,
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            // Skip to the last page (index 3)
                            _pageController.animateToPage(
                              3,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Skip',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // --- Page 4 Buttons ---
                      AppButton(
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
                      // Hidden long-press target for Admin access. This keeps the admin
                      // flow bundled but invisible to ordinary users. Long-press this
                      // area to open the admin login.
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onLongPress: () =>
                            Navigator.pushNamed(context, AppRouter.adminLogin),
                        child:
                            const SizedBox(height: 24, width: double.infinity),
                      ),
                    ],
                    const SizedBox(height: 16), // Bottom padding
                  ],
                ),
              ),
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
    // Use the route animation to fade the textual content in as the logo
    // completes its Hero flight. The image itself is not faded so the
    // shared element transition remains visually prominent.
    final routeAnim = ModalRoute.of(context)?.animation ??
        AlwaysStoppedAnimation<double>(1.0) as Animation<double>;
    final textFade = CurvedAnimation(
      parent: routeAnim,
      curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Hero(
          tag: 'app-logo',
          child: Image.asset(
            imagePath,
            height: 150, // You can adjust the size
          ),
        ),
        const SizedBox(height: 48),
        FadeTransition(
          opacity: textFade,
          child: Column(
            children: [
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
          ),
        ),
      ],
    );
  }
}
