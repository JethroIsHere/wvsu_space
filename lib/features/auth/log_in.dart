import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wvsu_space/main.dart';
import 'package:wvsu_space/router/app_router.dart';
import 'package:wvsu_space/widgets/app_button.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  // --- Add Controllers ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // ----------------------

  bool _obscurePassword = true;
  bool _isLoading = false; // --- Add loading state ---
  String? _errorMessage; // --- Add error message state ---
  bool _rememberMe = false; // --- Remember me toggle ---

  @override
  void dispose() {
    // --- Dispose controllers ---
    _emailController.dispose();
    _passwordController.dispose();
    // -------------------------
    super.dispose();
  }

  // --- Log In Function ---
  Future<void> _logIn() async {
    final navigator = Navigator.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    // Enforce WVSU-only email addresses before attempting sign-in
    final rawEmail = _emailController.text.trim();
    final emailLower = rawEmail.toLowerCase();
    // Allow WVSU emails or the developer test email `jet3danocup@gmail.com`.
    final allowedEmailRegExp =
        RegExp(r'(^[^@\s]+@wvsu\.edu\.ph$)|(^jet3danocup@gmail\.com$)');
    if (!allowedEmailRegExp.hasMatch(emailLower)) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Please sign in with a WVSU email (ending in @wvsu.edu.ph).';
        });
      }
      return;
    }

    try {
      // 1. Sign in user with Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: rawEmail,
        password: _passwordController.text.trim(),
      );

      // 2. Persist or clear remembered email
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString(
            'remembered_email',
            _emailController.text.trim(),
          );
          await prefs.setBool('remember_me', true);
        } else {
          await prefs.remove('remembered_email');
          await prefs.setBool('remember_me', false);
        }
      } catch (e) {
        debugPrint('SharedPreferences error: $e');
      }

      // 3. Require email verification for WVSU sign-ins.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        // Attempt to resend verification email, then sign out and inform user.
        try {
          await user.sendEmailVerification();
        } catch (e) {
          debugPrint('Failed to send verification email: $e');
        }
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Email not verified'),
              content: const Text(
                  'Please verify your WVSU email. A verification link was (re)sent to your inbox.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 4. Navigate based on custom claims: admin -> admin reports, else home
      bool isAdmin = false;
      if (user != null) {
        try {
          final token = await user.getIdTokenResult(true);
          final claims = token.claims ?? {};
          isAdmin = claims['admin'] == true;
        } catch (_) {
          // ignore, default to non-admin
        }
      }
      if (!mounted) return;
      if (isAdmin) {
        navigator.pushReplacementNamed(AppRouter.adminReports);
      } else {
        navigator.pushReplacementNamed(AppRouter.home);
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase errors
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        _errorMessage = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'The email address is not valid.';
      } else {
        _errorMessage = 'An error occurred. Please try again.';
      }
      debugPrint('Firebase Auth Error: ${e.message}'); // Log for debugging
    } catch (e) {
      // Handle other potential errors
      _errorMessage = 'An unexpected error occurred.';
      debugPrint('Log In Error: $e'); // Log for debugging
    } finally {
      // Ensure loading state is turned off
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // ---------------------

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('remembered_email');
      final savedFlag = prefs.getBool('remember_me') ?? false;
      if (saved != null && saved.isNotEmpty) {
        _emailController.text = saved;
      }
      setState(() {
        _rememberMe = savedFlag && (saved?.isNotEmpty ?? false);
      });
    } catch (e) {
      debugPrint('SharedPreferences read error: $e');
    }
  }

  Future<void> _sendPasswordReset() async {
    final rawEmail = _emailController.text.trim();
    if (rawEmail.isEmpty) {
      setState(
          () => _errorMessage = 'Enter your email to reset your password.');
      return;
    }

    // Enforce WVSU-only email addresses for password reset
    final emailLower = rawEmail.toLowerCase();
    // Allow WVSU emails or the developer test email `jet3danocup@gmail.com`.
    final allowedEmailRegExp =
        RegExp(r'(^[^@\s]+@wvsu\.edu\.ph$)|(^jet3danocup@gmail\.com$)');
    if (!allowedEmailRegExp.hasMatch(emailLower)) {
      setState(() => _errorMessage =
          'Password reset is only available for WVSU emails (ending in @wvsu.edu.ph).');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: rawEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      final code = e.code;
      String msg = 'Could not send reset email. Please try again.';
      if (code == 'user-not-found') msg = 'No account found for that email.';
      if (code == 'invalid-email') msg = 'The email address is not valid.';
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                'Welcome Back!',
                style: textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Don\'t have an account yet? ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).extension<AppColors>()!.inactive,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, AppRouter.signUp);
                    },
                    child: Text(
                      'Sign Up',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

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
              const SizedBox(height: 6),
              Text(
                'Sign in with your WVSU email (ending in @wvsu.edu.ph).',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).extension<AppColors>()!.inactive,
                ),
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
              const SizedBox(height: 12),

              // Forgot password + Remember me
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) {
                          setState(() => _rememberMe = (v ?? false));
                        },
                      ),
                      Text('Remember me', style: textTheme.bodyMedium),
                    ],
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _sendPasswordReset,
                    style: TextButton.styleFrom(textStyle: textTheme.bodySmall),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),

              const SizedBox(height: 8),

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

              const SizedBox(height: 16),

              // --- Log In Button ---
              AppButton(
                style: elevatedButtonStyle,
                onPressed: _isLoading ? null : _logIn,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('Log In'),
              ),
              const SizedBox(height: 16),

              // Disclaimer
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
