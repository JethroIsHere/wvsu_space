import 'package:flutter/material.dart';
import 'main.dart'; // To access AppColors if needed later
// Import log_in_screen.dart for navigation
import 'log_in.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Add controllers for text fields later if needed
  // final _nicknameController = TextEditingController();
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
          // Allows scrolling if content overflows
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment
                .stretch, // Make children stretch horizontally
            children: [
              Text(
                'Get Started',
                style: textTheme.headlineLarge, // Getting Started Headline
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                // For "Already have an account? Log in"
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).extension<AppColors>()!.inactive, // Use Inactive color
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      // Navigate to Log In Screen
                      Navigator.pushReplacement(
                        // Replace current screen
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LogInScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Log in',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary, // Use Primary color
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- Nickname Field ---
              Text('Nickname', style: textTheme.bodyLarge), // Login Text Label
              const SizedBox(height: 8),
              TextFormField(
                // controller: _nicknameController,
                decoration: InputDecoration(
                  hintText: 'Write your nickname',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: colorScheme.secondary,
                  ), // Accent color
                  border: outlineInputBorder,
                  enabledBorder: outlineInputBorder,
                  focusedBorder: outlineInputBorder.copyWith(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ), // Primary on focus
                  ),
                  // Apply hintStyle from theme automatically
                ),
                style: textTheme.bodyMedium, // For input text
              ),
              const SizedBox(height: 24),

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

              // --- Sign Up Button ---
              ElevatedButton(
                style: elevatedButtonStyle,
                onPressed: () {
                  // TODO: Implement Sign Up logic
                },
                child: const Text('Sign Up'),
              ),
              const SizedBox(height: 16),

              // --- Disclaimer Text ---
              Text(
                '*Nickname cannot be edited after signing up',
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
