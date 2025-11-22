import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wvsu_space/router/app_router.dart';
import 'package:wvsu_space/utils/app_colors.dart';
// bottom nav is provided by MainShell

class CommunityStandingScreen extends StatefulWidget {
  const CommunityStandingScreen({super.key});

  @override
  State<CommunityStandingScreen> createState() =>
      _CommunityStandingScreenState();
}

class _CommunityStandingScreenState extends State<CommunityStandingScreen> {
  int? _score; // 0-100
  List<Map<String, dynamic>> _recent = [];
  bool _loading = true;
  late final Future<String?> _nicknameFuture;

  // Stream subscriptions for real-time updates
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _reportsSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    _nicknameFuture = _fetchNickname();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _reportsSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListeners() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _score = null;
        _recent = [];
        _loading = false;
      });
      return;
    }

    // Listen to user document for standing changes
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((docSnapshot) async {
      if (!mounted) return;

      final data = docSnapshot.data() ?? {};

      // If user document doesn't have standing field, initialize it to 100
      if (!data.containsKey('standing') && docSnapshot.exists) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'standing': 100});
        return; // Will trigger another snapshot with updated value
      }

      int score = 100;
      if (data['standing'] is num) {
        score = (data['standing'] as num).toInt();
      } else if (data['standing'] is String) {
        score = int.tryParse(data['standing']) ?? 100;
      } else if (data['score'] is num) {
        score = (data['score'] as num).toInt();
      }

      debugPrint('=== Community Standing Real-time Update ===');
      debugPrint('UID: $uid');
      debugPrint('Document exists: ${docSnapshot.exists}');
      debugPrint('Has standing field: ${data.containsKey('standing')}');
      debugPrint('Raw standing value: ${data['standing']}');
      debugPrint('Parsed score: $score');
      debugPrint('==========================================');

      if (!mounted) return;
      setState(() {
        _score = score.clamp(0, 100);
        _loading = false;
      });
    }, onError: (error) {
      debugPrint('Error listening to user document: $error');
      if (!mounted) return;
      setState(() {
        _score = null;
        _loading = false;
      });
    });

    // Listen to standing reports for recent activity
    _reportsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('standing_reports')
        .orderBy('time', descending: true)
        .limit(3)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;
      List<Map<String, dynamic>> recent = [];
      if (snapshot.docs.isNotEmpty) {
        recent = snapshot.docs
            .map((d) {
              final m = d.data();
              return {
                'title': _displayActivityTitle(m),
                'delta': m['delta'] ?? 0,
                'time': (m['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
              };
            })
            .take(3)
            .toList();
      } else {
        // Fallback: show last activity from user doc if available
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final lastActive = userDoc.data()?['lastActiveAt'] as Timestamp?;
        if (lastActive != null) {
          recent = [
            {
              'title': 'Last active',
              'delta': 0,
              'time': lastActive.toDate(),
            }
          ];
        }
      }
      setState(() {
        _recent = recent;
      });
    }, onError: (error) {
      debugPrint('Error listening to standing reports: $error');
    });
  }

  String _displayActivityTitle(Map<String, dynamic> m) {
    final type = m['type'] as String?;
    final title = (m['title'] as String?) ?? '';
    // Primary: sanitize by type
    if (type == 'chat_rating') {
      return 'Conversation feedback received';
    }
    // Fallback: sanitize by title pattern for legacy entries
    if (title.toLowerCase().startsWith('chat rating')) {
      return 'Conversation feedback received';
    }
    // Abstract report-related activity
    if (type != null && type.contains('report')) {
      return 'Report reviewed';
    }
    final lower = title.toLowerCase();
    if (lower.startsWith('report') ||
        lower.startsWith('user report') ||
        lower.startsWith('false report')) {
      return 'Report reviewed';
    }
    return title.isNotEmpty ? title : 'Activity';
  }

  String _displayTitleString(dynamic title) {
    final t = (title as String?) ?? '';
    if (t.toLowerCase().startsWith('chat rating')) {
      return 'Conversation feedback received';
    }
    final lower = t.toLowerCase();
    if (lower.startsWith('report') ||
        lower.startsWith('user report') ||
        lower.startsWith('false report')) {
      return 'Report reviewed';
    }
    return t.isNotEmpty ? t : 'Activity';
  }

  String _standingLabel(int? score) {
    if (score == null) return 'Unknown';
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good Standing';
    if (score >= 50) return 'At Risk';
    return 'Restricted';
  }

  Color _badgeColor(int? score) {
    if (score == null) return Colors.grey;
    if (score >= 85) return BrandColors.appGreen;
    if (score >= 70) return BrandColors.appGreen;
    if (score >= 50) return Colors.orange;
    return Colors.red;
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

  Future<void> _recalculateStanding() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Get all standing reports
      final reportsSnapshot = await docRef
          .collection('standing_reports')
          .orderBy('time', descending: true)
          .get();

      // Reverse the results to process oldest first
      final docs = reportsSnapshot.docs.reversed;

      // Calculate standing from scratch (start at 100)
      int calculatedStanding = 100;
      for (var doc in docs) {
        final delta = (doc.data()['delta'] as num?)?.toInt() ?? 0;
        calculatedStanding += delta;
        debugPrint(
            'Report: ${doc.data()['title']}, Delta: $delta, New standing: $calculatedStanding');
      }

      debugPrint('Recalculated standing: $calculatedStanding');

      // Update the standing in the database (real-time listener will update UI automatically)
      await docRef
          .set({'standing': calculatedStanding}, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Standing recalculated: $calculatedStanding')),
      );
    } catch (e) {
      debugPrint('Error recalculating standing: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final score = _score ?? 100;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header - mirror HomeScreen's header layout
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
                                        style: theme.textTheme.titleMedium
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
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
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
                              icon: const Icon(Icons.refresh),
                              color: Colors.white,
                              tooltip: 'Recalculate Standing',
                              onPressed: _recalculateStanding,
                            ),
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
                              onLongPress: () async {
                                final navigator = Navigator.of(context);
                                await FirebaseAuth.instance.signOut();
                                if (!mounted) return;
                                navigator.pushNamedAndRemoveUntil(
                                  AppRouter.choose,
                                  (r) => false,
                                );
                              },
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
                                'Community Standing',
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your score & recent\nactivity',
                                style: theme.textTheme.bodyMedium?.copyWith(
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
                              Icons.leaderboard_outlined,
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

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Score circle
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 110,
                                height: 110,
                                child: CircularProgressIndicator(
                                  value: (_score ?? 100) / 100.0,
                                  strokeWidth: 8,
                                  color: BrandColors.appBlue,
                                  backgroundColor: Colors.black12,
                                ),
                              ),
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.white,
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        '$score',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: _badgeColor(score),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _standingLabel(score),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: _badgeColor(score),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keep up the great community behavior!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // How it works box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BrandColors.infoLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'How it works',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 8),
                          Text('• Gain points for positive behavior'),
                          Text('• Lose points for violations'),
                          Text('• Score affects privileges'),
                          Text('• Reviewed weekly'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Recent Activity
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BrandColors.infoLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Activity',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (!_loading && _recent.isEmpty)
                                Text(
                                  'No activity',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_loading) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ] else
                            ..._recent.map((r) {
                              final dt = r['time'] as DateTime;
                              final delta = r['delta'] ?? 0;
                              final titleStr = _displayTitleString(r['title']);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            titleStr,
                                            style: theme.textTheme.bodyLarge,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatTime(dt),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      (delta >= 0 ? '+$delta' : '$delta'),
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: delta >= 0
                                            ? BrandColors.appGreen
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          if (!_loading && _recent.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRouter.standingActivity,
                                  );
                                },
                                icon: const Icon(Icons.list_alt, size: 18),
                                label: const Text('View Full Activity'),
                                style: TextButton.styleFrom(
                                  foregroundColor: BrandColors.appBlue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: BrandColors.appBlue,
                        side: const BorderSide(
                          color: BrandColors.appBlue,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.pushNamed(
                                context,
                                AppRouter.requestReview,
                              );
                            },
                      child: const Text('Request Review'),
                    ),

                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRouter.communityGuidelines,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: BrandColors.appBlue),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('View Guidelines'),
                    ),

                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRouter.reportUser);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: BrandColors.appBlue,
                        side: const BorderSide(
                          color: BrandColors.appBlue,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Report a user'),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ], // end outer Column children
          ), // end outer Column
        ), // end SingleChildScrollView
      ), // end SafeArea
      // Bottom nav is provided by MainShell when used as a tabbed app.
      bottomNavigationBar: null,
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 1) {
      return "${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago";
    }
    if (diff.inHours >= 1) {
      return "${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago";
    }
    if (diff.inMinutes >= 1) {
      return "${diff.inMinutes} min ago";
    }
    return 'Just now';
  }
}
