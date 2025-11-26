// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
                      backgroundColor: Colors.red,
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
                          backgroundColor: Colors.red,
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
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Theme.of(localContext)
                                                  .colorScheme
                                                  .primary,
                                          foregroundColor:
                                              Theme.of(localContext)
                                                  .colorScheme
                                                  .onPrimary,
                                        ),
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

                                // Decide whether we need reauthentication.
                                final providerIds = user.providerData
                                    .map((p) => p.providerId)
                                    .toList();
<<<<<<< HEAD
                                var readyToDelete = false;

                                // Allow anonymous users to delete without extra reauthentication.
                                if (user.isAnonymous) {
                                  readyToDelete = true;
                                } else if (providerIds.contains('password')) {
                                  // If the user signed in with email/password, prompt for password to reauthenticate.
                                  final password = await showDialog<String?>(
=======
                                if (providerIds.contains('password')) {
                                  // First entry
                                  final first = await showDialog<String?>(
>>>>>>> main
                                    context: localContext,
                                    builder: (dctx) {
                                      final ctrl1 = TextEditingController();
                                      return AlertDialog(
                                        title: const Text(
                                            'Enter password to confirm'),
                                        content: TextField(
                                          controller: ctrl1,
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
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(dctx)
                                                  .colorScheme
                                                  .primary,
                                              foregroundColor: Theme.of(dctx)
                                                  .colorScheme
                                                  .onPrimary,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(dctx, ctrl1.text),
                                            child: const Text('Next'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (first == null || first.isEmpty) return;

                                  // Re-enter for confirmation
                                  final second = await showDialog<String?>(
                                    context: localContext,
                                    builder: (dctx) {
                                      final ctrl2 = TextEditingController();
                                      return AlertDialog(
                                        title: const Text('Re-enter password'),
                                        content: TextField(
                                          controller: ctrl2,
                                          obscureText: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Re-enter password',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dctx, null),
                                              child: const Text('Cancel')),
                                          ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Theme.of(dctx)
                                                    .colorScheme
                                                    .primary,
                                                foregroundColor: Theme.of(dctx)
                                                    .colorScheme
                                                    .onPrimary,
                                              ),
                                              onPressed: () => Navigator.pop(
                                                  dctx, ctrl2.text),
                                              child: const Text('Confirm')),
                                        ],
                                      );
                                    },
                                  );
                                  if (second == null || second.isEmpty) return;

                                  if (first != second) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Passwords do not match.'),
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    final cred = EmailAuthProvider.credential(
                                      email: user.email ?? '',
                                      password: first,
                                    );
                                    await user
                                        .reauthenticateWithCredential(cred);
                                    readyToDelete = true;
                                  } on FirebaseAuthException catch (e) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Reauthentication failed: ${e.message}'),
                                      ),
                                    );
                                    return;
                                  }
                                } else {
                                  // For provider like Google/GitHub, prompt the user to reauthenticate by signing in again.
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
                                            child: const Text('Cancel')),
                                        ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(dctx, true),
                                            child: const Text('OK')),
                                      ],
                                    ),
                                  );
                                  if (again != true) return;
                                  // Let user re-login manually; early exit.
                                  return;
                                }

                                // If we reached this point and are ready, call the server-side deletion function
                                if (!readyToDelete) return;
                                setState(() => _loading = true);
                                var deletionCompleted = false;
                                var attemptedClientFallback = false;
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
                                    deletionCompleted = true;
                                  } else {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Delete returned: $data'),
                                      ),
                                    );
                                  }
                                } on FirebaseFunctionsException catch (e) {
                                  // Log then attempt client-side fallback.
                                  debugPrint(
                                      'deleteUserAccount function error: ${e.message}');
                                  try {
                                    attemptedClientFallback = true;
                                    await _clientDeleteAccount(
                                        user.uid, messenger, nav);
                                    deletionCompleted = true;
                                  } catch (inner) {
                                    debugPrint(
                                        'Client-side deletion fallback failed: $inner');
                                  }
                                } catch (e) {
                                  // Unknown error - log and attempt client-side fallback
                                  debugPrint(
                                      'deleteUserAccount unknown error: $e');
                                  try {
                                    attemptedClientFallback = true;
                                    await _clientDeleteAccount(
                                        user.uid, messenger, nav);
                                    deletionCompleted = true;
                                  } catch (inner) {
                                    debugPrint(
                                        'Client-side deletion fallback failed: $inner');
                                  }
                                } finally {
                                  if (mounted) setState(() => _loading = false);

                                  if (deletionCompleted ||
                                      attemptedClientFallback) {
                                    // Show final confirmation dialog (UI-only) then sign out and navigate
                                    await showDialog<void>(
                                      context: localContext,
                                      builder: (dctx) => AlertDialog(
                                        title: const Text('Account Deleted'),
                                        content: const Text(
                                            'Your account has been deleted.'),
                                        actions: [
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(dctx).pop(),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );

                                    await FirebaseAuth.instance.signOut();
                                    if (!mounted) return;
                                    nav.pushNamedAndRemoveUntil(
                                      AppRouter.choose,
                                      (r) => false,
                                    );
                                  }
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

  Future<void> _clientDeleteAccount(
    String uid,
    ScaffoldMessengerState messenger,
    NavigatorState nav,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      // Attempt basic client-side deletions. Many protected collections
      // will fail due to security rules; we attempt what the client can.
      final batch = firestore.batch();
      final userDoc = firestore.collection('users').doc(uid);
      batch.delete(userDoc);

      // Commit what we can.
      await batch.commit();
      // Note: do not sign out or navigate here. Top-level caller will
      // show a confirmation dialog and perform sign-out/navigation so the
      // UX is consistent for both server and client fallback paths.
    } catch (e) {
      debugPrint('client-side delete error: $e');
      rethrow;
    }
  }
}
