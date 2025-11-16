import 'package:flutter/material.dart';
import 'models.dart';
import 'styles.dart';

class RoomCard extends StatelessWidget {
  final VibeRoom room;
  final VoidCallback? onJoin;

  const RoomCard({super.key, required this.room, this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(room.title.isNotEmpty ? room.title[0] : '?',
              style: const TextStyle(fontSize: 20)),
        ),
        title: Text(room.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(room.description,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onJoin,
              icon: Icon(Icons.chat_bubble_outline, color: AppColors.primary),
            ),
            Text('${room.participantCount} active',
                style: const TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
