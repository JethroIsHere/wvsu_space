import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ChatLobbyScreen extends StatefulWidget {
  final String? initialMode; // 'random' or 'keyword'
  final bool lockMode; // when true, hide the toggle and force the mode

  const ChatLobbyScreen({super.key, this.initialMode, this.lockMode = false});

  @override
  State<ChatLobbyScreen> createState() => _ChatLobbyScreenState();
}

class _ChatLobbyScreenState extends State<ChatLobbyScreen> {
  String _mode = 'random'; // 'random' or 'keyword'
  final TextEditingController _keywordController = TextEditingController();

  // Predefined interests based on mockup
  final List<_Interest> _interests = [
    _Interest('Study Help', Icons.menu_book_outlined, Colors.amber),
    _Interest('Gaming', Icons.sports_esports_outlined, Colors.blue),
    _Interest('Music', Icons.music_note_outlined, Colors.green),
    _Interest('Programming', Icons.code_outlined, Colors.indigo),
    _Interest('Anime', Icons.auto_awesome_outlined, Colors.pinkAccent),
    _Interest('Fitness', Icons.fitness_center_outlined, Colors.teal),
    _Interest('Photography', Icons.photo_camera_outlined, Colors.deepOrange),
    _Interest('Coffee', Icons.coffee_outlined, Colors.brown),
    _Interest('Art & Design', Icons.palette_outlined, Colors.purple),
    _Interest('Math', Icons.calculate_outlined, Colors.lightGreen),
    _Interest('Food', Icons.restaurant_outlined, Colors.deepOrangeAccent),
    _Interest('Movies & TV', Icons.favorite_border, Colors.cyan),
  ];

  final Set<String> _selected = <String>{};
  bool _isMatching = false;
  DocumentReference<Map<String, dynamic>>? _myQueueRef;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _queueSub;

  @override
  void initState() {
    super.initState();
    // Initialize mode from incoming route preference if provided
    final preferred = widget.initialMode;
    if (preferred == 'random' || preferred == 'keyword') {
      _mode = preferred!;
    }
  }

  @override
  void dispose() {
    _cancelMatching(cleanup: true);
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: _mode == 'random'
            ? Text('Chat Lobby', style: textTheme.headlineMedium)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find your match', style: textTheme.headlineMedium),
                  Text(
                    'Select interests to find similar users',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode selector (hidden when locked)
              if (!widget.lockMode)
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'random',
                      label: Text('Random'),
                      icon: Icon(Icons.shuffle),
                    ),
                    ButtonSegment(
                      value: 'keyword',
                      label: Text('Keyword'),
                      icon: Icon(Icons.tag),
                    ),
                  ],
                  selected: {_mode},
                  multiSelectionEnabled: false,
                  emptySelectionAllowed: false,
                  onSelectionChanged: (selection) {
                    // Guard against empty selection to avoid exceptions
                    if (selection.isEmpty) return;
                    setState(() => _mode = selection.first);
                  },
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(
                      _mode == 'random'
                          ? 'Quick Chat (Random)'
                          : 'Interest Matching (Keyword)',
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Selected chips row (only for keyword mode)
              if (_mode == 'keyword' && _selected.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _selected
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InputChip(
                              label: Text(s),
                              onDeleted: () {
                                setState(() => _selected.remove(s));
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),

              const SizedBox(height: 8),

              // Content
              Expanded(
                child: _mode == 'random'
                    ? _buildRandomInfo(textTheme)
                    : _buildKeywordGrid(context),
              ),

              // Bottom sticky action
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (_mode == 'keyword' && _selected.isEmpty) ||
                              _isMatching
                          ? null
                          : _startMatching,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        textStyle: textTheme.labelLarge,
                        minimumSize: const Size(double.infinity, 50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _mode == 'keyword'
                            ? 'Find Match (${_selected.length} selected)'
                            : (_isMatching ? 'Searching…' : 'Start Chat'),
                      ),
                    ),
                  ),
                  if (_mode == 'random') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Report inappropriate behavior anytime',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(width: 6),
                        const Text('🎉', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRandomInfo(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble,
              color: colorScheme.primary,
              size: 56,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ready to chat?',
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 300,
            child: Text(
              'Tap Start Chat to find a chat partner. Your identity will remain completely anonymous.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordGrid(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = List<_Interest>.from(_interests);

    // Ensure "Add Custom" tile is last
    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Give tiles a little more vertical space to avoid overflow on long labels like "Programming"
        childAspectRatio: 1.05,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _AddCustomTile(onTap: _addCustomInterest);
        }
        final it = items[index];
        final selected = _selected.contains(it.label);
        return _InterestTile(
          label: it.label,
          icon: it.icon,
          selected: selected,
          onTap: () {
            setState(() {
              if (selected) {
                _selected.remove(it.label);
              } else {
                _selected.add(it.label);
              }
            });
          },
          colorScheme: colorScheme,
          iconColor: it.iconColor,
        );
      },
    );
  }

