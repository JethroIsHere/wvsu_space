// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LogsAndAppealsScreen extends StatefulWidget {
  const LogsAndAppealsScreen({super.key});

  @override
  State<LogsAndAppealsScreen> createState() => _LogsAndAppealsScreenState();
}

// Top-level helper to update appeal status with a serverTimestamp fallback for web.
Future<void> _updateAppealStatus(String appealId, bool approve) async {
  final ref = FirebaseFirestore.instance
      .collection('admin_review_requests')
      .doc(appealId);
  try {
    await ref.update({
      'status': approve ? 'approved' : 'rejected',
      'decidedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    await ref.update({
      'status': approve ? 'approved' : 'rejected',
      'decidedAt': Timestamp.now(),
    });
  }
}

class _LogsAndAppealsScreenState extends State<LogsAndAppealsScreen> {
  bool _isAdmin = false;
  bool _loadingAdmin = true;
  String _tab = 'logs'; // logs | appeals

  @override
  void initState() {
    super.initState();
    _checkIsAdmin();
  }

  Future<void> _checkIsAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isAdmin = false;
          _loadingAdmin = false;
        });
        return;
      }
      final token = await user.getIdTokenResult(true);
      setState(() {
        _isAdmin = (token.claims ?? const {})['admin'] == true;
        _loadingAdmin = false;
      });
    } catch (_) {
      setState(() {
        _isAdmin = false;
        _loadingAdmin = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Logs & Appeals',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ) ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loadingAdmin
          ? const Center(child: CircularProgressIndicator())
          : (!_isAdmin)
              ? _NotAuthorized()
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    _SegmentedTabs(
                      selected: _tab,
                      onChanged: (val) => setState(() => _tab = val),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _tab == 'logs'
                          ? const _AdminLogsTab()
                          : const _AppealsTab(),
                    ),
                  ],
                ),
    );
  }
}

class _NotAuthorized extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Not authorized.'),
          ],
        ),
      ),
    );
  }
}

class _AdminLogsTab extends StatelessWidget {
  const _AdminLogsTab();

