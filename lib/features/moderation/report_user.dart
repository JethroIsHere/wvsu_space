// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wvsu_space/utils/app_colors.dart';

class ReportUserScreen extends StatefulWidget {
  const ReportUserScreen({super.key});

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reportedNickCtl = TextEditingController();
  final _detailsCtl = TextEditingController();
  String _reason = 'abuse';
  bool _submitting = false;
  // Autocomplete state
  Timer? _debounce;
  List<Map<String, String>> _suggestions = [];
  String? _selectedUserId;

  @override
  void dispose() {
    _debounce?.cancel();
    _reportedNickCtl.removeListener(_onReportedNickChanged);
    _reportedNickCtl.dispose();
    _detailsCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reportedNickCtl.addListener(_onReportedNickChanged);
  }

  void _onReportedNickChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _performSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final qLower = q.trim().toLowerCase();
    try {
      // Use a prefix range search on nicknameLower if available
      final start = qLower;
      final end = '$qLower\uf8ff';
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('nicknameLower', isGreaterThanOrEqualTo: start)
          .where('nicknameLower', isLessThanOrEqualTo: end)
          .orderBy('nicknameLower')
          .limit(6)
          .get();
      final results = <Map<String, String>>[];
      for (final d in snap.docs) {
        final data = d.data();
        final nickname = (data['nickname'] as String?) ?? '';
        results.add({'id': d.id, 'nickname': nickname});
      }
      if (mounted) setState(() => _suggestions = results);
    } catch (e) {
      debugPrint('Autocomplete search failed: $e');
      if (mounted) setState(() => _suggestions = []);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final reporterUid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final reporterNick = FirebaseAuth.instance.currentUser?.displayName ?? '';
      final reportedNick = _reportedNickCtl.text.trim();
      final details = _detailsCtl.text.trim();

      // Use explicitly selected UID if available, otherwise try to resolve by exact lookup.
      String? reportedUid = _selectedUserId;
      if (reportedUid == null) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('users')
              .where('nickname', isEqualTo: reportedNick)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            reportedUid = q.docs.first.id;
          } else {
            final q2 = await FirebaseFirestore.instance
                .collection('users')
                .where('nicknameLower', isEqualTo: reportedNick.toLowerCase())
                .limit(1)
                .get();
            if (q2.docs.isNotEmpty) reportedUid = q2.docs.first.id;
          }
        } catch (e) {
          debugPrint('User lookup failed: $e');
        }
      }

      final bool targetResolved = reportedUid != null && reportedUid.isNotEmpty;

      // Require that the reported nickname resolve to an existing user.
      if (!targetResolved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No user found with that nickname — please verify the nickname or select from suggestions.'),
            ),
          );
          setState(() => _submitting = false);
        }
        return;
      }

      await FirebaseFirestore.instance.collection('user_reports').add({
        'reportedUserId': reportedUid,
        'reportedNickname': reportedNick,
        'targetResolved': true,
        'reporterUid': reporterUid,
        'reporterNickname': reporterNick,
        'reason': _reason,
        'details': details,
        'createdAt': Timestamp.now(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(targetResolved
                ? 'Report submitted — thank you.'
                : 'No exact user found — report saved for admin review.'),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Failed to submit report: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report a user',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BrandColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Use this form to report users who abuse Vibe Rooms or otherwise violate our community guidelines. Provide the user nickname and as much detail as possible.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _reportedNickCtl,
                        decoration: const InputDecoration(
                          labelText: 'Report user nickname',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please provide the report user nickname'
                            : null,
                        onChanged: (v) {
                          _selectedUserId = null;
                          _debounce?.cancel();
                          _debounce =
                              Timer(const Duration(milliseconds: 300), () {
                            _performSearch(v);
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_suggestions.isNotEmpty) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                title: Text(s['nickname'] ?? ''),
                                onTap: () {
                                  _selectedUserId = s['id'];
                                  _reportedNickCtl.text = s['nickname'] ?? '';
                                  setState(() => _suggestions = []);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Show reasons as full visible options to avoid truncation
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              title:
                                  const Text('Abusive language / harassment'),
                              value: 'abuse',
                              groupValue: _reason,
                              onChanged: (v) =>
                                  setState(() => _reason = v ?? 'abuse'),
                            ),
                            RadioListTile<String>(
                              title: const Text('Spam / spammy behavior'),
                              value: 'spam',
                              groupValue: _reason,
                              onChanged: (v) =>
                                  setState(() => _reason = v ?? 'spam'),
                            ),
                            RadioListTile<String>(
                              title: const Text('Inappropriate content'),
                              value: 'inappropriate',
                              groupValue: _reason,
                              onChanged: (v) => setState(
                                  () => _reason = v ?? 'inappropriate'),
                            ),
                            RadioListTile<String>(
                              title: const Text('Other'),
                              value: 'other',
                              groupValue: _reason,
                              onChanged: (v) =>
                                  setState(() => _reason = v ?? 'other'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _detailsCtl,
                        decoration: const InputDecoration(
                          labelText: 'Details (what happened)',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: (_submitting ||
                                _reportedNickCtl.text.trim().isEmpty)
                            ? null
                            : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.appBlue,
                          foregroundColor: Colors.white,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white)))
                            : const Text('Submit Report'),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