  Future<void> _startMatching() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to start chatting.')),
      );
      return;
    }

    setState(() => _isMatching = true);

    final db = FirebaseFirestore.instance;
    final queue = db.collection('matchQueue');
    final now = FieldValue.serverTimestamp();

    // Create or overwrite my waiting doc
    final myRef = queue.doc(uid);
    _myQueueRef = myRef;
    final keywords = _mode == 'keyword' ? _selected.toList() : <String>[];
    await myRef.set({
      'uid': uid,
      'mode': _mode,
      'keywords': keywords,
      'status': 'waiting',
      'createdAt': now,
    }, SetOptions(merge: true));

    // Try to find a partner quickly (best-effort client-side filter)
    Query<Map<String, dynamic>> q = queue
        .where('status', isEqualTo: 'waiting')
        .where('mode', isEqualTo: _mode);
    if (_mode == 'keyword' && keywords.isNotEmpty) {
      q = q.where('keywords', arrayContainsAny: keywords.take(10).toList());
    }
    final snap = await q.limit(10).get();
    QueryDocumentSnapshot<Map<String, dynamic>>? partnerDoc;
    for (final d in snap.docs) {
      if ((d.data()['uid'] as String) != uid) {
        partnerDoc = d;
        break;
      }
    }

    if (partnerDoc != null) {
      await _pairWith(uid, partnerDoc.reference);
      return;
    }

    // Otherwise, listen for my doc to be paired
    _queueSub?.cancel();
    _queueSub = myRef.snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;
      if (data['status'] == 'paired' && data['sessionId'] != null) {
        _navigateToSession(data['sessionId'] as String);
      }
    });

    // Show cancellable dialog
    if (!mounted) return;
    _showSearchingDialog();
  }

  Future<void> _pairWith(
    String uid,
    DocumentReference<Map<String, dynamic>> partnerRef,
  ) async {
    final db = FirebaseFirestore.instance;
    final sessionRef = db.collection('sessions').doc();
    final batch = db.batch();
    batch.set(sessionRef, {
      'participants': [uid, (await partnerRef.get()).data()!['uid']],
      'mode': _mode,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (_myQueueRef != null) {
      batch.update(_myQueueRef!, {
        'status': 'paired',
        'sessionId': sessionRef.id,
        'partner': (await partnerRef.get()).data()!['uid'],
      });
    }
    batch.update(partnerRef, {
      'status': 'paired',
      'sessionId': sessionRef.id,
      'partner': uid,
    });
    await batch.commit();
    _navigateToSession(sessionRef.id);
  }

  void _navigateToSession(String sessionId) {
    _queueSub?.cancel();
    _queueSub = null;
    _isMatching = false;
    if (!mounted) return;
    Navigator.popUntil(
      context,
      (route) => route.isFirst || route.settings.name == AppRouter.lobby,
    );
    Navigator.pushReplacementNamed(
      context,
      AppRouter.chatSession,
      arguments: {
        'mode': _mode,
        'sessionId': sessionId,
        'keywords': _selected.toList(),
      },
    );
  }

  Future<void> _cancelMatching({bool cleanup = false}) async {
    if (!_isMatching && !cleanup) return;
    _queueSub?.cancel();
    _queueSub = null;
    final ref = _myQueueRef;
    _myQueueRef = null;
    if (ref != null) {
      try {
        await ref.delete();
      } catch (_) {}
    }
    // Avoid setState during dispose/cleanup; only update UI when not cleaning up.
    if (!cleanup && mounted) {
      setState(() => _isMatching = false);
    } else {
      _isMatching = false;
    }
  }

  void _showSearchingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(child: const Text('Searching for a partner...')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _cancelMatching();
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addCustomInterest() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Interest'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Type your interest'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      setState(() {
        // Insert custom at the front for visibility if not already present
        if (_interests.indexWhere((i) => i.label == result) == -1) {
          _interests.insert(0, _Interest(result, Icons.add, Colors.black87));
        }
        _selected.add(result);
      });
    }
  }
}

class _Interest {
  final String label;
  final IconData icon;
  final Color iconColor;
  const _Interest(this.label, this.icon, this.iconColor);
}

class _InterestTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final Color iconColor;

  const _InterestTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? colorScheme.primary : Colors.white;
    final fg = selected ? colorScheme.onPrimary : Colors.black87;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colorScheme.primary : Colors.black12,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? fg : iconColor, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCustomTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCustomTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.add, color: Colors.black87),
              SizedBox(height: 8),
              Text(
                'Add Custom',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
