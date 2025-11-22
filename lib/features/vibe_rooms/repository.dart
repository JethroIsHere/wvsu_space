import 'dart:async';
import 'dart:math';
import 'package:wvsu_space/features/vibe_rooms/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// In-memory repository that simulates rooms and messages so the UI works
/// without Firestore. Replace with Firestore logic later when ready.
class VibeRoomsRepository {
  static final Map<String, VibeRoom> _rooms = {};
  static final Map<String, List<VibeMessage>> _messages = {};
  // track participants by roomId -> set of userIds
  static final Map<String, Set<String>> _participants = {};

  static final StreamController<List<VibeRoom>> _roomsController =
      StreamController.broadcast();

  static final Map<String, StreamController<List<VibeMessage>>>
      _messagesControllers = {};
  static final Map<String,
          StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _messageSubscriptions = {};
  static final Map<String, Timer> _presenceTimers = {};
  static final Map<String,
          StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _presenceSubscriptions = {};

  static bool _initialized = false;
  static bool _firestoreListening = false;

  static void _ensureInit() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    // Do not seed placeholder/example rooms in the app by default.
    // Emit an initial empty list so the UI shows only rooms created by users.
    _rooms.clear();
    _messages.clear();
    _messagesControllers.clear();
    _roomsController.add([]);
    // Try to initialize Firestore listener in the background.
    _initFirestoreListener();
  }

  /// Try to resolve a friendly display name for a user id.
  /// Checks `/users/{uid}` then `/vibe_rooms/{roomId}/presence/{uid}` as a fallback.
  static Future<String> _resolveNickname(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final n =
              (data['displayName'] as String?) ?? (data['nickname'] as String?);
          if (n != null && n.isNotEmpty) return n;
        }
      }
    } catch (_) {}

    // Try presence lookup across rooms is expensive; we fallback to 'Anonymous'.
    try {
      final pres = await FirebaseFirestore.instance
          .collectionGroup('presence')
          .where(FieldPath.documentId, isEqualTo: uid)
          .limit(1)
          .get();
      for (final d in pres.docs) {
        final data = d.data();
        final n = (data['nickname'] as String?);
        if (n != null && n.isNotEmpty) return n;
      }
    } catch (_) {}

    return 'Anonymous';
  }

  static void _initFirestoreListener() async {
    if (_firestoreListening) {
      return;
    }
    _firestoreListening = true;
    try {
      final coll = FirebaseFirestore.instance.collection('vibe_rooms');
      // Quick permission check
      try {
        await coll.limit(1).get();
      } catch (e) {
        debugPrint('VibeRoomsRepository: Firestore read permission denied: $e');
        _firestoreListening = false;
        // Retry later
        Future.delayed(const Duration(seconds: 10), _initFirestoreListener);
        return;
      }

      // Listen for remote updates and replace the in-memory store atomically.
      coll.snapshots().listen((snap) {
        final Map<String, VibeRoom> newRooms = {};
        final Set<String> incomingIds = <String>{};
        for (final d in snap.docs) {
          incomingIds.add(d.id);
          final data = d.data();
          DateTime createdAt = DateTime.now();
          DateTime expiresAt = DateTime.now().add(const Duration(minutes: 30));
          try {
            final c = data['createdAt'];
            if (c is Timestamp) {
              createdAt = c.toDate();
            } else if (c is String) {
              createdAt = DateTime.parse(c);
            }
          } catch (_) {}
          try {
            final e = data['expiresAt'];
            if (e is Timestamp) {
              expiresAt = e.toDate();
            } else if (e is String) {
              expiresAt = DateTime.parse(e);
            }
          } catch (_) {}
          final room = VibeRoom(
            roomId: d.id,
            mood: (data['mood'] as String?) ?? 'chill',
            title: (data['title'] as String?) ?? 'Room',
            description: (data['description'] as String?) ?? '',
            createdAt: createdAt,
            expiresAt: expiresAt,
            status: (data['status'] as String?) ?? 'active',
            participantCount: (data['participantCount'] as int?) ?? 0,
            maxParticipants: (data['maxParticipants'] as int?) ?? 8,
            ownerUid: (data['ownerUid'] as String?),
          );
          newRooms[d.id] = room;
        }

        // Detect removed rooms and clean up their resources.
        final removed =
            _rooms.keys.where((k) => !incomingIds.contains(k)).toList();
        for (final rid in removed) {
          // Remove messages controllers
          try {
            final ctl = _messagesControllers.remove(rid);
            ctl?.close();
          } catch (_) {}
          // Cancel message listener
          try {
            final sub = _messageSubscriptions.remove(rid);
            sub?.cancel();
          } catch (_) {}
          // Cancel presence timers/subscriptions
          try {
            _presenceTimers[rid]?.cancel();
          } catch (_) {}
          try {
            _presenceSubscriptions[rid]?.cancel();
          } catch (_) {}
          _presenceTimers.remove(rid);
          _presenceSubscriptions.remove(rid);
          // Remove messages and participants from memory
          _messages.remove(rid);
          _participants.remove(rid);
          // Finally remove room entry
          _rooms.remove(rid);
        }

        // Merge/add new rooms
        for (final entry in newRooms.entries) {
          _rooms[entry.key] = entry.value;
        }

        _emitRooms();
      }, onError: (e) {
        debugPrint('VibeRoomsRepository: Firestore snapshot error: $e');
        _firestoreListening = false;
        Future.delayed(const Duration(seconds: 10), _initFirestoreListener);
      });
    } catch (e) {
      debugPrint('VibeRoomsRepository: Failed to init Firestore listener: $e');
      _firestoreListening = false;
      Future.delayed(const Duration(seconds: 10), _initFirestoreListener);
    }
  }

  static void _emitRooms() {
    _roomsController.add(_rooms.values.toList());
  }

  /// Stream of available rooms (simulated)
  static Stream<List<VibeRoom>> roomsStream() {
    _ensureInit();
    // Always return the in-memory controller stream. Firestore updates are
    // merged into the in-memory store by `_initFirestoreListener`, so the
    // UI sees a single unified source (local + remote).
    return _roomsController.stream;
  }

  /// Get a room by id, try in-memory first then fall back to Firestore fetch.
  static Future<VibeRoom?> getRoom(String roomId) async {
    _ensureInit();
    final existing = _rooms[roomId];
    if (existing != null) return existing;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vibe_rooms')
          .doc(roomId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      DateTime createdAt = DateTime.now();
      DateTime expiresAt = DateTime.now().add(const Duration(minutes: 30));
      try {
        final c = data['createdAt'];
        if (c is Timestamp) {
          createdAt = c.toDate();
        } else if (c is String) {
          createdAt = DateTime.parse(c);
        }
      } catch (_) {}
      try {
        final e = data['expiresAt'];
        if (e is Timestamp) {
          expiresAt = e.toDate();
        } else if (e is String) {
          expiresAt = DateTime.parse(e);
        }
      } catch (_) {}
      final room = VibeRoom(
        roomId: doc.id,
        mood: (data['mood'] as String?) ?? 'chill',
        title: (data['title'] as String?) ?? 'Room',
        description: (data['description'] as String?) ?? '',
        createdAt: createdAt,
        expiresAt: expiresAt,
        status: (data['status'] as String?) ?? 'active',
        participantCount: (data['participantCount'] as int?) ?? 0,
        maxParticipants: (data['maxParticipants'] as int?) ?? 8,
        ownerUid: (data['ownerUid'] as String?),
      );
      _rooms[roomId] = room;
      // init participants if present
      try {
        final parts = data['participants'];
        if (parts is List) {
          _participants[roomId] = parts.map((p) => p.toString()).toSet();
        }
      } catch (_) {}
      _emitRooms();
      return room;
    } catch (e) {
      debugPrint('VibeRoomsRepository.getRoom failed: $e');
      return null;
    }
  }

  /// Create a new room (in-memory)
  static Future<String> createRoom({
    required String mood,
    required String title,
    String description = '',
  }) async {
    _ensureInit();
    final id = 'room_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final creatorUid = FirebaseAuth.instance.currentUser?.uid ?? 'me';

    final room = VibeRoom(
      roomId: id,
      mood: mood,
      title: title,
      description: description,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
      status: 'active',
      participantCount: 1,
      maxParticipants: 8,
      ownerUid: creatorUid,
    );
    _rooms[id] = room;
    _messages[id] = [];
    _messagesControllers[id] = StreamController<List<VibeMessage>>.broadcast();
    _participants[id] = <String>{creatorUid};
    _emitRooms();
    // Also persist to Firestore so other users/devices can see the room.
    try {
      final doc = FirebaseFirestore.instance.collection('vibe_rooms').doc(id);
      await doc.set({
        'mood': mood,
        'title': title,
        'description': description,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 30))),
        'status': 'active',
        'participantCount': 1,
        'maxParticipants': 8,
        'participants': [creatorUid],
        'ownerUid': creatorUid,
      });
    } catch (e) {
      debugPrint('VibeRoomsRepository.createRoom: Firestore set failed: $e');
      // ignore firestore errors in the in-memory demo
    }
    return id;
  }

  /// Find an existing room by mood or create a new one
  static Future<String> findOrCreateVibeRoom(String mood) async {
    _ensureInit();
    try {
      final open = _rooms.values.where(
          (r) => r.mood == mood && r.participantCount < r.maxParticipants);
      if (open.isNotEmpty) return open.first.roomId;
    } catch (_) {}
    return createRoom(
        mood: mood, title: '${mood[0].toUpperCase()}${mood.substring(1)} Room');
  }

  /// Join a room (increments participant count and emits update)
  static Future<void> joinRoom(String roomId, {String userId = 'me'}) async {
    _ensureInit();
    var room = _rooms[roomId];
    if (room == null) {
      // Try to fetch room from Firestore if not present in-memory yet.
      try {
        final doc = await FirebaseFirestore.instance
            .collection('vibe_rooms')
            .doc(roomId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          DateTime createdAt = DateTime.now();
          DateTime expiresAt = DateTime.now().add(const Duration(minutes: 30));
          try {
            final c = data['createdAt'];
            if (c is Timestamp) {
              createdAt = c.toDate();
            } else if (c is String) {
              createdAt = DateTime.parse(c);
            }
          } catch (_) {}
          try {
            final e = data['expiresAt'];
            if (e is Timestamp) {
              expiresAt = e.toDate();
            } else if (e is String) {
              expiresAt = DateTime.parse(e);
            }
          } catch (_) {}
          room = VibeRoom(
            roomId: doc.id,
            mood: (data['mood'] as String?) ?? 'chill',
            title: (data['title'] as String?) ?? 'Room',
            description: (data['description'] as String?) ?? '',
            createdAt: createdAt,
            expiresAt: expiresAt,
            status: (data['status'] as String?) ?? 'active',
            participantCount: (data['participantCount'] as int?) ?? 0,
            maxParticipants: (data['maxParticipants'] as int?) ?? 8,
            ownerUid: (data['ownerUid'] as String?),
          );
          _rooms[roomId] = room;
          // initialize participants set from Firestore participants array if present
          try {
            final parts = data['participants'];
            if (parts is List) {
              _participants[roomId] = parts.map((p) => p.toString()).toSet();
            }
          } catch (_) {}
        } else {
          throw StateError('Room not found');
        }
      } catch (e) {
        throw StateError('Room not found');
      }
    }
    _participants.putIfAbsent(roomId, () => <String>{});
    final actualUserId = userId == 'me'
        ? FirebaseAuth.instance.currentUser?.uid ?? 'me'
        : userId;
    final added = _participants[roomId]!.add(actualUserId);
    if (added) {
      room.participantCount = _participants[roomId]!.length;
      _rooms[roomId] = room;
      _emitRooms();
      // add a system join message using the user's nickname when possible
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final isLocal = currentUid != null && actualUserId == currentUid;
      // Resolve a real display name for the joining user. For local user we use
      // the current user's displayName if available; for others try user doc or
      // presence doc, otherwise fall back to 'Anonymous'.
      String resolvedName;
      String persistedName;
      if (isLocal) {
        // Prefer a nickname stored in the users collection (profile)
        String? localNick;
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(actualUserId)
              .get();
          final data = doc.data();
          localNick = (data?['nickname'] as String?)?.trim();
        } catch (_) {}
        final currentDisplay = FirebaseAuth.instance.currentUser?.displayName;
        if (localNick != null && localNick.isNotEmpty) {
          resolvedName = localNick;
          persistedName = localNick;
        } else if (currentDisplay != null && currentDisplay.isNotEmpty) {
          resolvedName = currentDisplay;
          persistedName = currentDisplay;
        } else {
          // generate a local nickname and persist it in presence
          final gen = 'User${Random().nextInt(9000) + 1000}';
          resolvedName = gen;
          persistedName = gen;
        }
      } else {
        resolvedName = await _resolveNickname(actualUserId);
        persistedName = resolvedName;
      }

      // Persist a system-typed message authored by the joining user so it passes rules
      await sendMessage(roomId, actualUserId, '$resolvedName joined the room',
          senderNickname: persistedName, isSystem: true);
      // Update Firestore if possible using a transaction to avoid races
      try {
        final docRef =
            FirebaseFirestore.instance.collection('vibe_rooms').doc(roomId);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(docRef);
          if (!snap.exists) return;
          final data = snap.data();
          final currentCount = (data?['participantCount'] as int?) ?? 0;
          tx.update(docRef, {
            'participantCount': currentCount + 1,
            'participants': FieldValue.arrayUnion([actualUserId])
          });
        });
      } catch (e) {
        debugPrint(
            'VibeRoomsRepository.joinRoom: Firestore transaction failed: $e');
      }
      // Start presence tracking for this user in the room
      try {
        _startPresenceTracking(roomId, actualUserId, displayName: resolvedName);
      } catch (e) {
        debugPrint('VibeRoomsRepository.joinRoom: startPresence failed: $e');
      }
    }
  }

  static Future<void> leaveRoom(String roomId, {String userId = 'me'}) async {
    _ensureInit();
    final room = _rooms[roomId];
    if (room == null) return;
    final set = _participants[roomId];
    if (set != null) {
      final actualUserId = userId == 'me'
          ? FirebaseAuth.instance.currentUser?.uid ?? 'me'
          : userId;

      // If the leaving user is the owner, disband the room immediately for all users.
      if (room.ownerUid != null && actualUserId == room.ownerUid) {
        // Remove in-memory state and cancel listeners/timers
        _rooms.remove(roomId);
        _messages.remove(roomId);
        final ctl = _messagesControllers.remove(roomId);
        ctl?.close();
        // cancel any firestore message listener for this room
        final sub = _messageSubscriptions.remove(roomId);
        try {
          sub?.cancel();
        } catch (_) {}
        // cancel presence tracking
        try {
          _presenceTimers[roomId]?.cancel();
        } catch (_) {}
        try {
          _presenceSubscriptions[roomId]?.cancel();
        } catch (_) {}
        _presenceTimers.remove(roomId);
        _presenceSubscriptions.remove(roomId);
        _participants.remove(roomId);
        _emitRooms();

        // Attempt to delete presence and messages then the room doc.
        try {
          final docRef =
              FirebaseFirestore.instance.collection('vibe_rooms').doc(roomId);
          // Presence docs are owned by individual users and cannot be
          // deleted reliably from client code (permission rules prevent it).
          // We skip attempting to delete presence docs here.

          // Run heavy deletion work in the background so the UI leave flow
          // isn't blocked and we avoid race conditions between removal and
          // listeners that may still be active on the client.
          () async {
            try {
              try {
                await _deleteRoomMessages(roomId);
              } catch (e) {
                debugPrint('Background _deleteRoomMessages failed: $e');
              }
              try {
                await docRef.delete();
              } catch (e) {
                debugPrint('Background room doc delete failed: $e');
              }
            } catch (e) {
              debugPrint('Background room cleanup failed: $e');
            }
          }();
        } catch (e) {
          debugPrint(
              'VibeRoomsRepository.leaveRoom (owner): Firestore delete scheduling failed: $e');
        }

        return;
      }
      if (set.isEmpty) {
        // disband room
        _rooms.remove(roomId);
        _messages.remove(roomId);
        final ctl = _messagesControllers.remove(roomId);
        ctl?.close();
        // cancel any firestore message listener for this room
        final sub = _messageSubscriptions.remove(roomId);
        try {
          sub?.cancel();
        } catch (_) {}
        _participants.remove(roomId);
        _emitRooms();
        try {
          // delete messages then room doc
          try {
            await _deleteRoomMessages(roomId);
          } catch (_) {}
          await FirebaseFirestore.instance
              .collection('vibe_rooms')
              .doc(roomId)
              .delete();
        } catch (e) {
          debugPrint(
              'VibeRoomsRepository.leaveRoom: Firestore delete failed: $e');
        }
        return;
      } else {
        _rooms[roomId] = room;
        _emitRooms();
        final currentUid2 = FirebaseAuth.instance.currentUser?.uid;
        final isLocalLeave = currentUid2 != null && actualUserId == currentUid2;
        String resolvedLeaveName;
        String persistedLeaveName;
        if (isLocalLeave) {
          final currentDisplay = FirebaseAuth.instance.currentUser?.displayName;
          if (currentDisplay != null && currentDisplay.isNotEmpty) {
            resolvedLeaveName = currentDisplay;
            persistedLeaveName = currentDisplay;
          } else {
            resolvedLeaveName = await _resolveNickname(actualUserId);
            persistedLeaveName = resolvedLeaveName == 'Anonymous'
                ? 'Anonymous'
                : resolvedLeaveName;
          }
        } else {
          resolvedLeaveName = await _resolveNickname(actualUserId);
          persistedLeaveName = resolvedLeaveName;
        }
        await sendMessage(
            roomId, actualUserId, '$resolvedLeaveName left the room',
            senderNickname: persistedLeaveName, isSystem: true);
        try {
          final doc =
              FirebaseFirestore.instance.collection('vibe_rooms').doc(roomId);
          await doc.update({
            'participantCount': room.participantCount,
            'participants': FieldValue.arrayRemove([actualUserId])
          });
        } catch (e) {
          debugPrint(
              'VibeRoomsRepository.leaveRoom: Firestore update failed: $e');
        }
      }
    }
  }

  /// Deletes all messages under a room in batches. Client-side fallback for recursive delete.
  static Future<void> _deleteRoomMessages(String roomId) async {
    final coll = FirebaseFirestore.instance
        .collection('vibe_rooms')
        .doc(roomId)
        .collection('messages');
    const batchSize = 400; // stay below 500 write limit
    while (true) {
      final snap = await coll.limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      // small delay to avoid hitting per-second limits
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Stream messages for a room
  static Stream<List<VibeMessage>> messagesStream(String roomId) {
    _ensureInit();
    _messagesControllers.putIfAbsent(
        roomId, () => StreamController<List<VibeMessage>>.broadcast());

    // If we don't yet have a Firestore listener for this room's messages,
    // attempt to attach one. On permission errors we'll log and continue
    // using the in-memory messages only.
    if (!_messageSubscriptions.containsKey(roomId)) {
      try {
        final coll = FirebaseFirestore.instance
            .collection('vibe_rooms')
            .doc(roomId)
            .collection('messages')
            .orderBy('timestamp');
        final sub = coll.snapshots().listen((snap) {
          final msgs = snap.docs.map((d) {
            final data = d.data();
            DateTime ts = DateTime.now();
            try {
              // Prefer server-assigned timestamp when present for consistent ordering.
              final s = data['serverTimestamp'];
              if (s is Timestamp) {
                ts = s.toDate();
              } else {
                final t = data['timestamp'];
                if (t is Timestamp) {
                  ts = t.toDate();
                } else if (t is String) {
                  ts = DateTime.parse(t);
                }
              }
            } catch (_) {}
            return VibeMessage(
              messageId: d.id,
              senderId: (data['senderId'] as String?) ?? 'system',
              senderNickname:
                  (data['senderNickname'] as String?) ?? 'Anonymous',
              text: (data['text'] as String?) ?? '',
              timestamp: ts,
              isSystem: (data['isSystem'] as bool?) ?? false,
            );
          }).toList();
          // For messages that don't include a useful senderNickname, attempt
          // to resolve the user's nickname in the background and update the
          // in-memory list so the UI can refresh with the resolved name.
          for (final m in List<VibeMessage>.from(msgs)) {
            if ((m.senderNickname.isEmpty || m.senderNickname == 'Anonymous') &&
                m.senderId != 'system') {
              // Fire-and-forget resolution; when resolved, replace the message
              // object in the messages array and emit the updated list.
              _resolveNickname(m.senderId).then((resolved) {
                if (resolved != 'Anonymous') {
                  final i = msgs.indexWhere((x) => x.messageId == m.messageId);
                  if (i != -1 && msgs[i].senderNickname != resolved) {
                    final updated = VibeMessage(
                      messageId: msgs[i].messageId,
                      senderId: msgs[i].senderId,
                      senderNickname: resolved,
                      text: msgs[i].text,
                      timestamp: msgs[i].timestamp,
                      isSystem: msgs[i].isSystem,
                    );
                    msgs[i] = updated;
                    _messages[roomId] = msgs;
                    _messagesControllers[roomId]?.add(List.unmodifiable(msgs));
                  }
                }
              }).catchError((_) {});
            }
          }
          _messages[roomId] = msgs;
          _messagesControllers[roomId]!.add(List.unmodifiable(msgs));
        }, onError: (e) {
          debugPrint('VibeRoomsRepository.messagesStream: Firestore error: $e');
        });
        _messageSubscriptions[roomId] = sub;
      } catch (e) {
        debugPrint('VibeRoomsRepository.messagesStream: attach failed: $e');
      }
    }

    return _messagesControllers[roomId]!.stream;
  }

  /// Start presence tracking for the given room and user.
  /// Writes a presence doc under `vibe_rooms/{roomId}/presence/{uid}` and
  /// keeps it updated with a periodic heartbeat. Also listens to presence
  /// changes to compute active participants and update the room accordingly.
  static Future<void> _startPresenceTracking(String roomId, String uid,
      {String? displayName}) async {
    _presenceTimers[roomId]?.cancel();
    try {
      await _presenceSubscriptions[roomId]?.cancel();
    } catch (_) {}

    final presenceColl = FirebaseFirestore.instance
        .collection('vibe_rooms')
        .doc(roomId)
        .collection('presence');

    try {
      await presenceColl.doc(uid).set({
        'lastSeen': Timestamp.fromDate(DateTime.now()),
        'nickname': displayName ?? ''
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('VibeRoomsRepository._startPresenceTracking: set failed: $e');
    }

    // Periodic heartbeat
    _presenceTimers[roomId] =
        Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        await presenceColl.doc(uid).set(
            {'lastSeen': Timestamp.fromDate(DateTime.now())},
            SetOptions(merge: true));
      } catch (e) {
        debugPrint('VibeRoomsRepository._presence heartbeat failed: $e');
      }
    });

    // Listen for presence docs and compute active participants
    _presenceSubscriptions[roomId] =
        presenceColl.snapshots().listen((snap) async {
      final now = DateTime.now();
      final active = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        DateTime lastSeen = now;
        try {
          final t = data['lastSeen'];
          if (t is Timestamp) {
            lastSeen = t.toDate();
          } else if (t is String) {
            lastSeen = DateTime.parse(t);
          }
        } catch (_) {}
        final age = now.difference(lastSeen).inSeconds;
        // If stale, don't attempt to delete (clients may not have permission).
        if (age > 40) continue;
        active.add(d.id);
      }

      _participants[roomId] = active;
      final room = _rooms[roomId];
      if (room != null) {
        room.participantCount = active.length;
        _rooms[roomId] = room;
      }
      _emitRooms();

      // Update the room document's participant list/count to match active set
      try {
        final docRef =
            FirebaseFirestore.instance.collection('vibe_rooms').doc(roomId);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snapRoom = await tx.get(docRef);
          if (!snapRoom.exists) return;
          tx.update(docRef, {
            'participantCount': active.length,
            'participants': active.toList(),
          });
        });
      } catch (e) {
        debugPrint('VibeRoomsRepository._presence update failed: $e');
      }
    }, onError: (e) {
      debugPrint('VibeRoomsRepository._presence subscription error: $e');
    });
  }

  /// Return current participant count for a room
  static int participantCountFor(String roomId) {
    return _participants[roomId]?.length ??
        _rooms[roomId]?.participantCount ??
        0;
  }

  /// Whether the given user is the last participant in the room
  static bool isUserLastParticipant(String roomId, String userId) {
    final set = _participants[roomId];
    if (set == null) return false;
    final actualUserId = userId == 'me'
        ? FirebaseAuth.instance.currentUser?.uid ?? 'me'
        : userId;
    return set.length == 1 && set.contains(actualUserId);
  }

  /// Send a message to a room
  static Future<void> sendMessage(String roomId, String senderId, String text,
      {String? senderNickname, bool isSystem = false}) async {
    _ensureInit();
    final actualSenderId = senderId == 'me'
        ? FirebaseAuth.instance.currentUser?.uid ?? 'me'
        : senderId;
    // Compute a persisted nickname (what is stored in Firestore) and a
    // display nickname used for the in-memory message object. We avoid
    // persisting the literal 'You' so other clients see the real name.
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final currentDisplayName = FirebaseAuth.instance.currentUser?.displayName;
    final persistedNickname =
        (senderNickname != null && senderNickname != 'You')
            ? senderNickname
            : (actualSenderId == currentUid
                ? (currentDisplayName ?? 'Anonymous')
                : (senderNickname ?? 'Anonymous'));
    final displayNickname =
        (actualSenderId == currentUid) ? 'You' : persistedNickname;

    final msg = VibeMessage(
      messageId: '${roomId}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: actualSenderId,
      senderNickname: displayNickname,
      text: text,
      timestamp: DateTime.now(),
      isSystem: isSystem,
    );
    _messages.putIfAbsent(roomId, () => []);
    _messages[roomId]!.add(msg);
    _messagesControllers.putIfAbsent(
        roomId, () => StreamController<List<VibeMessage>>.broadcast());
    _messagesControllers[roomId]!.add(List.unmodifiable(_messages[roomId]!));
    // Also persist message to Firestore so other clients receive it.
    try {
      final doc = FirebaseFirestore.instance
          .collection('vibe_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(msg.messageId);
      await doc.set({
        'senderId': msg.senderId,
        'senderNickname': persistedNickname,
        'text': msg.text,
        // Persist a client timestamp for rules validation and quick ordering,
        // and also record a server timestamp for canonical ordering when available.
        'timestamp': Timestamp.fromDate(msg.timestamp),
        'serverTimestamp': FieldValue.serverTimestamp(),
        'isSystem': msg.isSystem,
      });
    } catch (e) {
      debugPrint('VibeRoomsRepository.sendMessage: Firestore set failed: $e');
    }
  }

  /// Dispose controllers (not strictly necessary for the in-memory demo)
  static void dispose() {
    _roomsController.close();
    for (final c in _messagesControllers.values) {
      c.close();
    }
  }
}
