import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:wvsu_space/router/app_router.dart';

/// A sequenced loading flow shown while pairing users into a chat session.
///
/// It performs the lightweight client-side matchmaking used elsewhere in the
/// app and visualizes three steps:
/// 1) Finding available users
/// 2) Matching interests
/// 3) Creating secure connection
class MatchingProgressScreen extends StatefulWidget {
  final String mode; // 'random' or 'keyword'
  final List<String> keywords;

  const MatchingProgressScreen({
    super.key,
    required this.mode,
    required this.keywords,
  });

  @override
  State<MatchingProgressScreen> createState() => _MatchingProgressScreenState();
}

class _MatchingProgressScreenState extends State<MatchingProgressScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0; // 0..2 visible, 3 = completed
  int _elapsedSeconds = 0;
  Timer? _timer;
  Timer? _stepTicker;

  // Matching state
  DocumentReference<Map<String, dynamic>>? _myQueueRef;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _queueSub;

  // Simple pulse animation for the header icon
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _startTimers();
    // Defer actual matchmaking start to ensure context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginMatching());
  }

  void _startTimers() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
    // Ticks through steps for UX even while waiting (doesn't mark complete).
    _stepTicker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (_currentStep < 2) setState(() => _currentStep++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stepTicker?.cancel();
    _queueSub?.cancel();
    _pulse.dispose();
    // Attempt to clean up the queue doc if still present
    final ref = _myQueueRef;
    _myQueueRef = null;
    if (ref != null) {
      // Fire and forget; ignore errors
      // ignore: discarded_futures
      ref.delete().catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _beginMatching() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start chatting.')),
      );
      Navigator.maybePop(context);
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final queue = db.collection('matchQueue');
      final now = FieldValue.serverTimestamp();

      // Step 0 -> create/enter queue
      _myQueueRef = queue.doc(uid);
      await _myQueueRef!.set({
        'uid': uid,
        'mode': widget.mode,
        'keywords': widget.keywords.take(10).toList(),
        'status': 'waiting',
        'createdAt': now,
      }, SetOptions(merge: true));
      if (mounted) setState(() => _currentStep = 1);

      // Ask Cloud Functions to atomically match (server-side pairing)
      try {
        // Call explicit region to avoid mismatch; our function is deployed in us-central1.
        final callable = FirebaseFunctions.instanceFor(
          region: 'us-central1',
        ).httpsCallable('matchUser');
        final res = await callable.call(<String, dynamic>{
          'mode': widget.mode,
          'keywords': widget.keywords.take(10).toList(),
        });
        final data = (res.data as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        if (data != null &&
            data['status'] == 'paired' &&
            data['sessionId'] != null) {
          if (mounted) setState(() => _currentStep = 2);
          await Future.delayed(const Duration(milliseconds: 400));
          _goToSession(data['sessionId'] as String);
          return;
        }
      } on FirebaseFunctionsException catch (fe) {
        debugPrint(
          'matchUser call failed: ${fe.code} ${fe.message} details=${fe.details}',
        );
        // If Functions are unavailable (Spark plan), try client-side pairing
        // so development can continue without billing. Do not show an
        // intrusive popup on failures; fall back silently and log instead.
        final didPairFallback = await _clientFindAndPair(uid);
        if (didPairFallback) return;
        debugPrint(
            'matchUser: falling back to client pairing (no popup shown)');
      } catch (e) {
        debugPrint('matchUser call error: $e');
        final didPairFallback = await _clientFindAndPair(uid);
        if (didPairFallback) return;
      }

      // If not immediately paired, listen for pairing on my own doc
      _queueSub?.cancel();
      _queueSub = _myQueueRef!.snapshots().listen((doc) async {
        final data = doc.data();
        if (data == null) return;
        if (data['status'] == 'paired' && data['sessionId'] != null) {
          if (mounted) setState(() => _currentStep = 2);
          // small UX delay to let the last step animate
          await Future.delayed(const Duration(milliseconds: 500));
          _goToSession(data['sessionId'] as String);
        }
      });
    } catch (e) {
      debugPrint('Failed to start matching: $e');
      // Avoid showing a blocking popup for matchmaking failures. Check
      // `mounted` before using the `BuildContext` because this method
      // performs async work earlier in the flow.
      if (!mounted) return;
      Navigator.maybePop(context);
    }
  }

  /// Attempt client-side pairing by querying the queue and updating both users
  /// in a single batch. This is a development fallback for projects without
  /// Cloud Functions billing. Requires permissive Firestore rules to allow
  /// peer updates with strict constraints.
  Future<bool> _clientFindAndPair(String uid) async {
    try {
      final db = FirebaseFirestore.instance;
      final queue = db.collection('matchQueue');
      Query<Map<String, dynamic>> q = queue
          .where('status', isEqualTo: 'waiting')
          .where('mode', isEqualTo: widget.mode);
      if (widget.mode == 'keyword' && widget.keywords.isNotEmpty) {
        q = q.where(
          'keywords',
          arrayContainsAny: widget.keywords.take(10).toList(),
        );
      }
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
      try {
        final snap = await q.limit(25).get();
        docs = snap.docs;
      } on FirebaseException catch (_) {
        // Fall back to simple query and filter in memory if index is missing
        final simple =
            await queue.where('status', isEqualTo: 'waiting').limit(25).get();
        final kw = widget.keywords.toSet();
        docs = simple.docs.where((d) {
          final data = d.data();
          if (data['mode'] != widget.mode) return false;
          if (widget.mode == 'keyword' && kw.isNotEmpty) {
            final theirs =
                (data['keywords'] as List?)?.map((e) => e.toString()).toSet() ??
                    {};
            if (!kw.any(theirs.contains)) return false;
          }
          return true;
        }).toList();
      }

      for (final d in docs) {
        final data = d.data();
        final partnerUid = data['uid'] as String?;
        if (partnerUid == null || partnerUid == uid) continue;

        // Create session and update both queue docs
        final sessionRef = db.collection('sessions').doc();
        final batch = db.batch();
        batch.set(sessionRef, {
          'participants': [uid, partnerUid],
          'mode': widget.mode,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final myRef = _myQueueRef ?? queue.doc(uid);
        batch.update(myRef, {
          'status': 'paired',
          'sessionId': sessionRef.id,
          'partner': partnerUid,
        });
        batch.update(d.reference, {
          'status': 'paired',
          'sessionId': sessionRef.id,
          'partner': uid,
        });
        await batch.commit();
        if (!mounted) return true;
        setState(() => _currentStep = 2);
        await Future.delayed(const Duration(milliseconds: 400));
        _goToSession(sessionRef.id);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Client pairing error: $e');
      return false;
    }
  }

  // Server-side matching will update our queue doc or return a sessionId.

  void _goToSession(String sessionId) {
    _queueSub?.cancel();
    _queueSub = null;
    final kw = widget.keywords;
    Navigator.pushReplacementNamed(
      context,
      AppRouter.chatSession,
      arguments: {'mode': widget.mode, 'sessionId': sessionId, 'keywords': kw},
    );
  }

  Future<void> _cancel() async {
    _queueSub?.cancel();
    _queueSub = null;
    final ref = _myQueueRef;
    _myQueueRef = null;
    if (ref != null) {
      try {
        await ref.delete();
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;
    final double scale = ((width / 375).clamp(0.9, 1.1)).toDouble();
    final interests = widget.mode == 'keyword' && widget.keywords.isNotEmpty
        ? widget.keywords
        : const <String>['Random'];

    final title = _currentStep == 0
        ? 'Finding available users..'
        : _currentStep == 1
            ? 'Matching interests'
            : 'Creating secure connection';

    final icon = _currentStep == 0
        ? Icons.groups_2_outlined
        : _currentStep == 1
            ? Icons.bolt_outlined
            : Icons.lock_outline;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        final navigator = Navigator.of(context);
        await _cancel();
        if (!didPop && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          toolbarHeight: 64,
          title: Text(
            'Finding match',
            style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: ((theme.textTheme.titleLarge?.fontSize ?? 20) + 2) *
                      scale,
                ) ??
                TextStyle(
                  fontSize: (20 + 2) * scale,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      _AnimatedCircleIcon(
                        icon: icon,
                        color: cs.primary,
                        scale: _scale,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize:
                                  ((theme.textTheme.headlineLarge?.fontSize ??
                                              28) +
                                          2) *
                                      scale,
                            ) ??
                            TextStyle(
                              fontSize: 30 * scale,
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Finding someone perfect for you',
                        style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize:
                                  (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                                      scale,
                            ) ??
                            TextStyle(fontSize: 14 * scale),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Matching based on your interests:',
                        style: theme.textTheme.bodySmall?.copyWith(
                              fontSize:
                                  (theme.textTheme.bodySmall?.fontSize ?? 12) *
                                      scale,
                            ) ??
                            TextStyle(fontSize: 12 * scale),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: interests
                            .take(2)
                            .map(
                              (k) => Chip(
                                label: Text(
                                  k,
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11 * scale,
                                  ),
                                ),
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.1),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      _StepTile(
                        index: 1,
                        label: 'Finding available users',
                        state: _tileState(0),
                        primary: cs.primary,
                        fontSize: 13 * scale,
                      ),
                      const SizedBox(height: 10),
                      _StepTile(
                        index: 2,
                        label: 'Matching interests',
                        state: _tileState(1),
                        primary: cs.primary,
                        fontSize: 13 * scale,
                      ),
                      const SizedBox(height: 10),
                      _StepTile(
                        index: 3,
                        label: 'Creating secure connection',
                        state: _tileState(2),
                        primary: cs.primary,
                        fontSize: 13 * scale,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Searching for ${_elapsedSeconds}s',
                        style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize:
                                  (theme.textTheme.bodyMedium?.fontSize ?? 14) *
                                      scale,
                            ) ??
                            TextStyle(fontSize: 14 * scale),
                      ),
                      const SizedBox(height: 18),
                      _TipCard(fontSize: 13 * scale),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _cancel,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor:
                                Colors.black.withValues(alpha: 0.06),
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _StepState _tileState(int stepIndex) {
    if (_currentStep > stepIndex) return _StepState.done;
    if (_currentStep == stepIndex) return _StepState.active;
    return _StepState.todo;
  }
}

class _AnimatedCircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Animation<double> scale;
  const _AnimatedCircleIcon({
    required this.icon,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scale,
      builder: (context, child) {
        return Transform.scale(
          scale: scale.value,
          child: Container(
            width: 152,
            height: 152,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 6,
                  ),
                ),
                child: Icon(icon, color: color, size: 40),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _StepState { todo, active, done }

class _StepTile extends StatelessWidget {
  final int index; // 1-based for display
  final String label;
  final _StepState state;
  final Color primary;
  final double? fontSize;
  const _StepTile({
    required this.index,
    required this.label,
    required this.state,
    required this.primary,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    Widget leading;
    if (state == _StepState.done) {
      leading = Icon(Icons.check_circle, color: Colors.green.shade500);
    } else if (state == _StepState.active) {
      leading = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    } else {
      leading = CircleAvatar(
        radius: 10,
        backgroundColor: Colors.grey.shade300,
        child: Text(
          '$index',
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      );
    }

    return Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: state == _StepState.active
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  final double? fontSize;
  const _TipCard({this.fontSize});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD), // soft yellow
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFF8A6D3B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: The more interests you select, the better we can match you!',
              style: TextStyle(
                color: const Color(0xFF8A6D3B),
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
