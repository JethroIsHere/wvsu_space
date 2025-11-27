// WVSU Space — `lib/features/home/home.dart`
// Home screen: greeting, quick access to matching and quick chat, and
// a summary of activity. Handles last-active tracking and notification checks.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wvsu_space/router/app_router.dart';
// Bottom navigation is provided by MainShell. This screen also triggers
// a brief notification check after startup so users see important warnings.
import 'package:wvsu_space/utils/notification_checker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final Future<String?> _nicknameFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nicknameFuture = _fetchNickname();
    _updateLastActive(); // Track user activity
    // Check for notifications after a short delay to let UI settle
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        NotificationChecker.checkAndShowNotifications(context);
      }
    });
  }

  Future<void> _updateLastActive() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
        // Maintain legacy field for compatibility
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to update lastActive: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Update last active when app returns to foreground
      _updateLastActive();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<String?> _fetchNickname() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      return data?['nickname'] as String?;
    } catch (e) {
      debugPrint('Failed to fetch nickname: $e');
      return null;
    }
  }

  Future<bool> _hasUnacknowledgedNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = userDoc.data();
      if (data == null) return false;

      final warningCount = (data['warningCount'] as num?)?.toInt() ?? 0;
      if (warningCount == 0) return false;

      final lastWarningAt = data['lastWarningAt'] as Timestamp?;
      final lastAcknowledgedAt =
          data['lastWarningAcknowledgedAt'] as Timestamp?;

      // Check if there are new warnings since last acknowledgment
      if (lastAcknowledgedAt == null ||
          (lastWarningAt != null &&
              lastWarningAt.millisecondsSinceEpoch >
                  lastAcknowledgedAt.millisecondsSinceEpoch)) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Failed to check notifications: $e');
      return false;
    }
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.signOut();
      navigator.pushNamedAndRemoveUntil(AppRouter.choose, (route) => false);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              color: colorScheme.secondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App logo + Nickname greeting
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/wvsu_space_logo.png',
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FutureBuilder<String?>(
                                future: _nicknameFuture,
                                builder: (context, snapshot) {
                                  final nickname = snapshot.data;
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Text(
                                      'Hi, …',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.titleMedium?.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }
                                  if (nickname == null || nickname.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    'Hi, $nickname!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          FutureBuilder<bool>(
                            future: _hasUnacknowledgedNotifications(),
                            builder: (context, snapshot) {
                              final hasUnread = snapshot.data ?? false;
                              return Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.notifications_outlined),
                                    color: Colors.white,
                                    tooltip: 'Notifications',
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRouter.notifications,
                                      );
                                    },
                                  ),
                                  if (hasUnread)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            color: Colors.white,
                            tooltip: 'Settings',
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRouter.settings,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_circle),
                            color: Colors.white,
                            tooltip: 'Profile',
                            onPressed: () {
                              Navigator.pushNamed(context, AppRouter.profile);
                            },
                            onLongPress: () => _logout(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Random Chat',
                              style: textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Talk with schoolmates\nanonymously',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 20.0),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Centered Interest Matching + Quick Chat block
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Interest Matching (centered, prominent)
                          _OutlinedCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18.0, vertical: 14.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          colorScheme.primary,
                                          colorScheme.primary
                                              .withValues(alpha: 0.8)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colorScheme.primary
                                              .withValues(alpha: 0.25),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.interests,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Interest Matching',
                                    style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 24),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Connect with people who share your interests',
                                    style: textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: 220,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14, horizontal: 18),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(28),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRouter.lobby,
                                          arguments: {
                                            'mode': 'keyword',
                                            'lock': true
                                          },
                                        );
                                      },
                                      child: const Text('Find Match'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Quick Chat (now Search) (centered, simple) — slightly larger to balance spacing
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 140),
                            child: _OutlinedCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18.0, vertical: 22.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Quick Chat',
                                            style: textTheme.titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Connect instantly with anyone online',
                                            style: textTheme.bodySmall,
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: colorScheme.primary,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 20),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          AppRouter.lobby,
                                          arguments: {
                                            'mode': 'random',
                                            'lock': true
                                          },
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.search, size: 18),
                                          SizedBox(width: 8),
                                          Text('Search'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // (Removed Gratitude Wall and Vibe Rooms cards beneath Quick Chat)

            // Removed extra bottom space to hug the bottom nav bar
          ],
        ),
      ),
      // Bottom nav is provided by the MainShell when used as a tabbed app.
      bottomNavigationBar: null,
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  final Widget child;
  const _OutlinedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use a Stack so we can reliably paint the border as an overlay on top
    // of the child on all devices. The overlay is an IgnorePointer so it
    // does not conflict with the taps.
    return Stack(
      children: [
        // Base card with background and rounded corners
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: child,
        ),
        // Border overlay always paints on top
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary, width: 1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Bottom navigation moved to reusable widget in lib/widgets/bottom_nav.dart
