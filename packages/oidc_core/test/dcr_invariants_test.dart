@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

/// The two countable invariants of the manager-level Dynamic Client
/// Registration design, asserted MECHANICALLY against the source.
///
/// The design's central claim is that the recurring "a durable guard is
/// destroyed or reset by the very action it gates" defect is not merely bounded
/// here but UNSTATEABLE. That claim rests on two facts, and both are countable:
///
///  1. There is exactly ONE `store` write call site and exactly ONE `store`
///     removal call site for the registration key (plus exactly one read).
///  2. There are ZERO read-modify-write sequences on registration state: no
///     member both reads and writes the record, and the writer never consults
///     the store at all.
///
/// Together they are why [OidcStore] having no compare-and-set primitive
/// (`state_store.dart` is `getMany` / `setMany` / `removeMany`, no CAS) is not a
/// hazard: every store anomaly — a torn write, an unreadable record, two racing
/// managers, a locked keychain — can only replace one whole immutable record
/// with another whole immutable record, or degrade to a cache miss. It can
/// never corrupt a counter, clear a latch, or half-apply an update, because
/// there is no counter, latch or update.
///
/// These are source-reading tests on purpose. A behavioural test can only
/// observe the sequences a test happens to drive; counting call sites fails the
/// suite the moment a future change reintroduces the shape, whether or not any
/// test exercises it.
const _sourcePath = 'lib/src/managers/user_manager_base.dart';

/// The `OidcStore` operations that mutate or read a key.
const _writeOps = {'set', 'setMany'};
const _removeOps = {'remove', 'removeMany'};
const _readOps = {'get', 'getMany'};

final _storeCallPattern = RegExp(
  r'\bstore\s*\.\s*(setMany|removeMany|getMany|set|remove|get)\b\s*\(',
);

/// A line that opens a class member: exactly two spaces of indent followed by
/// something that is not a comment. `dart format` guarantees this shape.
final _memberStartPattern = RegExp('^  [A-Za-z@_]');

/// One `store.<op>(...)` call found in the source.
typedef _StoreCall = ({String op, int line, String member, String memberBody});

/// Every `store.<op>(...)` call in [source], each tagged with the class member
/// that contains it.
List<_StoreCall> _storeCalls(String source) {
  final lines = source.split('\n');
  // Index of every member-declaration line, so a call can be attributed.
  final memberStarts = <int>[
    for (var i = 0; i < lines.length; i++)
      if (_memberStartPattern.hasMatch(lines[i])) i,
  ];

  String memberBodyAt(int startIndex) {
    final buffer = <String>[];
    for (var i = startIndex; i < lines.length; i++) {
      buffer.add(lines[i]);
      // A member's body closes at a brace on the class's own indent, or the
      // declaration is a single-line expression member.
      if (i > startIndex && lines[i] == '  }') {
        break;
      }
      if (i > startIndex && _memberStartPattern.hasMatch(lines[i])) {
        buffer.removeLast();
        break;
      }
    }
    return buffer.join('\n');
  }

  final calls = <_StoreCall>[];
  for (final match in _storeCallPattern.allMatches(source)) {
    final line = '\n'.allMatches(source.substring(0, match.start)).length;
    final startIndex = memberStarts.lastWhere(
      (i) => i <= line,
      orElse: () => 0,
    );
    calls.add((
      op: match.group(1)!,
      line: line + 1,
      member: lines[startIndex].trim(),
      memberBody: memberBodyAt(startIndex),
    ));
  }
  return calls;
}

/// The calls that touch the persisted client registration.
///
/// The registration key can only be built by `clientRegistrationStoreKey`, a
/// fact the `clientRegistrationKeyPrefix` test below pins, so a member that
/// never calls it cannot be addressing the registration.
bool _touchesRegistration(_StoreCall call) =>
    call.memberBody.contains('clientRegistrationStoreKey(');

