import 'package:flutter/material.dart';
import 'router/app_router.dart';

class ChooseScreen extends StatelessWidget {
  const ChooseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final elevatedButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF0D47A1), // app blue
      foregroundColor: Colors.white,
      textStyle: Theme.of(context).textTheme.labelLarge,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final outlinedButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: Color(0xFF0D47A1)),
      foregroundColor: const Color(0xFF0D47A1),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular logo with subtle border and shadow to match screenshot
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 6),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/wvsu_space_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 28),
              Text(
                'Choose',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Restricted to WVSU email only. Don\'t worry no one will know your identity',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              ElevatedButton(
                style: elevatedButtonStyle,
                onPressed: () => Navigator.pushNamed(context, AppRouter.login),
                child: const Text('Log In'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: outlinedButtonStyle,
                onPressed: () => Navigator.pushNamed(context, AppRouter.signUp),
                child: const Text('Sign Up'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRouter.adminLogin),
                child: Text(
                  'Admin Access',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
