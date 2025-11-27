import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// WVSU Space — `lib/features/standing/standing_activity.dart`
// UI for the community standing activity — shows seasonal leaderboards and progress.
import 'package:flutter/material.dart';
import 'package:wvsu_space/utils/app_colors.dart';

class StandingActivityScreen extends StatefulWidget {
  const StandingActivityScreen({super.key});

  @override
  State<StandingActivityScreen> createState() => _StandingActivityScreenState();
}

class _StandingActivityScreenState extends State<StandingActivityScreen> {
  StreamSubscription<QuerySnapshot>? _reportsSubscription;
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _setupActivityListener();
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    super.dispose();
  }

  void _setupActivityListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _activities = [];
        _loading = false;
      });
      return;
    }

    // Listen to all standing reports
    _reportsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('standing_reports')
        .orderBy('time', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final activities = snapshot.docs.map((d) {
        final m = d.data();
        return {
          'title': _displayActivityTitle(m),
          'delta': m['delta'] ?? 0,
          'time': (m['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();

      setState(() {
        _activities = activities;
        _loading = false;
      });
    }, onError: (error) {
      debugPrint('Error listening to standing reports: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    });
  }

  String _displayActivityTitle(Map<String, dynamic> m) {
    final type = m['type'] as String?;
    final title = (m['title'] as String?) ?? '';
    if (type == 'chat_rating') {
      return 'Conversation feedback received';
    }
    if (title.toLowerCase().startsWith('chat rating')) {
      return 'Conversation feedback received';
    }
    // Abstract any report-related activity
    if (type != null && (type.contains('report'))) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Activity History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Activity Yet',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your standing activity history will appear here',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activities.length,
                  itemBuilder: (context, index) {
                    final activity = _activities[index];
                    final title = activity['title'] as String? ?? 'Activity';
                    final delta = activity['delta'] as int? ?? 0;
                    final time = activity['time'] as DateTime;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Delta badge
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: delta >= 0
                                  ? BrandColors.appGreen.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              delta >= 0 ? '+$delta' : '$delta',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: delta >= 0
                                    ? BrandColors.appGreen
                                    : Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Activity details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTime(time),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Arrow icon
                          Icon(
                            delta >= 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color:
                                delta >= 0 ? BrandColors.appGreen : Colors.red,
                            size: 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return "$months month${months > 1 ? 's' : ''} ago";
    }
    if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return "$weeks week${weeks > 1 ? 's' : ''} ago";
    }
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
