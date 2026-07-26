@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Every option on `OidcNativeOptionsAndroid` is serialized by
// `platform_options_serialization_test.dart`, which asserts the JSON SHAPE and
// the round-trip. A shape assertion passes whether or not anything on the
// native side ever reads the value, so nine options shipped documented as
// working while `OidcPlugin.kt` read only two of them.
//
// This guard closes that: an option the Dart API documents as working must be
// named somewhere in the Android plugin. It cannot prove the option has the
// RIGHT effect -- `OidcPluginOptionsTest` (Kotlin/Robolectric) asserts the
// launched Intent for that -- but it does make "declared and never wired"
// impossible to add silently.
//
// An option that native cannot or does not yet honour is legitimate, but the
// exemption has to be deliberate: name it here with the reason. A word-match on
// the dartdoc is not enough -- `allowInsecureConnections` discloses honestly
// without using the word "Reserved", and a heuristic that missed that would
// report it as a defect while a differently-worded real defect slipped through.
//
// Adding an option to this map is the reviewable act. Adding one to the model
// and forgetting it is not possible.
//
// SCOPE, before anyone copies this to another platform: it checks ONE native
// file because Android handles no option in Dart -- `oidc_android.dart` passes
// `options.android.toJson()` straight to Pigeon and reads nothing itself. That
// is not true elsewhere. `oidc_darwin` implements `navigationMode` and its three
// response bodies entirely in Dart (`oidc_darwin.dart`), so the same check
// pointed at `OidcPlugin.swift` alone reports four working options as inert.
// Any port must cover every layer that can consume an option, not just the
// native one.
const _exempt = <String, String>{
  'preferredBrowserPackages':
      'dartdoc: "Reserved - not yet wired natively"; the launch does not pin a '
          'package via setPackage yet.',
  'warmup':
      'dartdoc: "Reserved - not yet wired natively"; no service binding or '
          'mayLaunchUrl is performed yet.',
  'allowInsecureConnections':
      'dartdoc: "No effect on the default Custom Tabs transport" - the browser, '
          'not the app, governs TLS, so it cannot be honoured there.',
};

File _repoFile(String relative) {
  // Tests run with CWD = the package root.
  final f = File(relative);
  if (!f.existsSync()) {
    fail('expected $relative to exist relative to ${Directory.current.path}');
  }
  return f;
}

/// Field name -> dartdoc, for every option on `OidcNativeOptionsAndroid`.
Map<String, String> _declaredAndroidOptions() {
  final source = _repoFile(
    '../oidc_core/lib/src/models/settings/platform_options.dart',
  ).readAsStringSync();

  final start = source.indexOf('class OidcNativeOptionsAndroid');
  expect(start, isNot(-1), reason: 'OidcNativeOptionsAndroid must exist');
  final body = source.substring(start, source.indexOf('\n}', start));

  // A run of `///` lines immediately followed by a `final <type> <name>;`.
  final pattern = RegExp(
    r'((?:[ \t]*///[^\n]*\n)+)[ \t]*final\s+[\w<>?,\s]+?\s+(\w+);',
    multiLine: true,
  );
  return {
    for (final m in pattern.allMatches(body)) m.group(2)!: m.group(1)!,
  };
}

void main() {
  test(
    'every Android option documented as working is read by the native plugin',
    () {
      final declared = _declaredAndroidOptions();
      expect(
        declared,
        isNotEmpty,
        reason:
            'the option parser found nothing; it has drifted from the model',
      );

      final plugin = _repoFile(
        'android/src/main/kotlin/com/bdayadev/oidc/OidcPlugin.kt',
      ).readAsStringSync();
      // Comments mention option names while wiring none of them, so strip them
      // before asking whether the plugin actually references a name.
      final code = plugin
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//[^\n]*'), '');

      final unwired = <String>[];
      for (final entry in declared.entries) {
        if (_exempt.containsKey(entry.key)) continue;
        if (!code.contains(entry.key)) unwired.add(entry.key);
      }

      expect(
        unwired,
        isEmpty,
        reason:
            'these options are documented as working but never reach native. '
            'Wire them in OidcPlugin.kt, or add them to _exempt in this file '
            'with the dartdoc sentence that discloses the limitation.',
      );
    },
  );

  test('every exemption names a real option that still discloses its limit',
      () {
    final declared = _declaredAndroidOptions();

    for (final name in _exempt.keys) {
      expect(
        declared,
        contains(name),
        reason: 'stale exemption: $name is no longer an option on '
            'OidcNativeOptionsAndroid. Remove it from _exempt.',
      );
      // The dartdoc must still tell a reader the option does nothing. If the
      // disclosure is dropped, the exemption is silently lying on its behalf.
      expect(
        declared[name],
        anyOf(contains('Reserved'), contains('No effect')),
        reason: '$name is exempt here but its dartdoc no longer discloses the '
            'limitation, so the public API now reads as if it works.',
      );
    }
  });
}