  @override
  Widget build(BuildContext context) {
    // Merge standing_reports (collectionGroup) with admin_review_requests so appeals
    // also appear in the moderation logs. Use nested StreamBuilders and client-side
    // merging/sorting to avoid composite index requirements.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('standing_reports')
          .orderBy('time', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, standingSnap) {
        if (standingSnap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading logs: ${standingSnap.error}',
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!standingSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('admin_review_requests')
              .orderBy('time', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, appealsSnap) {
            if (appealsSnap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading appeals: ${appealsSnap.error}',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Collect standing report docs
            final standingDocs = standingSnap.data?.docs ?? [];

            // Collect appeals (if available) and keep a set of appeal ids
            final entries = <Map<String, dynamic>>[];
            final presentAppealIds = <String>{};
            if (appealsSnap.hasData) {
              for (final a in appealsSnap.data!.docs) {
                final data = a.data();
                final t = (data['time'] as Timestamp?)?.toDate() ??
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();
                final uid = (data['user'] as String?) ??
                    (data['uid'] as String?) ??
                    'unknown';
                entries.add({
                  'source': 'appeal',
                  'time': t,
                  'data': data,
                  'id': a.id,
                  'userId': uid,
                });
                presentAppealIds.add(a.id);
              }
            }

            // Map standing reports into a uniform structure, but skip any
            // 'appeal_adjustment' reports that reference an appeal we already
            // have to avoid duplicate cards in the merged feed.
            for (final d in standingDocs) {
              final data = d.data();
              final t =
                  (data['time'] as Timestamp?)?.toDate() ?? DateTime.now();
              final appealRef = data['appealId'] as String?;
              if (appealRef != null && presentAppealIds.contains(appealRef)) {
                // this standing report is the follow-up for an appeal we
                // already include; skip to prevent duplicate appearance
                continue;
              }
              entries.add({
                'source': 'standing',
                'time': t,
                'data': data,
                'userId': d.reference.parent.parent?.id ?? 'unknown',
              });
            }

            // Filter and sort combined entries by time desc, then take up to 50
            entries.sort((l, r) =>
                (r['time'] as DateTime).compareTo(l['time'] as DateTime));
            final shown = entries.take(50).toList();

            if (shown.isEmpty) {
              return _EmptyState(
                icon: Icons.receipt_long,
                title: 'No moderator actions',
                message: 'Admin-issued notifications will appear here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = shown[index];
                final src = entry['source'] as String;
                final time = entry['time'] as DateTime;
                final data = Map<String, dynamic>.from(
                    entry['data'] as Map<String, dynamic>);
                final userId = entry['userId'] as String? ??
                    entry['id'] as String? ??
                    'unknown';

                if (src == 'standing') {
                  final type = (data['type'] as String?) ?? 'action';
                  final delta = (data['delta'] as num?)?.toInt();
                  final reason = (data['reason'] as String?) ?? '';

                  String category;
                  switch (type) {
                    case 'content_warning':
                      category = 'Warning Issued';
                      break;
                    case 'score_adjustment':
                      category = 'Score Adjustment';
                      break;
                    case 'admin_adjustment':
                      category = 'Manual Adjustment';
                      break;
                    case 'appeal_adjustment':
                      category = 'Appeal Approved';
                      break;
                    case 'appeal_decision':
                      category = 'Appeal Denied';
                      break;
                    default:
                      category = 'Admin Action';
                  }

                  final message = delta != null
                      ? 'Standing adjusted by ${delta > 0 ? "+" : ""}$delta'
                      : reason.isNotEmpty
                          ? reason
                          : 'Action recorded';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _CategoryChip(category: category)),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time, size: 14),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _fmt(time),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // If this standing entry contains decision metadata, show
                        // the decision footer immediately under the header and
                        // above the target label to avoid it being pushed to the
                        // bottom of the card.
                        (() {
                          final footerData = Map<String, dynamic>.from(data);
                          if (footerData['decisionAt'] == null &&
                              footerData['decidedAt'] != null) {
                            footerData['decisionAt'] = footerData['decidedAt'];
                          }
                          final hasDecision =
                              footerData.containsKey('status') ||
                                  footerData.containsKey('decisionAt') ||
                                  footerData.containsKey('decisionNote');
                          if (hasDecision) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DecisionFooter(data: footerData),
                                const SizedBox(height: 8),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        }()),
                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get(),
                          builder: (context, userSnap) {
                            String displayUser = userId;
                            if (userSnap.hasData &&
                                userSnap.data?.data() != null) {
                              final nick = (userSnap.data!.data()!['nickname']
                                      as String?)
                                  ?.trim();
                              if (nick != null && nick.isNotEmpty) {
                                displayUser = nick;
                              }
                            }
                            return Text(
                              'Target: $displayUser',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        if (message.isNotEmpty)
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              height: 1.35,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _Tag('type: $type'),
                            if (delta != null)
                              _Tag('delta: ${delta > 0 ? "+" : ""}$delta'),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                // Appeal entry rendering
                final appealId = entry['id'] as String? ?? 'unknown';
                final status = (data['status'] as String?) ?? 'pending';
                final summary = (data['description'] as String?) ??
                    (data['summary'] as String?) ??
                    '';
                final reviewType = (data['reviewType'] as String?) ?? '';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CategoryChip(
                                category:
                                    'Appeal${reviewType.isNotEmpty ? ': $reviewType' : ''}'),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time, size: 14),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _fmt(time),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Show decision footer (approved/denied) right after the
                      // appeal header so it's visible above the requester info.
                      (() {
                        final footerData = Map<String, dynamic>.from(data);
                        if (footerData['decisionAt'] == null &&
                            footerData['decidedAt'] != null) {
                          footerData['decisionAt'] = footerData['decidedAt'];
                        }
                        final hasDecision =
                            (footerData['status'] as String?) != null &&
                                    (footerData['status'] as String?) !=
                                        'pending' ||
                                footerData.containsKey('decisionAt') ||
                                footerData.containsKey('decisionNote');
                        if (hasDecision) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DecisionFooter(data: footerData),
                              const SizedBox(height: 8),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      }()),
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .get(),
                        builder: (context, userSnap) {
                          String displayUser = userId;
                          if (userSnap.hasData &&
                              userSnap.data?.data() != null) {
                            final nick =
                                (userSnap.data!.data()!['nickname'] as String?)
                                    ?.trim();
                            if (nick != null && nick.isNotEmpty) {
                              displayUser = nick;
                            }
                          }
                          return Text(
                            'Requester: $displayUser',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      if (summary.isNotEmpty)
                        Text(
                          summary,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              height: 1.35),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: status == 'pending'
                                ? () => _updateAppealStatus(appealId, true)
                                : null,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: status == 'pending'
                                ? () => _updateAppealStatus(appealId, false)
                                : null,
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AppealsTab extends StatefulWidget {
  const _AppealsTab();

  @override
  State<_AppealsTab> createState() => _AppealsTabState();
}

class _AppealsTabState extends State<_AppealsTab> {
  final Set<String> _expanded = <String>{};
  String _appealsFilter = 'pending'; // 'pending' | 'completed'

  @override
  Widget build(BuildContext context) {
    final base = FirebaseFirestore.instance
        .collection('admin_review_requests')
        .orderBy('time', descending: true)
        .limit(100);

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: base.snapshots(),
            builder: (context, countSnapshot) {
              final docs = countSnapshot.data?.docs ?? [];
              final pendingCount = docs
                  .where((d) =>
                      (d.data()['status'] as String? ?? 'pending') == 'pending')
                  .length;
              final completedCount = docs
                  .where((d) =>
                      (d.data()['status'] as String? ?? 'pending') != 'pending')
                  .length;

              return Container(
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildFilterPill(
                        'pending', 'Pending', pendingCount, Icons.schedule),
                    _buildFilterPill('completed', 'Completed', completedCount,
                        Icons.check_circle_outline),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: base.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No appeals',
                  message: 'No review requests found.',
                );
              }

              final filtered = docs.where((d) {
                final status = (d.data()['status'] as String?) ?? 'pending';
                return _appealsFilter == 'pending'
                    ? status == 'pending'
                    : status != 'pending';
              }).toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: Icons.inbox_outlined,
                  title: _appealsFilter == 'pending'
                      ? 'No pending appeals'
                      : 'No completed appeals',
                  message: _appealsFilter == 'pending'
                      ? 'Nothing awaiting review.'
                      : 'No decisions recorded yet.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildAppealCard(context, filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(
      String value, String label, int count, IconData icon) {
    final active = _appealsFilter == value;
    final activeColor =
        value == 'pending' ? const Color(0xFFFF9800) : const Color(0xFF4CAF50);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!active) {
            setState(() => _appealsFilter = value);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: active ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  size: 18,
                  color: active ? activeColor : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? Colors.black87 : Colors.grey.shade600,
                  letterSpacing: 0.2,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: active ? activeColor : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppealCard(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final user = d['user'] as String? ?? 'unknown';
    final type = d['reviewType'] as String? ?? 'unknown';
    final desc = d['description'] as String? ?? '';
    final status = d['status'] as String? ?? 'pending';
    final score = (d['score'] as num?)?.toInt();
    final time = d['time'] as Timestamp?;
    final isExpanded = _expanded.contains(doc.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user)
                      .get(),
                  builder: (context, snap) {
                    String display = user;
                    if (snap.hasData && snap.data?.data() != null) {
                      final nick =
                          (snap.data!.data()!['nickname'] as String?)?.trim();
                      if (nick != null && nick.isNotEmpty) {
                        display = nick;
                      }
                    }
                    return Text(
                      'User: $display',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
              if (time != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _fmt(time.toDate()),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _labelForType(type),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (score != null) _Tag('standing: $score/100'),
              _Tag('type: $type'),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            _KeyValueLine('Reason:', desc),
          ],
          const SizedBox(height: 12),
          if (status == 'pending' && !isExpanded)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _expanded.add(doc.id);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Review Appeal',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (status == 'pending' && isExpanded)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok =
                              await _decide(context, doc, true, note: '');
                          if (ok) {
                            await _adjustAfterApproval(context, doc);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _decide(context, doc, false, note: ''),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _expanded.remove(doc.id);
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          if (status != 'pending') ...[
            const SizedBox(height: 6),
            _DecisionFooter(data: d),
          ],
        ],
      ),
    );
  }

  Future<bool> _decide(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc, bool approve,
      {required String note}) async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      // Ensure a human-readable incrementing admin label like [ADMIN_01]
      final adminLabel = await _ensureAdminLabel(adminUid);
      final Map<String, dynamic> updates = {
        'status': approve ? 'approved' : 'denied',
        'decisionAt': FieldValue.serverTimestamp(),
        'decidedBy': adminUid,
        'decidedByLabel': adminLabel,
      };
      if (note.isNotEmpty) {
        updates['decisionNote'] = note;
      }
      await doc.reference.update(updates);

      // Notify the user via their warnings subcollection
      final data = doc.data();
      final userId = data['user'] as String?;
      if (userId != null && userId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('warnings')
            .add({
          'createdAt': FieldValue.serverTimestamp(),
          'adminUid': adminUid,
          'type': 'appeal_decision',
          'category': 'Appeal Decision',
          'message': approve
              ? 'Your appeal was approved.'
              : "Your appeal was denied.${note.isNotEmpty ? ' Reason: $note' : ''}",
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Appeal approved' : 'Appeal denied')),
      );
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating: $e')),
      );
      return false;
    }
  }

  // Assign or retrieve an incrementing admin label stored in /admins/{uid} with a
  // counter in /admins_meta/registry.nextIndex. Returns something like [ADMIN_01].
  Future<String?> _ensureAdminLabel(String? uid) async {
    if (uid == null) return null;
    final adminRef = FirebaseFirestore.instance.collection('admins').doc(uid);
    final existing = await adminRef.get();
    if (existing.exists) {
      return existing.data()?['label'] as String?;
    }
    final metaRef =
        FirebaseFirestore.instance.collection('admins_meta').doc('registry');
    return FirebaseFirestore.instance.runTransaction((tx) async {
      final checkSnap = await tx.get(adminRef);
      if (checkSnap.exists) {
        return checkSnap.data()?['label'] as String?;
      }
      final metaSnap = await tx.get(metaRef);
      int nextIndex = (metaSnap.data()?['nextIndex'] as int?) ?? 1;
      final label = '[ADMIN_${nextIndex.toString().padLeft(2, '0')}]';
      tx.set(adminRef, {
        'label': label,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(metaRef, {'nextIndex': nextIndex + 1}, SetOptions(merge: true));
      return label;
    });
  }

  Future<void> _adjustAfterApproval(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final userId = data['user'] as String?;
    if (userId == null || userId.isEmpty) return;

    int? delta;
    final currentSnap =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final currentStanding =
        (currentSnap.data()?['standing'] as num?)?.toInt() ?? 100;

    final controller = TextEditingController();
    final approve = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Standing (Optional)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current standing: $currentStanding'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Delta (e.g. +5 or -10)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Leave blank to skip adjustment.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Skip')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply')),
        ],
      ),
    );

    if (approve != true) {
      return; // skipped
    }
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      return; // no change
    }
    delta = int.tryParse(raw);
    if (delta == null || delta == 0) {
      return; // invalid or neutral
    }

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final current =
            (snap.data()?['standing'] as num?)?.toInt() ?? currentStanding;
        final int d = delta!; // safe: null/zero filtered above
        final newStanding = (current + d).clamp(0, 100);
        tx.set(userRef, {'standing': newStanding}, SetOptions(merge: true));
        tx.set(userRef.collection('standing_reports').doc(), {
          'type': 'appeal_adjustment',
          'delta': d,
          'time': FieldValue.serverTimestamp(),
          'appealId': doc.id,
          'reason': 'Adjustment after appeal approval',
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Standing adjusted by $delta')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adjustment failed: $e')),
      );
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'standing_score':
        return 'Community Standing Score';
      case 'content_warning':
        return 'Content Warning';
      case 'account_restriction':
        return 'Account Restriction';
      case 'false_report':
        return 'False Report';
      default:
        return type;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Colors.black54),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionFooter extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DecisionFooter({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] as String?) ?? 'pending';
    final note = data['decisionNote'] as String?;
    final icon = status == 'approved' ? Icons.check_circle : Icons.cancel;
    final color =
        status == 'approved' ? Colors.green.shade700 : Colors.red.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Decision: ${status.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    // decision timestamp removed: the header already shows
                    // the action time and including another date here was
                    // duplicative in the UI.
                  ],
                ),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Note: $note',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final String selected; // 'logs' | 'appeals'
  final ValueChanged<String> onChanged;
  const _SegmentedTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            _SegItem(
              text: 'Moderation Logs',
              active: selected == 'logs',
              onTap: () => onChanged('logs'),
            ),
            _SegItem(
              text: 'Appeals',
              active: selected == 'appeals',
              onTap: () => onChanged('appeals'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _SegItem(
      {required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFD54F) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final colors = _catColors(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        softWrap: true,
        maxLines: 2,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.text,
        ),
      ),
    );
  }
}

class _CatColors {
  final Color background;
  final Color text;
  const _CatColors(this.background, this.text);
}

_CatColors _catColors(String category) {
  switch (category.toLowerCase()) {
    case 'misuse':
      return _CatColors(const Color(0xFFEDE7F6), const Color(0xFF4A148C));
    case 'spam':
      return _CatColors(const Color(0xFFFFF3E0), const Color(0xFFE65100));
    case 'harassment':
      return _CatColors(const Color(0xFFFFEBEE), const Color(0xFFB71C1C));
    default:
      return _CatColors(Colors.blue.shade100, Colors.blue.shade900);
  }
}

class _KeyValueLine extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValueLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade800,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey.shade200,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }
}

// Status pill removed from headers to avoid duplication with the
// decision footer. The footer (rendered by `_DecisionFooter`) now
// communicates approved/denied status and timestamp beneath the header.

String _fmt(DateTime d) {
  final months = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final m = months[d.month - 1];
  final dd = d.day.toString().padLeft(2, '0');
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '$m $dd, ${d.year} $h:$mm$ap';
}
