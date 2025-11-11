// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../router/app_router.dart';

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
          style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ) ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
            tooltip: 'Delete all reports',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: () => _deleteAllReports(context),
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _checkIsAdmin(),
        builder: (context, adminSnap) {
          if (adminSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!adminSnap.hasData || adminSnap.data != true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Not authorized.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRouter.adminLogin),
                      child: const Text('Admin Login'),
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                  final reported =
                      (data['reportedUserId'] as String?) ?? 'unknown';
                  final reportedNickname =
                      (data['reportedNickname'] as String?)?.trim();
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
                      targetNickname: (reportedNickname != null &&
                              reportedNickname.isNotEmpty)
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
          );
        },
      ),
    );
  }

  Future<bool> _checkIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final t = await user.getIdTokenResult(true);
      return (t.claims ?? const {})['admin'] == true;
    } catch (_) {
      return false;
    }
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

  /// Fetches user display info: nickname, or email, or falls back to UID
  Future<String> _getUserDisplayInfo() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          // Try nickname first
          final nickname = (data['nickname'] as String?)?.trim();
          if (nickname != null && nickname.isNotEmpty) {
            return nickname;
          }

          // Try email second
          final email = (data['email'] as String?)?.trim();
          if (email != null && email.isNotEmpty) {
            return email;
          }
        }
      }

      // Fallback to UID
      return widget.targetId;
    } catch (e) {
      return widget.targetId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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

    // For adjust_score and suspend, show confirmation dialogs
    if (action == 'adjust_score') {
      if (!mounted) return;
      final result = await _showAdjustScoreDialog(context);
      if (result == null || !mounted) return;
      await _executeAdjustScore(result, status);
      return;
    }

    if (action == 'suspend') {
      if (!mounted) return;
      final days = await _showSuspendDialog(context);
      if (days == null || !mounted) return;
      await _executeSuspend(days, status);
      return;
    }

    // For warn and dismiss, execute directly
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final db = FirebaseFirestore.instance;

      // Execute action-specific logic
      if (action == 'warn') {
        // Use transaction to ensure user document exists
        await db.runTransaction((transaction) async {
          final userRef = db.collection('users').doc(widget.targetId);
          final userDoc = await transaction.get(userRef);

          // Ensure user document exists
          if (!userDoc.exists) {
            throw Exception('User document not found');
          }

          // Get current warning count
          final currentWarnings =
              (userDoc.data()?['warningCount'] as num?)?.toInt() ?? 0;

          // Update user with new warning count
          transaction.set(
            userRef,
            {
              'warningCount': currentWarnings + 1,
              'lastWarningAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          // Add abstracted warning notification to subcollection
          // Only include user-appropriate information, not reporter details
          final warningRef = userRef.collection('warnings').doc();
          transaction.set(warningRef, {
            'category': _getWarningCategory(widget.tag),
            'message': _getAbstractedWarningMessage(widget.tag),
            'createdAt': FieldValue.serverTimestamp(),
            // Admin tracking fields (not shown to user)
            'reportId': widget.docId,
            'issuedBy': FirebaseAuth.instance.currentUser?.uid,
          });

          // Update report status
          transaction.set(
            db.collection('reports').doc(widget.docId),
            {
              'status': status,
              'action': action,
              'reviewedAt': FieldValue.serverTimestamp(),
              'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
            },
            SetOptions(merge: true),
          );
        });
      } else if (action == 'dismiss') {
        // For dismiss, simply delete the report without affecting the user
        await db.collection('reports').doc(widget.docId).delete();
      }

      if (!mounted) return;
      final message = action == 'dismiss'
          ? 'Report dismissed'
          : 'Action "$action" completed successfully';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      setState(() => _expanded = false);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<int?> _showAdjustScoreDialog(BuildContext context) async {
    final controller = TextEditingController();

    // Fetch user info for display
    final userInfo = await _getUserDisplayInfo();

    if (!mounted) return null;

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Standing Score'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Target: $userInfo',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(
                  labelText: 'Score adjustment',
                  helperText: 'Enter a negative number to decrease (e.g., -10)',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, value);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAdjustScore(
    int adjustment,
    String status,
  ) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = FirebaseFirestore.instance;

      await db.runTransaction((transaction) async {
        final userRef = db.collection('users').doc(widget.targetId);
        final userDoc = await transaction.get(userRef);

        // Get current standing or default to 100
        final currentStanding =
            (userDoc.data()?['standing'] as num?)?.toInt() ?? 100;
        final newStanding = (currentStanding + adjustment).clamp(0, 100);

        // Update user standing
        transaction.set(
          userRef,
          {
            'standing': newStanding,
          },
          SetOptions(merge: true),
        );

        // Create standing report entry
        transaction.set(
          userRef.collection('standing_reports').doc(),
          {
            'type': 'admin_adjustment',
            'delta': adjustment,
            'reason': 'Admin adjustment from report ${widget.docId}',
            'reportReason': widget.tag,
            'details': widget.details,
            'createdAt': FieldValue.serverTimestamp(),
            'adjustedBy': FirebaseAuth.instance.currentUser?.uid,
          },
        );

        // Update report
        transaction.set(
          db.collection('reports').doc(widget.docId),
          {
            'status': status,
            'action': 'adjust_score',
            'adjustment': adjustment,
            'reviewedAt': FieldValue.serverTimestamp(),
            'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Standing adjusted by $adjustment successfully'),
        ),
      );
      setState(() => _expanded = false);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<int?> _showSuspendDialog(BuildContext context) async {
    int selectedDays = 7;

    // Fetch user info for display
    final userInfo = await _getUserDisplayInfo();

    if (!mounted) return null;

    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Suspend User'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 20, color: Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userInfo,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select suspension duration:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _SuspensionOption(
                  title: '1 Day',
                  subtitle: 'Temporary suspension',
                  value: 1,
                  groupValue: selectedDays,
                  onChanged: (val) => setDialogState(() => selectedDays = val),
                ),
                _SuspensionOption(
                  title: '7 Days',
                  subtitle: 'One week suspension',
                  value: 7,
                  groupValue: selectedDays,
                  onChanged: (val) => setDialogState(() => selectedDays = val),
                ),
                _SuspensionOption(
                  title: '30 Days',
                  subtitle: 'One month suspension',
                  value: 30,
                  groupValue: selectedDays,
                  onChanged: (val) => setDialogState(() => selectedDays = val),
                ),
                _SuspensionOption(
                  title: 'Permanent',
                  subtitle: 'Account permanently suspended',
                  value: -1,
                  groupValue: selectedDays,
                  onChanged: (val) => setDialogState(() => selectedDays = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, selectedDays),
              child: const Text('Suspend'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeSuspend(
    int days,
    String status,
  ) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Calculate suspension end date (null for permanent)
      final DateTime? suspendedUntil =
          days > 0 ? DateTime.now().add(Duration(days: days)) : null;

      // Update user with suspension
      batch.set(
        db.collection('users').doc(widget.targetId),
        {
          'suspended': true,
          'suspendedAt': FieldValue.serverTimestamp(),
          'suspendedUntil': suspendedUntil,
          'suspensionReason': widget.tag,
          'suspendedBy': FirebaseAuth.instance.currentUser?.uid,
        },
        SetOptions(merge: true),
      );

      // Create suspension record in subcollection
      batch.set(
        db
            .collection('users')
            .doc(widget.targetId)
            .collection('suspensions')
            .doc(),
        {
          'reportId': widget.docId,
          'reason': widget.tag,
          'details': widget.details,
          'duration': days > 0 ? '$days days' : 'permanent',
          'suspendedAt': FieldValue.serverTimestamp(),
          'suspendedUntil': suspendedUntil,
          'issuedBy': FirebaseAuth.instance.currentUser?.uid,
        },
      );

      // Update report
      batch.set(
        db.collection('reports').doc(widget.docId),
        {
          'status': status,
          'action': 'suspend',
          'suspensionDays': days,
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;
      final durationText = days > 0 ? '$days days' : 'permanently';
      messenger.showSnackBar(
        SnackBar(content: Text('User suspended for $durationText')),
      );
      setState(() => _expanded = false);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Helper methods to generate abstracted warning messages
  String _getWarningCategory(String reportReason) {
    // Map report reasons to user-friendly categories
    switch (reportReason.toLowerCase()) {
      case 'harassment':
      case 'bullying':
        return 'Respectful Behavior';
      case 'inappropriate content':
      case 'spam':
        return 'Content Guidelines';
      case 'hate speech':
      case 'discrimination':
        return 'Community Safety';
      case 'impersonation':
      case 'fraud':
        return 'Authenticity';
      default:
        return 'Community Guidelines';
    }
  }

  String _getAbstractedWarningMessage(String reportReason) {
    // Generate abstracted, user-appropriate warning messages
    // These do NOT include reporter details or specific report content
    switch (reportReason.toLowerCase()) {
      case 'harassment':
        return 'Your recent activity was flagged for potentially harassing behavior. Please review our Community Guidelines and ensure all interactions remain respectful.';
      case 'bullying':
        return 'We received concerns about behavior that may be considered bullying. Remember to treat all community members with kindness and respect.';
      case 'inappropriate content':
        return 'Some of your content was flagged as inappropriate. Please ensure all shared content follows our community standards.';
      case 'spam':
        return 'Your activity was flagged for spam-like behavior. Please avoid repetitive or unsolicited messages.';
      case 'hate speech':
        return 'Your content was flagged for violating our policies on hate speech. All community members must be treated with dignity and respect.';
      case 'discrimination':
        return 'We received reports of discriminatory behavior. Our community values inclusivity and equal treatment for everyone.';
      case 'impersonation':
        return 'There were concerns about authenticity in your profile or activity. Please ensure your account accurately represents you.';
      case 'fraud':
        return 'Your activity was flagged for potentially fraudulent behavior. Please review our terms of service regarding authentic engagement.';
      default:
        return 'Your recent activity was flagged for violating our Community Guidelines. Please review the guidelines to ensure future compliance.';
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
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

// Backfill function removed from UI; kept as script in /scripts for admin use.

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
  final messenger = ScaffoldMessenger.of(context);
  // Ask user to type DELETE to confirm destructive action
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Delete all reports?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This will permanently remove all reports. To confirm, type "DELETE" in the field below.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE to confirm',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  controller.text.trim().toUpperCase() == 'DELETE',
                ),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      ) ??
      false;
  if (!confirmed) return;
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
      // allow UI to update; ensure context still mounted for scaffold
      if (!context.mounted) break;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Deleted $deleted report(s).')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
  }
}

// Custom suspension option widget to avoid deprecated Radio widgets
class _SuspensionOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final int groupValue;
  final ValueChanged<int> onChanged;

  const _SuspensionOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final primaryBlue = const Color(0xFF003087);

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryBlue.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? primaryBlue : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                      color: isSelected ? primaryBlue : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? primaryBlue.withValues(alpha: 0.7)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