void main() {
  final source = File(_sourcePath).readAsStringSync();
  final calls = _storeCalls(source);
  final registrationCalls = calls.where(_touchesRegistration).toList();

  group('DCR invariant 1: one write site, one removal site', () {
    test(
      'the registration key can ONLY be built by clientRegistrationStoreKey — '
      'the prefix appears nowhere else that could address it',
      () {
        // Three permitted mentions and no more: the declaration itself, the
        // single use inside `clientRegistrationStoreKey`, and `forgetUser`'s
        // preserve-list (which reads the prefix to SPARE the key, never to
        // address it). A fourth would mean some other site can compute the key
        // and slip past every count below.
        expect(
          'clientRegistrationKeyPrefix'.allMatches(source).length,
          3,
          reason:
              'A new mention of clientRegistrationKeyPrefix can build the '
              'registration key without going through clientRegistrationStoreKey, '
              'which would make the call-site counts in this file blind to it.',
        );
      },
    );

    test('exactly ONE store write of the registration key', () {
      final writes = registrationCalls
          .where((c) => _writeOps.contains(c.op))
          .toList();
      expect(
        writes.map((c) => '${c.op} at line ${c.line} in "${c.member}"'),
        hasLength(1),
        reason:
            'Every registration write must go through the single persist '
            'method. A second write site is a second place where the record '
            'can be composed, and therefore a place a read-modify-write can '
            'grow back.',
      );
    });

    test('exactly ONE store removal of the registration key', () {
      final removals = registrationCalls
          .where((c) => _removeOps.contains(c.op))
          .toList();
      expect(
        removals.map((c) => '${c.op} at line ${c.line} in "${c.member}"'),
        hasLength(1),
        reason:
            'The only deletion may be the app-invoked forgetClientRegistration. '
            'A removal on any failure path is the discard-before-replace defect: '
            'it destroys the only copy of the client_id and of the RFC 7592 §3 '
            'registration_access_token before a replacement exists.',
      );
      expect(
        removals.single.member,
        contains('forgetClientRegistration'),
        reason: 'the one removal must be the explicit app-facing operation',
      );
    });

    test('exactly ONE store read of the registration key', () {
      final reads = registrationCalls
          .where((c) => _readOps.contains(c.op))
          .toList();
      expect(
        reads.map((c) => '${c.op} at line ${c.line} in "${c.member}"'),
        hasLength(1),
      );
    });
  });

  group('DCR invariant 2: zero read-modify-write on registration state', () {
    test(
      'the read, the write and the removal are in three DIFFERENT members',
      () {
        final members = registrationCalls.map((c) => c.member).toSet();
        expect(
          registrationCalls,
          hasLength(3),
          reason: 'exactly one read + one write + one removal',
        );
        expect(
          members,
          hasLength(3),
          reason:
              'A member that both reads and writes the registration key IS a '
              'read-modify-write, whether or not any test drives the interleaving '
              'that breaks it. Compose the new record from values already in '
              'hand instead.',
        );
      },
    );

    test('the writer never consults the store', () {
      final write = registrationCalls.singleWhere(
        (c) => _writeOps.contains(c.op),
      );
      final reads = _storeCallPattern
          .allMatches(write.memberBody)
          .where((m) => _readOps.contains(m.group(1)));
      expect(
        reads,
        isEmpty,
        reason:
            'The persisted record must be composed from the arguments the '
            'caller already holds. Reading the current value to merge onto it '
            'is the lost-update shape that no CAS-free OidcStore can make safe.',
      );
    });

    test('the reader never mutates the store', () {
      final read = registrationCalls.singleWhere(
        (c) => _readOps.contains(c.op),
      );
      final mutations = _storeCallPattern
          .allMatches(read.memberBody)
          .where(
            (m) =>
                _writeOps.contains(m.group(1)) ||
                _removeOps.contains(m.group(1)),
          );
      expect(
        mutations,
        isEmpty,
        reason:
            'Reading is not a decision. An unreadable, unparseable or '
            'unconvertible record must degrade to a cache miss that leaves the '
            'key exactly as it was — an unreadable store is not an empty store.',
      );
    });
  });

  group('DCR: the persisted record carries no durable control state', () {
    test('the record has exactly two members, and neither is a measure', () {
      final record =
          jsonDecode(
                OidcUserManagerBase.encodeClientRegistrationRecord(
                  OidcClientRegistrationResponse.fromJson(const {
                    'client_id': 'c1',
                    'client_secret': 's1',
                  }),
                  fingerprint: 'fp',
                ),
              )
              as Map<String, dynamic>;

      expect(record.keys.toSet(), {'registration', 'registered_for'});
      expect(record['registered_for'], 'fp');
      expect(
        (record['registration']! as Map<String, dynamic>)['client_id'],
        'c1',
      );

      // Nothing in the record may be a counter, latch, verdict, generation or
      // ledger: those are exactly the durable measures that the action they
      // gate can destroy or reset, which is the defect this design exists to
      // make unstateable. `registration` is the OP's own response document and
      // `registered_for` is a digest of the request it was issued for — a
      // digest of the material the action would change, never of the action.
      final forbidden = RegExp(
        'attempt|count|generation|epoch|retry|budget|latch|verdict|ledger|'
        'terminal|orphan|rotation|reject',
        caseSensitive: false,
      );
      expect(record.keys.where(forbidden.hasMatch), isEmpty);
    });
  });
}
