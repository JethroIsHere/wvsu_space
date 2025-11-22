// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wvsu_space/router/app_router.dart';
import 'package:wvsu_space/utils/app_colors.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  Map<String, dynamic>? _foundUser;
  String? _searchError;
  bool _showClearButton = false;
  String? _lastSearchedQuery;
  bool _hasSearched = false;
  int _searchSeq = 0; // invalidate stale async completions

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final hasText = _searchController.text.isNotEmpty;
    // Only rebuild when clear button visibility needs to change OR
    // when we need to clear stale results/errors after the user edits the query.
    final queryText = _searchController.text;
    final divergedFromLast = queryText != (_lastSearchedQuery ?? '');
    final shouldClearResults = divergedFromLast &&
        (_foundUser != null || _searchError != null || _hasSearched);

    if (hasText != _showClearButton || shouldClearResults) {
      setState(() {
        _showClearButton = hasText;
        if (shouldClearResults) {
          _foundUser = null;
          _searchError = null;
          _hasSearched = false; // gate UI until next explicit search
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    if (_isSearching) return; // prevent overlapping searches
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchError = 'Please enter a Student ID or Pseudonym';
        _foundUser = null;
      });
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final mySeq = ++_searchSeq; // bump sequence for this search
    setState(() {
      _isSearching = true;
      _searchError = null;
      _foundUser = null;
      _lastSearchedQuery = query;
      _hasSearched = true;
    });

    // Note: we rely on comparing current text vs the original 'query' to ignore stale completions.
    try {
      // Run both queries in parallel for better performance
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .where('studentId', isEqualTo: query)
            .limit(1)
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('nickname', isEqualTo: query)
            .limit(1)
            .get(),
      ]).timeout(const Duration(seconds: 15));

      final studentIdQuery = results[0];
      final nicknameQuery = results[1];

      // Check studentId results first
      if (studentIdQuery.docs.isNotEmpty) {
        final doc = studentIdQuery.docs.first;
        if (!mounted) return;
        if (_searchController.text.trim() != query) return; // stale by text
        if (mySeq != _searchSeq) return; // stale by sequence
        setState(() {
          _foundUser = {
            'uid': doc.id,
            ...doc.data(),
          };
        });
        return;
      }

      // Check nickname results
      if (nicknameQuery.docs.isNotEmpty) {
        final doc = nicknameQuery.docs.first;
        if (!mounted) return;
        if (_searchController.text.trim() != query) return; // stale by text
        if (mySeq != _searchSeq) return; // stale by sequence
        setState(() {
          _foundUser = {
            'uid': doc.id,
            ...doc.data(),
          };
        });
        return;
      }

      // No user found
      if (!mounted) return;
      if (_searchController.text.trim() != query) return; // stale by text
      if (mySeq != _searchSeq) return; // stale by sequence
      setState(() {
        _searchError = 'No user found with that Student ID or Pseudonym';
      });
    } catch (e) {
      if (!mounted) return;
      if (mySeq != _searchSeq) return; // stale
      setState(() {
        _searchError = 'Error searching: $e';
      });
    } finally {
      if (mounted && mySeq == _searchSeq) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'User Management',
          style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ) ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: FutureBuilder<bool>(
        future: _checkIsAdmin(),
        builder: (context, adminSnap) {
          if (adminSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!adminSnap.hasData || adminSnap.data != true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Not authorized.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRouter.adminLogin),
                      child: const Text('Admin Login'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.search,
                                color: BrandColors.appBlue, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'Search User',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Enter Student ID or Pseudonym',
                                  hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14),
                                  prefixIcon: Icon(Icons.person_search,
                                      color: Colors.grey.shade400),
                                  suffixIcon: _showClearButton
                                      ? IconButton(
                                          icon:
                                              const Icon(Icons.clear, size: 20),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _foundUser = null;
                                              _searchError = null;
                                              _isSearching = false;
                                              _hasSearched = false;
                                              _lastSearchedQuery = null;
                                              _searchSeq++; // invalidate any in-flight search
                                            });
                                            // Ensure the field is ready for new input immediately
                                            _searchFocusNode.requestFocus();
                                          },
                                          tooltip: 'Clear',
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: BrandColors.appBlue, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                // Intentionally disable onSubmitted so search only occurs
                                // when pressing the Search button.
                                // onSubmitted: (_) => _searchUser(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, _) {
                                final canSearch =
                                    value.text.trim().isNotEmpty &&
                                        !_isSearching;
                                return SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: canSearch ? _searchUser : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: BrandColors.appBlue,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          Colors.grey.shade300,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 1,
                                    ),
                                    child: _isSearching
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Search',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (_hasSearched && _searchError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _searchError!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Quick access list for admins: show recent / alphabetical users
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Access',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 220,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .orderBy('nickname')
                                .limit(20)
                                .snapshots(),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              if (!snap.hasData || snap.data!.docs.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No users to show',
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.all(4),
                                itemCount: snap.data!.docs.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, i) {
                                  final doc = snap.data!.docs[i];
                                  final data =
                                      doc.data() as Map<String, dynamic>? ?? {};
                                  final nickname =
                                      (data['nickname'] as String?) ?? '';
                                  return ListTile(
                                    onTap: () {
                                      // select this user as the searched user
                                      setState(() {
                                        _foundUser = {'uid': doc.id, ...data};
                                        _hasSearched = true;
                                        // only populate search field with nickname to
                                        // avoid exposing student IDs in the UI
                                        if (nickname.isNotEmpty) {
                                          _searchController.text = nickname;
                                        }
                                        _searchError = null;
                                      });
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.grey.shade200,
                                      child: Text(
                                        (nickname.isNotEmpty
                                                ? nickname[0]
                                                : '?')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.black87),
                                      ),
                                    ),
                                    title: Text(nickname.isNotEmpty
                                        ? nickname
                                        : '(no nickname)'),
                                    trailing: const Icon(Icons.chevron_right),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // User result or empty state
                if (_hasSearched && _foundUser != null)
                  _UserProfileCard(userData: _foundUser!)
                else if (!_hasSearched)
                  _EmptySearchState()
                else if (_hasSearched &&
                    !_isSearching &&
                    _searchError == null &&
                    _foundUser == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      'No user selected. Perform a search.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _checkIsAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final t = await user.getIdTokenResult(true);
      return (t.claims ?? const {})['admin'] == true;
    } catch (_) {
      return false;
    }
  }
}

