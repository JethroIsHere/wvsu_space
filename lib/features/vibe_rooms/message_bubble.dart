// WVSU Space — `lib/features/vibe_rooms/message_bubble.dart`
// Small UI widget that renders a chat message bubble inside Vibe Rooms.
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final String author;
  final DateTime timestamp;
  final bool isOwn;
  final Color? backgroundColor;
  final Color? borderColor;

  const MessageBubble(
      {super.key,
      required this.text,
      required this.author,
      required this.timestamp,
      this.isOwn = false,
      this.backgroundColor,
      this.borderColor});

  @override
  Widget build(BuildContext context) {
    final align = isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = backgroundColor ?? (isOwn ? Colors.blue[100] : Colors.grey[200]);
    final borderCol = borderColor ?? Colors.transparent;
    final radius = isOwn
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12))
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12));

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(color: borderCol)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(author,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(text),
              const SizedBox(height: 6),
              Text(_formatTime(timestamp),
                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
