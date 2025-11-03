import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class ChatSessionScreen extends StatefulWidget {
  const ChatSessionScreen({super.key});

  @override
  State<ChatSessionScreen> createState() => _ChatSessionScreenState();
}

class _ChatSessionScreenState extends State<ChatSessionScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  String? _sessionId;
  String _mode = 'random';
  List<String> _keywords = const [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sessionSub;
  bool _endAlertShown = false;

  @override
  void initState() {
    super.initState();
    // Args are not available in initState via ModalRoute, defer to addPostFrameCallback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      setState(() {
        _mode = (args?['mode'] as String?) ?? 'random';
        _sessionId = args?['sessionId'] as String?;
        final kw = args?['keywords'];
        if (kw is List) {
          _keywords = kw.whereType<String>().toList();
        }
      });
      _startSessionListener();
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = _sessionId;
    final isReady = sessionId != null && sessionId.isNotEmpty;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final ok = await _confirmEnd(context);
        if (ok) {
          await _endChat();
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final ok = await _confirmEnd(context);
              if (ok) {
                await _endChat();
                navigator.pop();
              }
            },
          ),
          title: const Text('You matched with a schoolmate!'),
          actions: [
            IconButton(
              tooltip: 'Report',
              icon: const Icon(Icons.flag_outlined),
              onPressed: _openReportDialog,
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'end') {
                  final navigator = Navigator.of(context);
                  final ok = await _confirmEnd(context);
                  if (ok) {
                    await _endChat();
                    navigator.pop();
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'end', child: Text('End chat')),
              ],
            ),
          ],
        ),
        body: isReady
            ? Column(
                children: [
                  if (_mode == 'keyword' && _keywords.isNotEmpty)
                    _MatchBanner(keywords: _keywords),
                  Expanded(
                    child: _MessagesList(
                      sessionId: sessionId,
                      scrollController: _scrollController,
                    ),
                  ),
                  const Divider(height: 1),
                  _Composer(
                    controller: _textController,
                    sending: _sending,
                    onSend: _sendMessage,
                  ),
                ],
              )
            : _notReadyPlaceholder(),
      ),
    );
  }

  Widget _notReadyPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, size: 40, color: Colors.black54),
            const SizedBox(height: 12),
            const Text('Preparing your chat session…'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  void _startSessionListener() {
    final id = _sessionId;
    if (id == null || id.isEmpty) return;
    _sessionSub?.cancel();
    _sessionSub = FirebaseFirestore.instance
        .collection('sessions')
        .doc(id)
        .snapshots()
        .listen((doc) async {
          final data = doc.data();
          if (data == null) return;
          final status = data['status'] as String?;
          final endedBy = data['endedBy'] as String?;
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          if (!_endAlertShown &&
              status == 'ended' &&
              endedBy != null &&
              endedBy != myUid) {
            _endAlertShown = true;
            if (!mounted) return;
            final navigator = Navigator.of(context);
            await showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Chat ended'),
                content: const Text('Your chat partner left the conversation.'),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            if (!mounted) return;
            navigator.pop();
          }
        });
  }

  Future<void> _endChat({String? reason}) async {
    final id = _sessionId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('sessions').doc(id).set({
        'status': 'ended',
        'endedBy': uid,
        'endedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'endedReason': reason,
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore failures; we still navigate out
    }
  }

  Future<void> _sendMessage() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send messages.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final db = FirebaseFirestore.instance;
      final messages = db
          .collection('sessions')
          .doc(sessionId)
          .collection('messages');
      await messages.add({
        'text': text,
        'senderId': uid,
        'ts': FieldValue.serverTimestamp(),
      });
      _textController.clear();
      // Scroll to bottom after a tiny delay to let the list rebuild
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _confirmEnd(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End chat?'),
            content: const Text('Are you sure you want to end this chat?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('End'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openReportDialog() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final reasons = <String>[
      'Harassment',
      'Spam',
      'Inappropriate Content',
      'Other',
    ];
    String? selected;
    final controller = TextEditingController();
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Report chat'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => selected = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Details (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Try to resolve the other participant for the report document
      String? reportedUid;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionId)
            .get();
        final data = doc.data();
        if (data != null && data['participants'] is List) {
          final parts = List.from(
            data['participants'] as List,
          ).whereType<String>().toList();
          if (parts.length == 2) {
            reportedUid = parts.firstWhere(
              (p) => p != uid,
              orElse: () => parts.first,
            );
          }
        }
      } catch (_) {
        // best-effort only
      }

      await FirebaseFirestore.instance.collection('reports').add({
        'sessionId': sessionId,
        'reporterId': uid,
        if (reportedUid != null) 'reportedUserId': reportedUid,
        'mode': _mode,
        'reason': selected,
        'details': controller.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // End the chat as part of reporting
      await _endChat(reason: 'reported');

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Report submitted. Chat ended.')),
      );
      // Pop back to previous screen
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e')),
      );
    }
  }
}

class _MessagesList extends StatelessWidget {
  final String sessionId;
  final ScrollController scrollController;
  const _MessagesList({
    required this.sessionId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final messages = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('ts');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: messages.snapshots(),
      builder: (context, snapshot) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.jumpTo(scrollController.position.maxScrollExtent);
          }
        });

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const _EmptyMessages();
        }
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final text = (data['text'] as String?) ?? '';
            final sender = data['senderId'] as String?;
            final isMine = sender != null && sender == uid;
            final ts = data['ts'];
            return _MessageBubble(
              text: text,
              isMine: isMine,
              timestamp: ts is Timestamp ? ts.toDate() : null,
            );
          },
        );
      },
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.chat_bubble_outline, size: 40, color: Colors.black45),
          SizedBox(height: 8),
          Text('Say hi to start the conversation'),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final canSend = value.text.trim().isNotEmpty && !sending;
                return IconButton.filled(
                  style: IconButton.styleFrom(shape: const CircleBorder()),
                  onPressed: canSend ? onSend : null,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final DateTime? timestamp;
  const _MessageBubble({
    required this.text,
    required this.isMine,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isMine ? theme.colorScheme.primary : Colors.grey.shade200;
    final fg = isMine ? theme.colorScheme.onPrimary : Colors.black87;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isMine ? 14 : 2),
      bottomRight: Radius.circular(isMine ? 2 : 14),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: radius),
            child: Text(text, style: TextStyle(color: fg)),
          ),
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _fmtTime(timestamp!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black45,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class _MatchBanner extends StatelessWidget {
  final List<String> keywords;
  const _MatchBanner({required this.keywords});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = 'Great match! You both like:';
    final topics =
        keywords.take(2).join(', ') + (keywords.length > 2 ? '…' : '');
    return Container(
      width: double.infinity,
      color: Colors.green.shade500,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  topics,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
