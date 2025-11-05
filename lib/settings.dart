import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'router/app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

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
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preferences
            Text('PREFERENCES', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                trailing: Switch.adaptive(
                  value: _notificationsEnabled,
                  onChanged: (v) {
                    setState(() => _notificationsEnabled = v);
                    // TODO: persist preference to Firestore or local storage if desired
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Support
            Text('SUPPORT', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Community Guidelines'),
                onTap: () =>
                    Navigator.pushNamed(context, AppRouter.communityGuidelines),
              ),
            ),
            const SizedBox(height: 16),

            // Account
            Text('ACCOUNT', style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, AppRouter.deleteAccount),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_outlined,
                      color: Colors.blue,
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.blue),
                    ),
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      await FirebaseAuth.instance.signOut();
                      navigator.pushNamedAndRemoveUntil(
                        AppRouter.choose,
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Note: the detailed delete flow is handled on a dedicated screen (`DeleteAccountScreen`).
}
