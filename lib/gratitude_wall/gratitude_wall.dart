import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../router/app_router.dart';

import 'models.dart';
import 'post_tile.dart';
import 'post_composer.dart';

class GratitudeWallScreen extends StatefulWidget {
  const GratitudeWallScreen({super.key});

  @override
  State<GratitudeWallScreen> createState() => _GratitudeWallScreenState();
}

class _GratitudeWallScreenState extends State<GratitudeWallScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _startCleanupTimer();
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _startCleanupTimer() {
    // run cleanup every 60 seconds
    _cleanupTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _cleanupExpiredReleasePosts();
    });
    // run an immediate one-off as well
    _cleanupExpiredReleasePosts();
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

  Future<void> _cleanupExpiredReleasePosts() async {
    try {
      final nowTs = Timestamp.fromDate(DateTime.now().toUtc());
      // Query expired posts by expiresAt only (no composite index required).
      // Only express posts have `expiresAt` so this returns the right set.
      final q = await FirebaseFirestore.instance
          .collection('gratitude_posts')
          .where('expiresAt', isLessThan: nowTs)
          .limit(200)
          .get();
      if (q.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in q.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('cleanupExpiredReleasePosts failed: $e');
    }
  }

  Stream<List<GratitudePost>> _query(String type) {
    if (type == 'gratitude') {
      // Order by timestamp ascending so older posts appear on top and newer ones at bottom.
      return FirebaseFirestore.instance
          .collection('gratitude_posts')
          .where('type', isEqualTo: 'gratitude')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snap) {
        debugPrint('Gratitude snapshot: ${snap.docs.length} docs');
        return snap.docs.map((d) => GratitudePost.fromDoc(d)).toList();
      });
    }
    // For express posts we order by creation `timestamp` ascending so older
    // posts appear on top and newer append to the bottom. We filter expired
    // posts client-side (by `expiresAt`) to avoid requiring a composite
    // index on `expiresAt` + `timestamp`.
    return FirebaseFirestore.instance
        .collection('gratitude_posts')
        .where('type', isEqualTo: 'express')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) {
      final now = DateTime.now().toUtc();
      return snap.docs
          .map((d) => GratitudePost.fromDoc(d))
          .where(
              (p) => p.expiresAt != null && p.expiresAt!.toDate().isAfter(now))
          .toList();
    });
  }

  Future<void> _openComposer() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PostComposer(),
    );
    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Posted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header matching Home/Community screens (logo, greeting, icons)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              color: Theme.of(context).colorScheme.secondary,
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
                                future: _fetchNickname(),
                                builder: (context, snapshot) {
                                  final nickname = snapshot.data;
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Text(
                                      'Hi, …',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
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

                      // Right-side icons
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
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  // Title + subtitle (two-line style)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gratitude Wall',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Say thanks to the people you talked with',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 0.0),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.favorite,
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

            // Tab bar below header
            Material(
              color: Theme.of(context).colorScheme.secondary,
              child: TabBar(
                controller: _tabs,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Gratitude', icon: Icon(Icons.favorite)),
                  Tab(text: 'Express', icon: Icon(Icons.cloud)),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(controller: _tabs, children: [
                // Gratitude Tab
                StreamBuilder<List<GratitudePost>>(
                  stream: _query('gratitude'),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                          child:
                              Text('Error loading posts: ${snapshot.error}'));
                    }
                    final posts = snapshot.data ?? [];
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // Ensure expired express posts are cleaned up when the wall is active.
                    // Firestore TTL is the recommended server-side solution; this
                    // client-side cleanup helps while users have the app open.
                    unawaited(_cleanupExpiredReleasePosts());
                    if (posts.isEmpty) {
                      return const Center(
                          child: Text('No gratitude posts yet.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 12, bottom: 120),
                      itemCount: posts.length,
                      itemBuilder: (context, i) =>
                          PostTile(key: ValueKey(posts[i].id), post: posts[i]),
                    );
                  },
                ),

                // Express Tab: try server query first; if it errors (index
                // required), fall back to an expiresAt-only query so user
                // content remains visible.
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('gratitude_posts')
                      .where('type', isEqualTo: 'express')
                      .where('expiresAt',
                          isGreaterThan:
                              Timestamp.fromDate(DateTime.now().toUtc()))
                      .orderBy('expiresAt')
                      .snapshots(),
                  builder: (context, serverSnap) {
                    if (serverSnap.hasError) {
                      // fall back to expiresAt-only stream
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('gratitude_posts')
                            .where('expiresAt',
                                isGreaterThan:
                                    Timestamp.fromDate(DateTime.now().toUtc()))
                            .orderBy('expiresAt')
                            .snapshots(),
                        builder: (context, fallbackSnap) {
                          if (fallbackSnap.hasError) {
                            return Center(
                                child: Text(
                                    'Error loading posts: ${fallbackSnap.error}'));
                          }
                          if (fallbackSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final posts = (fallbackSnap.data?.docs ?? [])
                              .map((d) => GratitudePost.fromDoc(d))
                              .where((p) =>
                                  p.expiresAt != null &&
                                  p.expiresAt!
                                      .toDate()
                                      .isAfter(DateTime.now().toUtc()))
                              .toList();
                          if (posts.isEmpty) {
                            return const Center(
                                child: Text('No recent express posts.'));
                          }
                          return ListView.builder(
                            padding:
                                const EdgeInsets.only(top: 12, bottom: 120),
                            itemCount: posts.length,
                            itemBuilder: (context, i) => PostTile(
                                key: ValueKey(posts[i].id), post: posts[i]),
                          );
                        },
                      );
                    }

                    if (serverSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Client-side cleanup while the screen is active.
                    unawaited(_cleanupExpiredReleasePosts());

                    final posts = (serverSnap.data?.docs ?? [])
                        .map((d) => GratitudePost.fromDoc(d))
                        .where((p) =>
                            p.expiresAt != null &&
                            p.expiresAt!
                                .toDate()
                                .isAfter(DateTime.now().toUtc()))
                        .toList();
                    if (posts.isEmpty) {
                      return const Center(
                          child: Text('No recent express posts.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 12, bottom: 120),
                      itemCount: posts.length,
                      itemBuilder: (context, i) =>
                          PostTile(key: ValueKey(posts[i].id), post: posts[i]),
                    );
                  },
                ),
              ]),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _openComposer,
        child: const Icon(Icons.add),
      ),
    );
  }
}
