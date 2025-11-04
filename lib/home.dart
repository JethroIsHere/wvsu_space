import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'getting_started.dart';
import 'router/app_router.dart';
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
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GettingStartedScreen()),
        (route) => false,
      );
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Settings tapped'),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.account_circle),
                              color: Colors.white,
                              tooltip: 'Profile',
                              onPressed: () async {
                                final email =
                                    FirebaseAuth.instance.currentUser?.email;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(email ?? 'Profile')),
                                );
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
                        const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                          size: 28,
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
                                color: const Color(
                                  0xFFFFD60A,
                                ).withValues(alpha: 0.2),
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
                                color: const Color(
                                  0xFF34C759,
                                ).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.groups_2,
                                color: Color(0xFF34C759),
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
      bottomNavigationBar: _BottomNav(currentIndex: 0),
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

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.chat_bubble,
                label: 'Chat',
                selected: currentIndex == 0,
                selectedColor: colorScheme.primary,
              ),
              _NavItem(
                icon: Icons.forum_outlined,
                label: 'Rooms',
                selected: currentIndex == 1,
                selectedColor: colorScheme.primary,
              ),
              _NavItem(
                icon: Icons.favorite_border,
                label: 'Gratitude',
                selected: currentIndex == 2,
                selectedColor: colorScheme.primary,
              ),
              _NavItem(
                icon: Icons.leaderboard_outlined,
                label: 'Standing',
                selected: currentIndex == 3,
                selectedColor: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final base = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: selected ? Colors.white : Colors.black54),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ],
    );

    if (!selected) return base;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: BoxDecoration(
        color: selectedColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: base,
    );
  }
}
