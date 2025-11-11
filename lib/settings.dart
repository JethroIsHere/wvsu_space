import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'router/app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  static const _kNotificationsKey = 'notifications_enabled';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_kNotificationsKey);
      if (saved != null) {
        setState(() => _notificationsEnabled = saved);
      }
    } catch (_) {
      // If prefs fail to load for any reason, keep default value.
    }
  }

  Future<void> _saveNotificationsPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNotificationsKey, value);
    } catch (_) {
      // Ignore failures - preference saving is best-effort local persistence.
    }
  }

  Future<int> _getWarningCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      return (data?['warningCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
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
                  onChanged: (v) async {
                    setState(() => _notificationsEnabled = v);
                    await _saveNotificationsPreference(v);
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
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Community Guidelines'),
                    onTap: () => Navigator.pushNamed(
                        context, AppRouter.communityGuidelines),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined,
                        color: Colors.orange),
                    title: const Text('Account Notifications'),
                    trailing: FutureBuilder<int>(
                      future: _getWarningCount(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, AppRouter.notifications),
                  ),
                ],
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
