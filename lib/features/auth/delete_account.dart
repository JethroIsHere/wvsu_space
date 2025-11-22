// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wvsu_space/router/app_router.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _loading = false;

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
          'Delete Account',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 28.0,
                  horizontal: 20.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.redAccent,
                      child: const Icon(
                        Icons.delete_outline,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Delete Account?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This action cannot be undone. All your data will be permanently removed from WVSU Space.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'What will be deleted:',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 8),
                          Text('• Your anonymous chat history'),
                          Text('• Gratitude posts and likes'),
                          Text('• Community standing score'),
                          Text('• Account preferences'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _loading
                            ? null
                            : () async {
                                final localContext = context;
                                final messenger = ScaffoldMessenger.of(
                                  localContext,
                                );
                                final nav = Navigator.of(localContext);
                                final confirmed = await showDialog<bool>(
                                  context: localContext,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm Deletion'),
                                    content: const Text(
                                      'Are you sure you want to permanently delete your account? This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Yes, delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;

                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('No signed-in user found.'),
                                    ),
                                  );
                                  return;
                                }

                                // If the user signed in with email/password, prompt for password to reauthenticate.
                                final providerIds = user.providerData
                                    .map((p) => p.providerId)
                                    .toList();
                                if (providerIds.contains('password')) {
                                  final password = await showDialog<String?>(
                                    context: localContext,
                                    builder: (dctx) {
                                      final ctrl = TextEditingController();
                                      return AlertDialog(
                                        title: const Text('Re-enter password'),
                                        content: TextField(
                                          controller: ctrl,
                                          obscureText: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Password',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dctx, null),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(dctx, ctrl.text),
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (password == null || password.isEmpty) {
                                    return;
                                  }
                                  try {
                                    final cred = EmailAuthProvider.credential(
                                      email: user.email ?? '',
                                      password: password,
                                    );
                                    await user.reauthenticateWithCredential(
                                      cred,
                                    );
                                  } on FirebaseAuthException catch (e) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Reauthentication failed: ${e.message}',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                } else {
                                  // For provider like google/github, instruct user to sign in again (simple approach).
                                  final again = await showDialog<bool>(
                                    context: localContext,
                                    builder: (dctx) => AlertDialog(
                                      title: const Text('Reauthenticate'),
                                      content: const Text(
                                        'To delete your account you must reauthenticate. Please sign out and sign in again with your provider, then try deletion.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(dctx, true),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (again != true) return;
                                  // Let user re-login manually; early exit.
                                  return;
                                }

                                // Call the server-side deletion function
                                setState(() => _loading = true);
                                try {
                                  final functions = FirebaseFunctions.instance;
                                  final callable = functions.httpsCallable(
                                    'deleteUserAccount',
                                  );
                                  final resp = await callable.call(
                                    <String, dynamic>{'dryRun': false},
                                  );
                                  final data =
                                      resp.data as Map<String, dynamic>;
                                  if (!mounted) return;
                                  if (data['success'] == true) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Account deleted successfully.',
                                        ),
                                      ),
                                    );
                                    // Sign out and navigate to the choose (sign in / sign up) screen
                                    await FirebaseAuth.instance.signOut();
                                    if (!mounted) return;
                                    nav.pushNamedAndRemoveUntil(
                                      AppRouter.choose,
                                      (r) => false,
                                    );
                                  } else {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Delete returned: $data'),
                                      ),
                                    );
                                  }
                                } on FirebaseFunctionsException catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Server error: ${e.message}',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                } finally {
                                  if (mounted) setState(() => _loading = false);
                                }
                              },
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Yes, Delete My Account'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Keep My Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
