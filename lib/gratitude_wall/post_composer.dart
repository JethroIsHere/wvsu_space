import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_button.dart';

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are not signed in.')),
          );
        }
        return;
      }
      final uid = user.uid;
      debugPrint('Posting as uid=$uid');
      final now = DateTime.now().toUtc();
      // express posts expire after 30 minutes
      final expires = _type == 'express'
          ? Timestamp.fromDate(now.add(const Duration(minutes: 30)))
          : null;
      final doc =
          FirebaseFirestore.instance.collection('gratitude_posts').doc();
      final map = <String, dynamic>{
        'type': _type,
        'content': text,
        'authorId': uid,
        'isAnonymous': _type == 'express',
        'timestamp': Timestamp.fromDate(now),
        'likes': 0,
      };
      if (expires != null) map['expiresAt'] = expires;
      debugPrint('Writing gratitude_posts doc with data: $map');
      await doc.set(map);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Failed to post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: ${e.toString()}')),
        );
      }
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Make the chips horizontally scrollable to avoid overflow on
                // small/mobile screens while keeping the close button pinned.
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Gratitude'),
                          selected: _type == 'gratitude',
                          onSelected: (v) =>
                              setState(() => _type = 'gratitude'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Express'),
                          selected: _type == 'express',
                          onSelected: (v) => setState(() => _type = 'express'),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
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
            AppButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Post'),
            )
          ],
        ),
      ),
    );
  }
}
