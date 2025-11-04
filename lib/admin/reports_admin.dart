import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportsAdminScreen extends StatelessWidget {
  const ReportsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(100);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports',
          style:
              theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ) ??
              const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Create test report',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => _createTestReport(context),
          ),
          IconButton(
            tooltip: 'Backfill nicknames',
            icon: const Icon(Icons.person_search_outlined),
            onPressed: () => _backfillNicknames(context),
          ),
          IconButton(
            tooltip: 'Delete all reports',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: () => _deleteAllReports(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading reports: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No reports yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final reason = (data['reason'] as String?) ?? '—';
              final details = (data['details'] as String?) ?? '';
              final reported = (data['reportedUserId'] as String?) ?? 'unknown';
              final reportedNickname = (data['reportedNickname'] as String?)
                  ?.trim();
              final ts = data['createdAt'];
              final when = ts is Timestamp ? ts.toDate() : null;
              final status = (data['status'] as String?) ?? 'open';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ReportCard(
                  docId: doc.id,
                  tag: reason,
                  tagColor: _tagColorFor(reason),
                  targetId: reported,
                  targetNickname:
                      (reportedNickname != null && reportedNickname.isNotEmpty)
                      ? reportedNickname
                      : null,
                  details: details,
                  timestamp: when,
                  status: status,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============== New UI widgets to match mockups ==============

class _ReportCard extends StatefulWidget {
  final String docId;
  final String tag;
  final Color tagColor;
  final String targetId;
  final String? targetNickname;
  final String details;
  final DateTime? timestamp;
  final String status;

  const _ReportCard({
    required this.docId,
    required this.tag,
    required this.tagColor,
    required this.targetId,
    this.targetNickname,
    required this.details,
    required this.timestamp,
    required this.status,
  });

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _expanded = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TagChip(text: widget.tag, color: widget.tagColor),
                const Spacer(),
                const Icon(Icons.access_time, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  widget.timestamp != null ? _fmtDate(widget.timestamp!) : '—',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if ((widget.targetNickname ?? '').isNotEmpty)
              Text(
                'Target: ${widget.targetNickname}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              )
            else
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.targetId)
                    .get(),
                builder: (context, snap) {
                  String display = widget.targetId;
                  if (snap.hasData && snap.data?.data() != null) {
                    final data = snap.data!.data()!;
                    display =
                        (data['nickname'] as String?)?.trim().isNotEmpty == true
                        ? (data['nickname'] as String)
                        : widget.targetId;
                  }
                  return Text(
                    'Target: $display',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  );
                },
              ),
            if (widget.details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '"${widget.details}"',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 14),
            if (!_expanded)
              SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0C3EA9), // navy
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => setState(() => _expanded = true),
                  child: const Text('Review & Take Action'),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          label: 'Warn User',
                          color: const Color(0xFFF9C84B), // yellow
                          textColor: Colors.black87,
                          onPressed: () =>
                              _applyAction(context, 'warn', 'reviewed'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionBtn(
                          label: 'Adjust Score',
                          color: const Color(0xFF7B61FF), // purple
                          onPressed: () =>
                              _applyAction(context, 'adjust_score', 'actioned'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          label: 'Suspend',
                          color: const Color(0xFFFF4D4F), // red
                          onPressed: () =>
                              _applyAction(context, 'suspend', 'actioned'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionBtn(
                          label: 'Dismiss',
                          color: Colors.grey.shade400,
                          textColor: Colors.black87,
                          onPressed: () =>
                              _applyAction(context, 'dismiss', 'reviewed'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _expanded = false),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyAction(
    BuildContext context,
    String action,
    String status,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.docId)
          .set({
            'status': status,
            'action': action,
            'reviewedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      messenger.showSnackBar(SnackBar(content: Text('Action "$action" saved')));
      setState(() => _expanded = false);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final Color color;
  const _TagChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback onPressed;
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onPressed,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

Color _tagColorFor(String reason) {
  final r = reason.toLowerCase();
  if (r.contains('harass')) return const Color(0xFFFF4D4F);
  if (r.contains('spam')) return const Color(0xFFF5A623);
  if (r.contains('abuse')) return const Color(0xFFE53935);
  return Colors.grey;
}

String _fmtDate(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

// Admin-only: backfill missing reporterNickname/reportedNickname on recent reports
Future<void> _backfillNicknames(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final db = FirebaseFirestore.instance;
  messenger.showSnackBar(const SnackBar(content: Text('Backfill started…')));

  try {
    final snap = await db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();

    final Map<String, String?> cache = {};
    int updates = 0;
    WriteBatch? batch;
    int inBatch = 0;

    Future<String?> nicknameFor(String uid) async {
      if (cache.containsKey(uid)) return cache[uid];
      try {
        final u = await db.collection('users').doc(uid).get();
        final nick = (u.data()?['nickname'] as String?)?.trim();
        cache[uid] = (nick != null && nick.isNotEmpty) ? nick : null;
      } catch (_) {
        cache[uid] = null;
      }
      return cache[uid];
    }

    Future<void> commitIfNeeded() async {
      if (batch != null && inBatch > 0) {
        await batch!.commit();
        batch = null;
        inBatch = 0;
      }
    }

    for (final doc in snap.docs) {
      final data = doc.data();
      final reporterId = data['reporterId'] as String?;
      final reportedId = data['reportedUserId'] as String?;
      String? reporterNickname = (data['reporterNickname'] as String?)?.trim();
      String? reportedNickname = (data['reportedNickname'] as String?)?.trim();

      bool needsUpdate = false;
      final updateData = <String, dynamic>{};

      if ((reporterNickname == null || reporterNickname.isEmpty) &&
          reporterId != null) {
        final n = await nicknameFor(reporterId);
        if (n != null) {
          updateData['reporterNickname'] = n;
          needsUpdate = true;
        }
      }
      if ((reportedNickname == null || reportedNickname.isEmpty) &&
          reportedId != null) {
        final n = await nicknameFor(reportedId);
        if (n != null) {
          updateData['reportedNickname'] = n;
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        batch ??= db.batch();
        batch!.set(doc.reference, updateData, SetOptions(merge: true));
        inBatch++;
        updates++;
        if (inBatch >= 400) {
          await commitIfNeeded();
        }
      }
    }

    await commitIfNeeded();
    messenger.showSnackBar(
      SnackBar(content: Text('Backfill complete. Updated $updates report(s).')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Backfill failed: $e')));
  }
}

// Admin-only: create a simple test report using current user as both reporter and target
Future<void> _createTestReport(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Not signed in')));
    return;
  }
  try {
    final db = FirebaseFirestore.instance;
    final userDoc = await db.collection('users').doc(user.uid).get();
    final nick = (userDoc.data()?['nickname'] as String?)?.trim();

    await db.collection('reports').add({
      'sessionId': 'TEST',
      'reporterId': user.uid,
      'reportedUserId': user.uid,
      if (nick != null && nick.isNotEmpty) 'reporterNickname': nick,
      if (nick != null && nick.isNotEmpty) 'reportedNickname': nick,
      'mode': 'test',
      'reason': 'Test',
      'details': 'Test report created ${DateTime.now().toIso8601String()}',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Test report created')),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to create test: $e')),
    );
  }
}

// Admin-only: delete all reports in batches
Future<void> _deleteAllReports(BuildContext context) async {
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete all reports?'),
          content: const Text('This will permanently remove all reports.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed) return;

  final messenger = ScaffoldMessenger.of(context);
  final db = FirebaseFirestore.instance;
  int deleted = 0;
  try {
    while (true) {
      final snap = await db.collection('reports').limit(500).get();
      if (snap.docs.isEmpty) break;
      final batch = db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
      // Give UI a chance to breathe if very large
      await Future.delayed(const Duration(milliseconds: 50));
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Deleted $deleted report(s).')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
  }
}
