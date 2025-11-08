import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'utils/app_colors.dart';
import 'router/app_router.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void initState() {
    super.initState();
    // Rebuild when form fields change so the Update button can enable/disable
    _currentCtrl.addListener(_onFormChanged);
    _newCtrl.addListener(_onFormChanged);
    _confirmCtrl.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    // Extra client-side validation for password strength
    final newPwd = _newCtrl.text.trim();
    final strengthError = _passwordValidationMessage(newPwd);
    if (strengthError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strengthError)));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No user signed in')));
      return;
    }

    setState(() => _loading = true);
    try {
      // If the user doesn't have an email/password provider attached,
      // they likely signed in via Google/Apple and cannot reauthenticate
      // using an email credential. Detect that and show a helpful message.
      final providerIds = user.providerData.map((p) => p.providerId).toList();
      final hasPasswordProvider = providerIds.contains('password');
      if (!hasPasswordProvider) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reauthentication required'),
            content: Text(
              'This account signs in using ${providerIds.join(", ")}.\n\n'
              'To change your password you must sign in with an email/password account. '
              'You can sign out and sign in again with an email account, or use the original provider to manage your account.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                },
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRouter.choose, (_) => false);
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
        return;
      }

      // Reauthenticate with current password
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentCtrl.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);

      // Update password
      await user.updatePassword(_newCtrl.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated')));
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? e.code;
      // Map common FirebaseAuthException codes to friendly messages
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Current password is incorrect';
          break;
        case 'weak-password':
          message =
              'Choose a stronger password (at least 8 characters with letters and numbers)';
          break;
        case 'requires-recent-login':
          message =
              'Please sign out and sign in again, then try changing your password';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your connection and try again';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Try again later';
          break;
        default:
          // leave message from exception
          break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Whether the form currently meets basic validation requirements.
  bool get _isFormValid {
    if (_loading) return false;
    final currentValid = _currentCtrl.text.trim().isNotEmpty;
    final newMsg = _passwordValidationMessage(_newCtrl.text);
    final newValid = newMsg == null;
    final confirmValid =
        _confirmCtrl.text.trim().isNotEmpty &&
        _confirmCtrl.text == _newCtrl.text;
    return currentValid && newValid && confirmValid;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Change Password',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BrandColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Password Security',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Choose a strong password to keep your WVSU Space account secure. Your password protects your anonymous identity and chat history.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'Current Password',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      _buildPasswordField(
                        _currentCtrl,
                        'Enter your current password',
                        _showCurrent,
                        () => setState(() => _showCurrent = !_showCurrent),
                      ),
                      const SizedBox(height: 16),

                      Text('New Password', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      _buildPasswordField(
                        _newCtrl,
                        'Enter your new password',
                        _showNew,
                        () => setState(() => _showNew = !_showNew),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Confirm New Password',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      _buildPasswordField(
                        _confirmCtrl,
                        'Enter your new password',
                        _showConfirm,
                        () => setState(() => _showConfirm = !_showConfirm),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your new password';
                          }
                          if (v != _newCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: BrandColors.appBlue,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isFormValid ? _updatePassword : null,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: BrandColors.appBlue,
                                ),
                              )
                            : const Text('Update Password'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: BrandColors.cancelBg,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    TextEditingController ctrl,
    String hint,
    bool visible,
    VoidCallback toggle, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: !visible,
      validator:
          validator ??
          (v) => (v == null || v.isEmpty) ? 'Please enter a value' : null,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BrandColors.appYellow),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BrandColors.appYellow, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
      ),
    );
  }

  // Returns an error message string if the password is invalid, otherwise null.
  String? _passwordValidationMessage(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter a new password';
    if (v.length < 8) return 'Password must be at least 8 characters';
    // Require at least one letter and one number
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    if (!hasLetter || !hasDigit) {
      return 'Password must contain letters and numbers';
    }
    return null;
  }
}
