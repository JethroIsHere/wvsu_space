import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationChecker {
  /// Check if user has unacknowledged warnings and show dialog
  static Future<void> checkAndShowNotifications(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      if (data == null) return;

      final warningCount = (data['warningCount'] as num?)?.toInt() ?? 0;
      final lastWarningAt = data['lastWarningAt'] as Timestamp?;
      final lastAcknowledgedAt =
          data['lastWarningAcknowledgedAt'] as Timestamp?;

      // Check if there are new warnings since last acknowledgment
      if (warningCount > 0 &&
          (lastAcknowledgedAt == null ||
              (lastWarningAt != null &&
                  lastWarningAt.millisecondsSinceEpoch >
                      lastAcknowledgedAt.millisecondsSinceEpoch))) {
        // Fetch recent notifications
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('warnings')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        if (!context.mounted) return;

        await _showNotificationDialog(
          context,
          warningCount,
          notificationsSnapshot.docs,
        );
      }
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    }
  }

  static Future<void> _showNotificationDialog(
    BuildContext context,
    int warningCount,
    List<QueryDocumentSnapshot> notifications,
  ) async {
    final shouldShowNotifications = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Account Warning')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have $warningCount warning${warningCount > 1 ? 's' : ''} on your account.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recent notifications:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...notifications.map((notification) {
                final data = notification.data() as Map<String, dynamic>;
                // Display only abstracted user-appropriate messages
                final message = data['message'] as String? ??
                    'You received a warning for violating Community Guidelines.';
                final category =
                    data['category'] as String? ?? 'Community Guidelines';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text(
                            category,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              if (warningCount >= 3)
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
                          'Multiple warnings may result in account suspension.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('View All Notifications'),
          ),
        ],
      ),
    );

    // Mark notifications as acknowledged
    await _acknowledgeNotifications();

    // Navigate to notifications page if requested
    if (shouldShowNotifications == true && context.mounted) {
      Navigator.pushNamed(context, '/notifications');
    }
  }

  static Future<void> _acknowledgeNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'lastWarningAcknowledgedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error acknowledging notifications: $e');
    }
  }

  /// Check if user is restricted due to suspension or warnings
  static Future<bool> isUserRestricted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      if (data == null) return false;

      // Check suspension
      final suspended = data['suspended'] as bool? ?? false;
      if (suspended) {
        final suspendedUntil = data['suspendedUntil'] as Timestamp?;
        if (suspendedUntil == null) {
          // Permanently suspended
          return true;
        }
        // Check if suspension expired
        if (suspendedUntil.toDate().isAfter(DateTime.now())) {
          return true;
        }
        // Suspension expired - clear it
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'suspended': false,
          'suspendedUntil': FieldValue.delete(),
        });
        return false;
      }

      // Check warning count
      final warningCount = (data['warningCount'] as num?)?.toInt() ?? 0;
      if (warningCount >= 5) {
        // Too many warnings - restrict features
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking user restriction: $e');
      return false;
    }
  }

  /// Check restriction and notify user if restricted
  static Future<bool> checkRestrictionAndNotify(BuildContext context) async {
    final restricted = await isUserRestricted();
    if (!restricted || !context.mounted) return restricted;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      if (data == null) return true;

      final suspended = data['suspended'] as bool? ?? false;
      final suspendedUntil = data['suspendedUntil'] as Timestamp?;
      final warningCount = (data['warningCount'] as num?)?.toInt() ?? 0;

      String message;
      if (suspended) {
        message = suspendedUntil == null
            ? 'Your account is permanently suspended due to violations of our Community Guidelines.'
            : 'Your account is suspended until ${_formatDate(suspendedUntil.toDate())}. This feature is unavailable during suspension.';
      } else {
        message =
            'You have $warningCount warnings. Some features are restricted.';
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.block, color: Colors.red),
                SizedBox(width: 12),
                Expanded(child: Text('Access Restricted')),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushNamed(context, '/notifications');
                },
                child: const Text('View Notifications'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error displaying restriction message: $e');
    }

    return restricted;
  }

  static String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
