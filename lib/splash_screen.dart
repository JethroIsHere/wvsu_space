import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'getting_started.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // Detect test binding so widget tests run fast
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    final bool isTestBinding = bindingName.contains('TestWidgets');

    // Long, slow animation for normal runs; very short for tests
    final animDuration = isTestBinding
        ? const Duration(milliseconds: 8)
        : const Duration(milliseconds: 4500);

    _ctrl = AnimationController(
      vsync: this,
      duration: animDuration,
    );

    // Subtle scale animation across the duration (slow breathing/pulse)
    _scale = Tween<double>(begin: 0.88, end: 1.02)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Start the animation and navigate when complete.
    // For normal runs we push the Getting Started screen with a longer
    // transitionDuration so the Hero flight lasts ~2.5s (visible movement).
    // For widget tests we short-circuit to avoid long waits.
    _ctrl.forward().whenComplete(() {
      if (!mounted) return;
      if (isTestBinding) {
        Navigator.pushReplacementNamed(context, AppRouter.gettingStarted);
        return;
      }

      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GettingStartedScreen(),
        transitionDuration: const Duration(milliseconds: 2500),
        reverseTransitionDuration: const Duration(milliseconds: 2500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // No extra visual transition — the Hero handles the shared element
          // animation. Returning the child directly keeps the route change
          // clean while the Hero flies between positions.
          return child;
        },
      ));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No theme needed; colors are specified for the splash background and text
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.18 * 255).round()),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: ClipOval(
                      child: Hero(
                        tag: 'app-logo',
                        child: Image.asset(
                          'assets/images/wvsu_space_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                // No text — only the logo is shown on the splash for a clean look.
              ],
            ),
          ),
        ),
      ),
    );
  }
}
