// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../router/app_router.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final colorScheme = Theme.of(context).colorScheme; // not currently used

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: _checkIsAdmin(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data != true) {
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
            // User is admin — render dashboard body
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  decoration: BoxDecoration(color: Colors.amber.shade600),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Dashboard',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 26,
                                  ),
                            ),
                            Text(
                              _fmtNow(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              tooltip: 'Settings',
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.black87,
                              ),
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRouter.adminSettings,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              tooltip: 'Show token claims',
                              icon: const Icon(
                                Icons.verified_user_outlined,
                                color: Colors.black87,
                              ),
                              onPressed: () => _showTokenClaims(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),

                // Quick actions list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      const _ReportsTile(),
                      const SizedBox(height: 12),
                      _NavTile(
                        icon: Icons.manage_accounts_outlined,
                        color: Colors.blue,
                        title: 'User Management',
                        subtitle: 'Search & manage users',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRouter.adminUserManagement,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _NavTile(
                        icon: Icons.feed_outlined,
                        color: Colors.orange,
                        title: 'Logs & Appeals',
                        subtitle: 'View mod actions & appeals',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRouter.adminLogsAppeals,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _CommunityHealthTile(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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

  Future<void> _showTokenClaims(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final dialogContext = navigator.context;
    if (user == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }
    try {
      final t = await user.getIdTokenResult(true);
      final claims = t.claims ?? {};

      // Use a context captured synchronously above to avoid using the
      // original BuildContext across the async gap (satisfies linter).
      showDialog<void>(
        context: dialogContext,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.verified_user, color: Colors.amber.shade700),
              const SizedBox(width: 12),
              const Text('Account Details'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClaimSection(
                    ctx,
                    'Authentication',
                    Icons.account_circle,
                    [
                      _buildClaimRow('Email', claims['email'] ?? 'N/A'),
                      _buildClaimRow(
                        'User ID',
                        claims['user_id'] ?? 'N/A',
                        monospace: true,
                      ),
                      _buildClaimRow(
                        'Email Verified',
                        claims['email_verified'] == true ? '✓ Yes' : '✗ No',
                        valueColor: claims['email_verified'] == true
                            ? Colors.green
                            : Colors.orange,
                      ),
                      _buildClaimRow(
                        'Sign-in Provider',
                        claims['sign_in_provider'] ?? 'N/A',
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildClaimSection(ctx, 'Permissions', Icons.shield, [
                    _buildClaimRow(
                      'Admin Access',
                      claims['admin'] == true ? '✓ Granted' : '✗ None',
                      valueColor:
                          claims['admin'] == true ? Colors.green : Colors.grey,
                    ),
                  ]),
                  const Divider(height: 24),
                  _buildClaimSection(ctx, 'Session Info', Icons.schedule, [
                    _buildClaimRow('Project', claims['aud'] ?? 'N/A'),
                    _buildClaimRow(
                      'Issued At',
                      _formatTimestamp(claims['iat']),
                    ),
                    _buildClaimRow(
                      'Expires At',
                      _formatTimestamp(claims['exp']),
                    ),
                    _buildClaimRow(
                      'Auth Time',
                      _formatTimestamp(claims['auth_time']),
                    ),
                    _buildClaimRow('Issuer', _formatIssuer(claims['iss'])),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to read token claims: $e')),
      );
    }
  }

  Widget _buildClaimSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.black54),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildClaimRow(
    String label,
    String value, {
    bool monospace = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontFamily: monospace ? 'Courier' : null,
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final seconds =
          timestamp is int ? timestamp : int.tryParse(timestamp.toString());
      if (seconds == null) return 'Invalid';

      final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      final now = DateTime.now();
      final diff = date.difference(now);

      // Format: "Nov 9, 2025 at 3:45 PM"
      final formattedDate =
          '${_monthName(date.month)} ${date.day}, ${date.year} at ${_formatTime(date)}';

      // Add relative time for expiry
      if (diff.isNegative) {
        return '$formattedDate (expired)';
      } else if (diff.inHours < 24) {
        return '$formattedDate (in ${diff.inHours}h)';
      } else {
        return formattedDate;
      }
    } catch (e) {
      return 'Invalid';
    }
  }

  String _monthName(int month) {
    const months = [
      '',
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
      'Dec',
    ];
    return months[month];
  }

  String _formatTime(DateTime date) {
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatIssuer(dynamic issuer) {
    if (issuer == null) return 'N/A';
    final issuerStr = issuer.toString();
    // Extract just the domain from the issuer URL
    final uri = Uri.tryParse(issuerStr);
    if (uri != null) {
      return uri.host.replaceAll('securetoken.google.com', 'Firebase Auth');
    }
    return issuerStr;
  }

  // _notImplemented helper removed after adding Logs & Appeals route
}

String _fmtNow() {
  final now = DateTime.now();
  final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final m = now.minute.toString().padLeft(2, '0');
  final ap = now.hour >= 12 ? 'PM' : 'AM';
  return '${now.month}/${now.day}/${now.year} ${h.toString().padLeft(2, '0')}:$m$ap';
}

class _ReportsTile extends StatelessWidget {
  const _ReportsTile();
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('user_reports')
        .where('status', isEqualTo: 'pending');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int pending = 0;
        if (snapshot.hasData) pending = snapshot.data!.docs.length;
        return _NavTile(
          icon: Icons.report_gmailerrorred_outlined,
          color: Colors.red,
          title: 'Review Reports',
          subtitle: '$pending pending',
          onTap: () => Navigator.pushNamed(context, AppRouter.adminReports),
        );
      },
    );
  }
}

class _CommunityHealthTile extends StatelessWidget {
  const _CommunityHealthTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        double avgStanding = 0.0;
        int userCount = 0;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          double totalStanding = 0.0;
          userCount = 0;

          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null && data.containsKey('standing')) {
              final standing = data['standing'];
              final standingValue = standing is num ? standing.toDouble() : 0.0;
              totalStanding += standingValue;
              userCount++;
            }
          }

          if (userCount > 0) {
            avgStanding = totalStanding / userCount;
          }
        }

        // Format to 1 decimal place
        final valueText = '${avgStanding.toStringAsFixed(1)} /100';

        // Color based on health: green if >= 80, yellow if >= 60, orange if >= 40, red otherwise
        Color healthColor = Colors.green;
        if (avgStanding < 40) {
          healthColor = Colors.red;
        } else if (avgStanding < 60) {
          healthColor = Colors.orange;
        } else if (avgStanding < 80) {
          healthColor = Colors.yellow.shade700;
        }

        return _MetricTile(
          label: 'Community Health',
          valueText: valueText,
          color: healthColor,
          subtitle: 'Average standing ($userCount users)',
        );
      },
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _NavTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
                child: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String valueText;
  final String subtitle;
  final Color color;
  const _MetricTile({
    required this.label,
    required this.valueText,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black),
                ),
              ],
            ),
          ),
          // Split the value so the score is green and the max is muted
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(
                context,
              ).style.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
              children: [
                TextSpan(
                  text: valueText.split(' ').first,
                  style: TextStyle(color: color),
                ),
                TextSpan(
                  text: ' ${valueText.substring(valueText.indexOf('/'))}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
