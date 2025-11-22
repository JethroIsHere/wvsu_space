import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wvsu_space/features/gratitude_wall/models.dart';

class PostTile extends StatefulWidget {
  final GratitudePost post;
  const PostTile({super.key, required this.post});

  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile> {
  late int _likes;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.post.likes;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _liked = uid != null && (widget.post.likedBy ?? {}).containsKey(uid);
  }

  Future<void> _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to react')),
        );
      }
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection('gratitude_posts')
        .doc(widget.post.id);

    // optimistic UI
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });

    try {
      if (_liked) {
        // set likedBy.uid = true and increment
        await docRef
            .update({'likedBy.$uid': true, 'likes': FieldValue.increment(1)});
      } else {
        // remove likedBy.uid and decrement
        await docRef.update({
          'likedBy.$uid': FieldValue.delete(),
          'likes': FieldValue.increment(-1)
        });
      }
    } catch (e) {
      // revert on error
      setState(() {
        _liked = !_liked;
        _likes += _liked ? 1 : -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to react: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isMine = uid != null && uid == post.authorId;

    final base = Theme.of(context).colorScheme.primary;
    final bubbleColor = isMine
        ? base.withAlpha((0.12 * 255).round())
        : Theme.of(context).cardColor;
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final cross = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: cross,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.content, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(post.timestamp),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _toggleLike,
                    icon: Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked ? Colors.red : Colors.grey,
                      size: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    constraints: const BoxConstraints(),
                  ),
                  Text('$_likes',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp ts) {
    try {
      final dt = ts.toDate().toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  void didUpdateWidget(covariant PostTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the likes count changed externally (from Firestore), sync local state
    final newLikes = widget.post.likes;
    if (newLikes != _likes) {
      setState(() {
        _likes = newLikes;
      });
    }
  }
}
