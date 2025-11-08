import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'router/app_router.dart';
// bottom nav is provided by MainShell
import 'utils/app_colors.dart';
// Reverted: removed Rooms screen import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<String?> _nicknameFuture;

  @override
  void initState() {
    super.initState();
    _nicknameFuture = _fetchNickname();
  }

  Future<String?> _fetchNickname() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data();
      return data?['nickname'] as String?;
    } catch (e) {
      debugPrint('Failed to fetch nickname: $e');
      return null;
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
        child: SingleChildScrollView(
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

              const SizedBox(height: 12),

              // Interest Matching Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _OutlinedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.shield_moon_outlined,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Interest Matching',
                                style: textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Find users with similar interests',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            textStyle: textTheme.labelLarge,
                            minimumSize: const Size(double.infinity, 50),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRouter.lobby,
                              arguments: {'mode': 'keyword', 'lock': true},
                            );
                          },
                          child: const Text('Find Match'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Quick Chat Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _OutlinedCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connect instantly\nwith anyone online',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRouter.lobby,
                            arguments: {'mode': 'random', 'lock': true},
                          );
                        },
                        child: const Text('Quick Chat'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Stack cards vertically for better fit: Gratitude Wall and Themed Rooms
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 104),
                      child: _OutlinedCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD60A).withAlpha(51),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: Color(0xFFFFD60A),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gratitude Wall',
                                    style: textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Share positive vibes',
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 104),
                      child: _OutlinedCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: BrandColors.appGreen.withAlpha(51),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.groups_2,
                                color: BrandColors.appGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Themed Rooms',
                                    style: textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Join similar interest groups & more',
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Removed extra bottom space to hug the bottom nav bar
            ],
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

// Bottom navigation moved to reusable widget in lib/widgets/bottom_nav.dart
