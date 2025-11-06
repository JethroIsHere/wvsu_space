import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../router/app_router.dart';
import '../utils/app_colors.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = FirebaseAuth.instance.currentUser;
      bool isAdmin = false;
      if (user != null) {
        try {
          final token = await user.getIdTokenResult(true);
          isAdmin = (token.claims ?? const {})['admin'] == true;
        } catch (_) {}
      }
      if (!mounted) return;
      if (!isAdmin) {
        _error = 'This account does not have admin access.';
        await FirebaseAuth.instance.signOut();
        setState(() => _loading = false);
        return;
      }
      navigator.pushReplacementNamed(AppRouter.adminDashboard);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == 'invalid-credential'
            ? 'Invalid email or password.'
            : 'Sign-in failed: ${e.message ?? e.code}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unexpected error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Color(0xFFFFB703),
        width: 1.5,
      ), // orange-like
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Portal'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Shield icon
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: BrandColors.appBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Headline & subtext
              const Center(
                child: Text(
                  'Secure Admin Access',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Enter your administrator credentials to\naccess the moderation dashboard',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Email
              const Text('Email'),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.badge_outlined),
                  hintText: 'Write your email',
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Password
              const Text('Password'),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  hintText: 'Write your password',
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],

              const SizedBox(height: 20),
              // Sign In button
              ElevatedButton(
                onPressed: _loading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.appBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),

              const SizedBox(height: 16),
              // Security notice card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security Notice',
                      style: TextStyle(
                        color: Color(0xFFFF8F00),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    _Bullet('All admin actions are logged and audited'),
                    _Bullet('Unauthorized access attempts are monitored'),
                    _Bullet('Sessions expire after 30 minutes of inactivity'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5.0),
          child: Icon(Icons.circle, size: 6, color: Colors.black54),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
