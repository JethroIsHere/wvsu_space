import 'package:flutter/material.dart';
import 'main.dart'; // To access AppColors if needed later
// Import sign_up.dart for navigation
import 'sign_up.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  // Add controllers for text fields later if needed
  // final _emailController = TextEditingController();
  // final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final inputDecorationTheme = Theme.of(context).inputDecorationTheme;

    // Define border style once
    final outlineInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: colorScheme.secondary,
        width: 1.5,
      ), // Accent color border
    );

    final elevatedButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      textStyle: textTheme.labelLarge, // Button Text Size
      minimumSize: const Size(double.infinity, 50),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Or use background color
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Back',
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome Back!',
                // Using h1 style for this title as it seems larger
                style: textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                // For "Don't have an account yet? Sign Up"
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Don\'t have an account yet? ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).extension<AppColors>()!.inactive, // Use Inactive color
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      // Navigate to Sign Up Screen
                      Navigator.pushReplacement(
                        // Replace current screen
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary, // Use Primary color
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- Email Field ---
              Text('Email', style: textTheme.bodyLarge), // Login Text Label
              const SizedBox(height: 8),
              TextFormField(
                // controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Write your email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: colorScheme.secondary,
                  ), // Accent color
                  border: outlineInputBorder,
                  enabledBorder: outlineInputBorder,
                  focusedBorder: outlineInputBorder.copyWith(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // --- Password Field ---
              Text('Password', style: textTheme.bodyLarge), // Login Text Label
              const SizedBox(height: 8),
              TextFormField(
                // controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Write your password',
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: colorScheme.secondary,
                  ), // Accent color
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colorScheme.secondary, // Accent color
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: outlineInputBorder,
                  enabledBorder: outlineInputBorder,
                  focusedBorder: outlineInputBorder.copyWith(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // --- Log In Button ---
              ElevatedButton(
                style: elevatedButtonStyle,
                onPressed: () {
                  // TODO: Implement Log In logic
                },
                child: const Text('Log In'),
              ),
              const SizedBox(height: 16),

              // --- Disclaimer Text ---
              Text(
                '*Nickname cannot be edited after signing up', // Note: Same text as sign up?
                style: textTheme.bodySmall?.copyWith(
                  // Log In Text Hint style
                  color: Theme.of(
                    context,
                  ).extension<AppColors>()!.inactive, // Use Inactive color
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
