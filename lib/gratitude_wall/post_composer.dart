import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostComposer extends StatefulWidget {
  const PostComposer({super.key});

  @override
  State<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<PostComposer> {
  String _type = 'gratitude';
  final TextEditingController _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      String? nickname;
      try {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = userDoc.data();
        nickname = data?['nickname'] as String?;
      } catch (_) {
        nickname = null;
      }
      final now = DateTime.now().toUtc();
      final expires = _type == 'express'
          ? Timestamp.fromDate(now.add(const Duration(minutes: 10)))
          : null;
      final doc =
          FirebaseFirestore.instance.collection('gratitude_posts').doc();
      await doc.set({
        'type': _type,
        'content': text,
        'authorId': uid,
        'authorNickname': nickname,
        'isAnonymous': _type == 'express',
        'timestamp': Timestamp.fromDate(now),
        'expiresAt': expires,
        'likes': 0,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Failed to post: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).dialogTheme.backgroundColor ??
              Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Gratitude'),
                  selected: _type == 'gratitude',
                  onSelected: (v) => setState(() => _type = 'gratitude'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Express'),
                  selected: _type == 'express',
                  onSelected: (v) => setState(() => _type = 'express'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: _type == 'express'
                    ? 'Write anonymously…'
                    : 'Write a gratitude post…',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const CircularProgressIndicator()
                  : const Text('Post'),
            )
          ],
        ),
      ),
    );
  }
}
