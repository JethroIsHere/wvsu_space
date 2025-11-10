import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'main.dart'; // To access AppColors if needed later
import 'router/app_router.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // --- Add Controllers ---
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // ----------------------

  bool _obscurePassword = true;
  bool _isLoading = false; // --- Add loading state ---
  String? _errorMessage; // --- Add error message state ---

  @override
  void dispose() {
    // --- Dispose controllers ---
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    // -------------------------
    super.dispose();
  }

  // --- Sign Up Function ---
  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      // 1. Create user in Firebase Auth
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Save additional user info (nickname) to Firestore
      if (credential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid) // Use user's unique ID as document ID
            .set({
          'nickname': _nicknameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': Timestamp.now(), // Optional: add creation timestamp
          'standing': 100, // Initialize community standing score
        });

        // 3. Navigate to Home Screen on success
        if (mounted) {
          // Check if the widget is still in the tree
          Navigator.pushReplacementNamed(context, AppRouter.home);
        }
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase errors
      if (e.code == 'weak-password') {
        _errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        _errorMessage = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'The email address is not valid.';
      } else {
        _errorMessage = 'An error occurred. Please try again.';
      }
      debugPrint('Firebase Auth Error: ${e.message}'); // Log for debugging
    } catch (e) {
      // Handle other potential errors
      _errorMessage = 'An unexpected error occurred.';
      debugPrint('Sign Up Error: $e'); // Log for debugging
    } finally {
      // Ensure loading state is turned off even if errors occur
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // ------------------------

  @override
  Widget build(BuildContext context) {
    // ... (keep existing theme/style definitions) ...
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final outlineInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
    );

    final elevatedButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      textStyle: textTheme.labelLarge,
      minimumSize: const Size(double.infinity, 50),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title and CTA
              Text(
                'Get Started',
                style: textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).extension<AppColors>()!.inactive,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, AppRouter.login);
                    },
                    child: Text(
                      'Log in',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- Nickname Field ---
              Text('Nickname', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nicknameController, // <-- Use controller
                decoration: InputDecoration(
                  /* ... keep existing decoration ... */
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: colorScheme.secondary,
                  ),
                  border: outlineInputBorder,
                  enabledBorder: outlineInputBorder,
                  focusedBorder: outlineInputBorder.copyWith(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  hintText: 'Write your nickname',
                ),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // --- Email Field ---
              Text('Email', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController, // <-- Use controller
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  /* ... keep existing decoration ... */
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: colorScheme.secondary,
                  ),
                  border: outlineInputBorder,
                  enabledBorder: outlineInputBorder,
                  focusedBorder: outlineInputBorder.copyWith(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  hintText: 'Write your email',
                ),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // --- Password Field ---
              Text('Password', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController, // <-- Use controller
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  /* ... keep existing decoration ... */
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: colorScheme.secondary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colorScheme.secondary,
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
                  hintText: 'Write your password',
                ),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16), // Reduced space
              // --- Display Error Message ---
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: colorScheme.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // ---------------------------
              const SizedBox(height: 16),

              // --- Sign Up Button ---
              ElevatedButton(
                style: elevatedButtonStyle,
                // Disable button while loading or call _signUp
                onPressed: _isLoading ? null : _signUp,
                child: _isLoading
                    ? const SizedBox(
                        // Show loading indicator
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('Sign Up'),
              ),
              const SizedBox(height: 16),

              // ... (keep Disclaimer Text) ...
              Text(
                '*Nickname cannot be edited after signing up',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).extension<AppColors>()!.inactive,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
