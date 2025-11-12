import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// A dialog shown after the chat ends that lets the user rate their partner.
class RateConversationDialog extends StatefulWidget {
  final String sessionId;
  final VoidCallback? onComplete;

  const RateConversationDialog({
    super.key,
    required this.sessionId,
    this.onComplete,
  });

  @override
  State<RateConversationDialog> createState() => _RateConversationDialogState();
}

class _RateConversationDialogState extends State<RateConversationDialog> {
  int _selectedRating = 0; // 1..5
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
              child:
                  const Icon(Icons.chat_bubble, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rate your conversation\npartner',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your feedback helps keep WVSU\nSpace safe and positive for\neveryone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                final sel = _selectedRating >= star;
                return GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => setState(() => _selectedRating = star),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      sel ? Icons.star : Icons.star_border,
                      size: 40,
                      color: sel ? Colors.amber : Colors.grey[300],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _label(_selectedRating),
              style: TextStyle(
                fontSize: 14,
                color: _selectedRating > 0 ? primary : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedRating > 0 && !_submitting ? _submitRating : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Rating',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _submitting ? null : _skip,
              child: const Text('Skip',
                  style: TextStyle(fontSize: 14, color: Colors.black87)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ratings are anonymous and help maintain\ncommunity standards. Your identity remains\ncompletely private.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[700], height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(int r) {
    switch (r) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating < 1 || _submitting) return;
    setState(() => _submitting = true);
    try {
      // Force refresh auth state
      await FirebaseAuth.instance.authStateChanges().first;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Not authenticated - please sign in again');
      }

      final uid = currentUser.uid;
      if (uid.isEmpty) {
        throw Exception('Invalid user ID');
      }

      // Get session to find the other participant
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .get();

      final data = sessionDoc.data();
      if (data == null || data['participants'] is! List) {
        throw Exception('Invalid session data');
      }

      final parts = List<String>.from(data['participants']);
      final otherUid = parts.firstWhere((p) => p != uid, orElse: () => '');
      if (otherUid.isEmpty) {
        throw Exception('Could not find conversation partner');
      }

      debugPrint(
          'Rating submission - Rater: $uid, Rated: $otherUid, Rating: $_selectedRating');

      // Calculate standing delta: 1:-2, 2:-1, 3:0, 4:+1, 5:+2
      final deltas = {1: -2, 2: -1, 3: 0, 4: 1, 5: 2};
      final delta = deltas[_selectedRating] ?? 0;

      debugPrint('Standing delta: $delta');

      // 1. Create the rating document
      await FirebaseFirestore.instance.collection('ratings').add({
        'sessionId': widget.sessionId,
        'ratedBy': uid,
        'ratedUser': otherUid,
        'rating': _selectedRating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (delta != 0) {
        // 2. Update the rated user's standing using a transaction for atomicity
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(otherUid);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final userDoc = await transaction.get(userRef);

          if (!userDoc.exists) {
            // Create user document with initial standing
            debugPrint(
                'Creating new user doc for $otherUid with standing: ${100 + delta}');
            transaction.set(userRef, {
              'standing': 100 + delta,
              'uid': otherUid,
            });
          } else {
            // Update existing standing
            final currentStanding = userDoc.data()?['standing'] ?? 100;
            final newStanding = currentStanding + delta;
            debugPrint(
                'Updating standing for $otherUid: $currentStanding -> $newStanding');
            transaction.update(userRef, {
              'standing': newStanding,
            });
          }
        });

        debugPrint('Standing update completed successfully');

        // 3. Add standing report (after transaction completes)
        await userRef.collection('standing_reports').add({
          // Store a generic sanitized title (no explicit qualitative label)
          'title': 'Conversation feedback received',
          'delta': delta,
          'type': 'chat_rating',
          'time': FieldValue.serverTimestamp(),
          'sessionId': widget.sessionId,
          // Additional fields retained for internal analytics / future use
          'rating': _selectedRating,
          'ratingLabel': _label(_selectedRating),
        });
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      widget.onComplete?.call();
    } catch (e, stackTrace) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);

      // More detailed error messages
      String msg;
      final errorStr = e.toString().toLowerCase();

      debugPrint('Rating submission error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (errorStr.contains('permission') || errorStr.contains('denied')) {
        msg = 'Permission denied. Please check your sign-in status.';
      } else if (errorStr.contains('not authenticated') ||
          errorStr.contains('not signed in')) {
        msg = 'You must be signed in to submit a rating.';
      } else if (errorStr.contains('network')) {
        msg = 'Network error. Please check your connection.';
      } else if (errorStr.contains('invalid session')) {
        msg = 'Session data not found. The chat may have already ended.';
      } else {
        msg = 'Failed to submit rating: $e';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _skip() {
    Navigator.of(context).pop();
    widget.onComplete?.call();
  }
}
