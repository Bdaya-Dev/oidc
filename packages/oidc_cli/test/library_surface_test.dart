@TestOn('vm')
library;

// `oidc_cli`'s public barrel (`lib/oidc_cli.dart`) carries only doc comments
// and has no `export` statements — this package ships an executable, not an
// importable library, so there is nothing to load from the barrel itself.
// This test instead exercises the real CLI-identity constants in
// `src/command_runner.dart`, which the rest of the suite covers only
// indirectly (through command_runner_test.dart's behavioral tests) without
// ever asserting them against their documented values.
import 'package:oidc_cli/src/command_runner.dart' as runner;
import 'package:test/test.dart';

void main() {
  group('oidc_cli library surface', () {
    test('the CLI identity constants match the published package name', () {
      expect(runner.executableName, 'oidc');
      expect(runner.packageName, 'oidc_cli');
      expect(
        runner.description,
        'A small provider-agnostic CLI for OpenID Connect (OIDC).',
      );
    });
  });
}
