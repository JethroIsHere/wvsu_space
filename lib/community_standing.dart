import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'utils/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStanding();
    _nicknameFuture = _fetchNickname();
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

  Future<void> _recalculateStanding() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Get all standing reports
      final reportsSnapshot = await docRef
          .collection('standing_reports')
          .orderBy('time', descending: false)
          .get();

      // Calculate standing from scratch (start at 100)
      int calculatedStanding = 100;
      for (var doc in reportsSnapshot.docs) {
        final delta = (doc.data()['delta'] as num?)?.toInt() ?? 0;
        calculatedStanding += delta;
        debugPrint(
            'Report: ${doc.data()['title']}, Delta: $delta, New standing: $calculatedStanding');
      }

      debugPrint('Recalculated standing: $calculatedStanding');

      // Update the standing in the database
      await docRef.update({'standing': calculatedStanding});

      // Reload the display
      await _loadStanding();

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

  Future<void> _loadStanding() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _score = null;
        _recent = [];
        _loading = false;
      });
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await docRef.get();
      final data = doc.data() ?? {};

      // If user document doesn't have standing field at all, initialize it to 100
      // Don't reset if it's 0 or negative - those are legitimate low scores
      if (!data.containsKey('standing') && doc.exists) {
        await docRef.update({'standing': 100});
        data['standing'] = 100;
      }

      final scoreVal = data['standing'] ?? data['score'] ?? 100;
      final score = (scoreVal is num)
          ? scoreVal.toInt()
          : int.tryParse('$scoreVal') ?? 100; // Default to 100 instead of 0

      debugPrint('=== Community Standing Debug ===');
      debugPrint('UID: $uid');
      debugPrint('Document exists: ${doc.exists}');
      debugPrint('Has standing field: ${data.containsKey('standing')}');
      debugPrint('Raw standing value: ${data['standing']}');
      debugPrint('Raw standing type: ${data['standing'].runtimeType}');
      debugPrint('Score val: $scoreVal');
      debugPrint('Parsed score: $score');
      debugPrint('===============================');

      final reportsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('standing_reports')
          .orderBy('time', descending: true)
          .limit(6)
          .get();

      final recent = reportsSnap.docs.map((d) {
        final m = d.data();
        return {
          'title': m['title'] ?? 'Report',
          'delta': m['delta'] ?? 0,
          'time': (m['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _score = score.clamp(0, 100);
        _recent = recent;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _score = null;
        _recent = [];
        _loading = false;
      });
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
                              Icons.sentiment_satisfied,
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
                                            r['title'] ?? 'Activity',
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
