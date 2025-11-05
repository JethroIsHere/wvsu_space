// Small utility helpers for report documents
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

// Ensure reportedNickname is present when available
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
