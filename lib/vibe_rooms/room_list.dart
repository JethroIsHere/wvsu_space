import 'package:flutter/material.dart';
// foundation not required; material.dart covers needed APIs
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'repository.dart';
import 'chat.dart';
import 'room_card.dart';
import 'models.dart';
import '../router/app_router.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen>
    with WidgetsBindingObserver {
  late final Future<String?> _nicknameFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nicknameFuture = _fetchNickname();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<String?> _fetchNickname() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      return data?['nickname'] as String?;
    } catch (e) {
      debugPrint('Failed to fetch nickname: $e');
      return null;
    }
  }

  Future<bool> _hasUnacknowledgedNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = userDoc.data();
      if (data == null) return false;

      final warningCount = (data['warningCount'] as num?)?.toInt() ?? 0;
      if (warningCount == 0) return false;

      final lastWarningAt = data['lastWarningAt'] as Timestamp?;
      final lastAcknowledgedAt =
          data['lastWarningAcknowledgedAt'] as Timestamp?;

      if (lastAcknowledgedAt == null ||
          (lastWarningAt != null &&
              lastWarningAt.millisecondsSinceEpoch >
                  lastAcknowledgedAt.millisecondsSinceEpoch)) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Failed to check notifications: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (mirror HomeScreen)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              color: theme.colorScheme.secondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App logo + Nickname greeting
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/wvsu_space_logo.png',
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FutureBuilder<String?>(
                                future: _nicknameFuture,
                                builder: (context, snapshot) {
                                  final nickname = snapshot.data;
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Text(
                                      'Hi, …',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.titleMedium?.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }
                                  if (nickname == null || nickname.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    'Hi, $nickname!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          FutureBuilder<bool>(
                            future: _hasUnacknowledgedNotifications(),
                            builder: (context, snapshot) {
                              final hasUnread = snapshot.data ?? false;
                              return Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.notifications_outlined),
                                    color: Colors.white,
                                    tooltip: 'Notifications',
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRouter.notifications,
                                      );
                                    },
                                  ),
                                  if (hasUnread)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            color: Colors.white,
                            tooltip: 'Settings',
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRouter.settings,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_circle),
                            color: Colors.white,
                            tooltip: 'Profile',
                            onPressed: () {
                              Navigator.pushNamed(context, AppRouter.profile);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vibe Rooms',
                              style: textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Anonymously chat in groups',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 20.0),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.group_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Card(
                color: Colors.blue[50],
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text('Room Guidelines',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.blue[900])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('• Stay on topic for each room',
                                    style: TextStyle(fontSize: 13)),
                                SizedBox(height: 8),
                                Text('• Report inappropriate behavior',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('• Be respectful and supportive',
                                    style: TextStyle(fontSize: 13)),
                                SizedBox(height: 8),
                                Text('• No sharing of personal info',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Room list (takes remaining space)
            Expanded(
              child: StreamBuilder<List<VibeRoom>>(
                stream: VibeRoomsRepository.roomsStream(),
                builder: (context, snapshot) {
                  final rooms = snapshot.data ?? [];
                  final mq = MediaQuery.of(context);
                  // Provide extra bottom padding so items don't collide with
                  // the floating action button and bottom navigation bar.
                  // Increased buffer to handle taller FABs and device nav bars.
                  final double bottomPadding = 24.0 + mq.padding.bottom + 160.0;
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final r = rooms[index];
                      return RoomCard(
                        room: r,
                        onJoin: () async {
                          await VibeRoomsRepository.joinRoom(r.roomId);
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      RoomChatScreen(roomId: r.roomId)),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
