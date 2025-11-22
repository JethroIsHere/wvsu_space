import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:wvsu_space/features/vibe_rooms/vibe_rooms/models.dart';
import 'package:wvsu_space/features/vibe_rooms/vibe_rooms/styles.dart';
import 'package:wvsu_space/features/vibe_rooms/vibe_rooms/utils.dart';
import 'package:wvsu_space/widgets/app_button.dart';

class RoomCard extends StatelessWidget {
  final VibeRoom room;
  final VoidCallback? onJoin;

  const RoomCard({super.key, required this.room, this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _moodBackground(room.mood),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child:
              Text(_moodEmoji(room.mood), style: const TextStyle(fontSize: 22)),
        ),
        title: Text(room.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(room.description,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: LayoutBuilder(builder: (context, dialogConstraints) {
                final mq = MediaQuery.of(context);
                final screenWidth = mq.size.width;
                final screenHeight = mq.size.height;
                final maxWidth = math.min(640.0, screenWidth - 48.0);
                final dialogMaxHeight = math.min(640.0, screenHeight * 0.75);

                final moodObj = moods.firstWhere((m) => m.id == room.mood,
                    orElse: () => moods.first);

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: maxWidth, maxHeight: dialogMaxHeight),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).dialogTheme.backgroundColor ??
                                  Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Container(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 18, 16, 14),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _moodBackground(room.mood)),
                                    alignment: Alignment.center,
                                    child: Text(moodObj.emoji,
                                        style: const TextStyle(fontSize: 26)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(room.title,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20)),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                                color: const Color.fromRGBO(
                                                    255, 255, 255, 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: Text(moodObj.name,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ),
                                        ])
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.white),
                                      onPressed: () => Navigator.pop(context))
                                ],
                              ),
                            ),

                            // Body — description, constrained and scrollable (fixed height)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('About this room',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxHeight: dialogMaxHeight * 0.5),
                                    child: SingleChildScrollView(
                                      child: Text(
                                        room.description.isNotEmpty
                                            ? room.description
                                            : 'No description provided.',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    Icon(Icons.people,
                                        size: 16, color: Colors.green[700]),
                                    const SizedBox(width: 6),
                                    Text('${room.participantCount} active',
                                        style: const TextStyle(
                                            color: Colors.black54)),
                                    const SizedBox(width: 12),
                                    Text('· ${room.maxParticipants} max',
                                        style: const TextStyle(
                                            color: Colors.black54)),
                                  ])
                                ],
                              ),
                            ),

                            // Footer actions
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel')),
                                  const SizedBox(width: 8),
                                  AppButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      if (onJoin != null) onJoin!();
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.login,
                                            size: 18, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('Join Room'),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
        trailing: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${room.participantCount} active',
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _moodBackground(String moodId) {
    switch (moodId) {
      case 'chill':
        return const Color(0xFFDCEBFF);
      case 'motivated':
        return const Color(0xFFDFF5E6);
      case 'happy':
        return const Color(0xFFFFF4D9);
      case 'support':
        return const Color(0xFFFFE6F0);
      default:
        return const Color.fromRGBO(253, 184, 19, 0.15);
    }
  }

  String _moodEmoji(String moodId) {
    final found =
        moods.firstWhere((m) => m.id == moodId, orElse: () => moods.first);
    return found.emoji;
  }
}
