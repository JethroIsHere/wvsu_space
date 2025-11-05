import 'package:flutter_test/flutter_test.dart';
import 'package:wvsu_space/utils/report_utils.dart';

void main() {
  test('ensureReporterNickname sets when missing', () {
    final rpt = {'reporterId': 'u1'};
    final out = ensureReporterNickname(rpt, 'Alice');
    expect(out['reporterNickname'], 'Alice');
  });

  test('ensureReporterNickname preserves existing', () {
    final rpt = {'reporterId': 'u1', 'reporterNickname': 'Existing'};
    final out = ensureReporterNickname(rpt, 'Alice');
    expect(out['reporterNickname'], 'Existing');
  });

  test('ensureReportedNickname sets when missing', () {
    final rpt = {'reportedUserId': 'u2'};
    final out = ensureReportedNickname(rpt, 'Bob');
    expect(out['reportedNickname'], 'Bob');
  });
}
