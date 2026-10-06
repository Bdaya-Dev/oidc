import 'package:flutter_test/flutter_test.dart';

import '../integration_test/conformance/api.dart';

void main() {
  group('takeUnseenLogEntries', () {
    test('asks from one millisecond before the newest entry', () {
      final seen = <Object>{};
      final r = takeUnseenLogEntries([
        {'_id': 'a', 'time': 1000},
        {'_id': 'b', 'time': 1005},
      ], seen);
      expect(r.since, 1004);
      expect(r.fresh.map((e) => e['_id']), ['a', 'b']);
    });

    test(
      'an entry written later in the same millisecond is still delivered once',
      () {
        final seen = <Object>{};
        var r = takeUnseenLogEntries([
          {'_id': 'discovery', 'time': 2000},
        ], seen);
        // The suite returns `time > since`, so the next read (since=1999)
        // re-includes `discovery` plus `Setup Done` from the same millisecond.
        r = takeUnseenLogEntries(
          [
            {'_id': 'discovery', 'time': 2000},
            {'_id': 'done', 'msg': 'Setup Done', 'time': 2000},
          ],
          seen,
          since: r.since,
        );
        expect(r.fresh.map((e) => e['msg']), ['Setup Done']);
        expect(r.since, 1999);
      },
    );

    test('never moves since backwards for an out-of-order batch', () {
      final seen = <Object>{};
      final r = takeUnseenLogEntries(
        [
          {'_id': 'old', 'time': 10},
        ],
        seen,
        since: 500,
      );
      expect(r.since, 500);
    });
  });
}
