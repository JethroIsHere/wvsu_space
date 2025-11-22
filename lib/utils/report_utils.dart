// Utilities: fill missing reporter and reported nicknames when available.
// Ensure the `reporterNickname` field exists when a value is provided.
Map<String, dynamic> ensureReporterNickname(
  Map<String, dynamic> report,
  String? reporterNickname,
) {
  final out = Map<String, dynamic>.from(report);
  final rn = (report['reporterNickname'] as String?)?.trim();
  if ((rn == null || rn.isEmpty) &&
      reporterNickname != null &&
      reporterNickname.isNotEmpty) {
    out['reporterNickname'] = reporterNickname;
  }
  return out;
}

// Ensure the `reportedNickname` field exists when a value is provided.
// Since the UID is not used to search, the nickname is used as it is visible in the vibe rooms
// so it is valid to be used to report a user.
Map<String, dynamic> ensureReportedNickname(
  Map<String, dynamic> report,
  String? reportedNickname,
) {
  final out = Map<String, dynamic>.from(report);
  final rn = (report['reportedNickname'] as String?)?.trim();
  if ((rn == null || rn.isEmpty) &&
      reportedNickname != null &&
      reportedNickname.isNotEmpty) {
    out['reportedNickname'] = reportedNickname;
  }
  return out;
}
