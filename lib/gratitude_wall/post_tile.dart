import 'package:flutter/material.dart';
// keep formatting minimal to avoid extra package dependency
import 'models.dart';

class PostTile extends StatelessWidget {
  final GratitudePost post;
  const PostTile({super.key, required this.post});

  String _timeAgo(DateTime dt) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    // simple month/day fallback
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final authorLabel =
        post.isAnonymous ? 'Anonymous' : (post.authorNickname ?? 'User');
    final content = post.content;
    final timestamp = post.timestamp.toDate().toLocal();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(authorLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(_timeAgo(timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            if (post.type == 'gratitude')
              Row(
                children: [
                  const Icon(Icons.favorite_border,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('${post.likes}',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