class _EmptySearchState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Search for a User',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter a Student ID or Pseudonym to view user profile and management options',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserProfileCard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const _UserProfileCard({required this.userData});

  @override
  State<_UserProfileCard> createState() => _UserProfileCardState();
}

class _UserProfileCardState extends State<_UserProfileCard> {
  // report counts removed from UI; no longer tracked here
  late Map<String, dynamic> _currentUserData;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  @override
  void initState() {
    super.initState();
    _currentUserData = widget.userData;
    _listenToUser();
  }

  void _listenToUser() {
    final uid = _currentUserData['uid'] as String?;
    if (uid == null) return;
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data()!;
      setState(() {
        _currentUserData = {
          'uid': uid,
          ...data,
        };
      });
      // If neither lastActiveAt nor lastActive exist yet, seed lastActiveAt now so admin can see a timestamp.
      if (data['lastActiveAt'] == null && data['lastActive'] == null) {
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'lastActiveAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshUserData() async {
    try {
      final uid = _currentUserData['uid'] as String;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists && mounted) {
        final newData = {
          'uid': uid,
          ...userDoc.data()!,
        };
        debugPrint(
            'Refreshed user data: standing=${newData['standing']}, lastActiveAt=${newData['lastActiveAt']}');
        setState(() {
          _currentUserData = newData;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing user data: $e');
    }
  }

  // Parses various timestamp representations (Timestamp, int millis/seconds, ISO string)
  DateTime? _parseFlexibleTimestamp(dynamic value) {
    try {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) {
        // Assume millis if it looks like millis, otherwise seconds
        if (value > 2000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
              .toLocal();
        } else {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
              .toLocal();
        }
      }
      if (value is String) {
        // Try ISO 8601
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nickname = _currentUserData['nickname'] as String? ?? 'Unknown';
    // The field is called 'standing' not 'score'
    final standingRaw = (_currentUserData['standing'] ??
        _currentUserData['score'] ??
        100) as num;
    // Standing is stored as 0-100, display as integer
    final score = standingRaw.toInt();
    final joinedAt = _parseFlexibleTimestamp(_currentUserData['createdAt']);
    // Resolve last active with multi-source fallback
    final lastActiveAt = _resolveLastActive(_currentUserData);
    debugPrint(
        'User $nickname: standing=$standingRaw, lastActiveAt=$lastActiveAt');
    final uid = _currentUserData['uid'] as String;

    // Check user status
    final isSuspended = _currentUserData['suspended'] == true;
    final isRestricted = _currentUserData['restricted'] == true;
    final suspendedUntil = _currentUserData['suspendedUntil'] as Timestamp?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSuspended
            ? BorderSide(color: Colors.red.shade300, width: 2)
            : isRestricted
                ? BorderSide(color: Colors.orange.shade300, width: 2)
                : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            if (isSuspended || isRestricted) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isSuspended ? Colors.red.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSuspended
                        ? Colors.red.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSuspended ? Icons.block : Icons.warning,
                      color: isSuspended ? Colors.red : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSuspended
                            ? 'SUSPENDED${suspendedUntil != null ? " until ${_formatDate(suspendedUntil.toDate())}" : ""}'
                            : 'RESTRICTED - Cannot start new chats',
                        style: TextStyle(
                          color: isSuspended
                              ? Colors.red.shade900
                              : Colors.orange.shade900,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // User Header
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: BrandColors.appBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'UID: $uid',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // User Stats
            Row(
              children: [
                Expanded(
                  child: _InfoColumn(
                    label: 'Current Score',
                    value: '$score',
                    valueColor: _getScoreColor(score.toDouble()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _InfoColumn(
                    label: 'Joined',
                    value: joinedAt != null ? _formatDate(joinedAt) : '—',
                  ),
                ),
                Expanded(
                  child: _InfoColumn(
                    label: 'Last Active',
                    value: lastActiveAt != null
                        ? _formatDateTime(lastActiveAt)
                        : '—',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Adjust Score',
                    color: BrandColors.appBlue,
                    icon: Icons.edit,
                    onPressed: () => _showAdjustScoreDialog(
                      context,
                      uid,
                      score.toDouble(),
                      _refreshUserData,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Suspend',
                    color: Colors.red,
                    icon: Icons.block,
                    onPressed: () => _showSuspendDialog(
                      context,
                      uid,
                      nickname,
                      _refreshUserData,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Restrict',
                    color: Colors.orange,
                    icon: Icons.warning,
                    onPressed: isRestricted
                        ? null
                        : () => _showRestrictDialog(
                              context,
                              uid,
                              nickname,
                              _refreshUserData,
                            ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Reinstate',
                    color: Colors.green,
                    icon: Icons.check_circle,
                    onPressed: (!isRestricted && !isSuspended)
                        ? null
                        : () => _showReinstateDialog(
                              context,
                              uid,
                              nickname,
                              _refreshUserData,
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 85) return BrandColors.appGreen;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Attempts to derive last active timestamp from available fields.
  // Priority order:
  // 1. lastActiveAt (server timestamp)
  // 2. lastActive (legacy mirrored field)
  // 3. activity fields: lastWarningAt, createdAt fallback
  // 4. in absence, null
  DateTime? _resolveLastActive(Map<String, dynamic> data) {
    final primary = _parseFlexibleTimestamp(data['lastActiveAt']);
    if (primary != null) return primary;
    final legacy = _parseFlexibleTimestamp(data['lastActive']);
    if (legacy != null) return legacy;
    final warning = _parseFlexibleTimestamp(data['lastWarningAt']);
    if (warning != null) return warning;
    // Avoid showing joined date as last active if too old (heuristic)
    final created = _parseFlexibleTimestamp(data['createdAt']);
    if (created != null) {
      final now = DateTime.now();
      // If user has no other activity, treat creation within last 5 minutes as initial activity
      if (now.difference(created).inMinutes <= 5) return created;
    }
    return null;
  }

  void _showAdjustScoreDialog(
    BuildContext context,
    String uid,
    double currentScore,
    VoidCallback onUpdate,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Score'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current score: ${currentScore.toInt()} / 100'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Score',
                hintText: 'Enter new score (0 - 100)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newScore = int.tryParse(controller.text);
              if (newScore == null || newScore < 0 || newScore > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid score. Enter 0 - 100')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'standing': newScore});

                // Create a notification for the user about the score adjustment
                await _createUserNotification(
                  uid,
                  {
                    'type': 'score_adjustment',
                    'category': 'Score Adjustment',
                    'message':
                        'Your community standing was adjusted from ${currentScore.toInt()} to $newScore by an admin.',
                    'standingBefore': currentScore.toInt(),
                    'standingAfter': newScore,
                  },
                );

                Navigator.pop(context);
                onUpdate(); // Refresh the UI
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Score updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _createUserNotification(
    String uid,
    Map<String, dynamic> data,
  ) async {
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('warnings')
          .add({
        'createdAt': FieldValue.serverTimestamp(),
        'adminUid': adminUid,
        ...data,
      });
    } catch (e) {
      debugPrint('Failed to create user notification: $e');
    }
  }

  void _showSuspendDialog(
    BuildContext context,
    String uid,
    String nickname,
    VoidCallback onUpdate,
  ) {
    final daysController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Suspend $nickname'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (days)',
                hintText: 'Enter number of days',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter suspension reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final days = int.tryParse(daysController.text);
              final reason = reasonController.text.trim();

              if (days == null || days <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid duration')),
                );
                return;
              }

              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason')),
                );
                return;
              }

              try {
                final until = DateTime.now().add(Duration(days: days));
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                  'suspended': true,
                  'suspendedUntil': Timestamp.fromDate(until),
                  'suspensionReason': reason,
                });

                Navigator.pop(context);
                onUpdate(); // Refresh the UI
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$nickname suspended for $days days')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  void _showRestrictDialog(
    BuildContext context,
    String uid,
    String nickname,
    VoidCallback onUpdate,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restrict $nickname'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('User will be unable to start new chats.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter restriction reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();

              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                  'restricted': true,
                  'restrictionReason': reason,
                });

                Navigator.pop(context);
                onUpdate(); // Refresh the UI
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$nickname has been restricted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restrict'),
          ),
        ],
      ),
    );
  }

  void _showReinstateDialog(
    BuildContext context,
    String uid,
    String nickname,
    VoidCallback onUpdate,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reinstate $nickname'),
        content: const Text(
          'This will remove all suspensions and restrictions from this user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                  'suspended': false,
                  'suspendedUntil': FieldValue.delete(),
                  'suspensionReason': FieldValue.delete(),
                  'restricted': false,
                  'restrictionReason': FieldValue.delete(),
                });

                Navigator.pop(context);
                onUpdate(); // Refresh the UI
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$nickname has been reinstated')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Reinstate'),
          ),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
            fontSize: 16,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? Colors.grey.shade300 : color,
        foregroundColor: isDisabled ? Colors.grey.shade600 : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 1,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
