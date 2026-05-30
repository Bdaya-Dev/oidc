// Regenerates the Pigeon native transport with ZERO manual steps.
//
// Usage (from the repo root):
//   melos run generate:native
//   # or: dart run tool/generate_native.dart
//
// From the single schema
// `packages/oidc_platform_interface/pigeons/oidc_native.dart` it produces:
//   - Dart:   packages/oidc_platform_interface/lib/src/oidc_native.g.dart
//   - Kotlin: packages/oidc_android/.../com/bdayadev/oidc/OidcNative.g.kt
//   - Swift:  packages/oidc_darwin/.../Sources/oidc_darwin/OidcNative.g.swift
//
// Pigeon emits a single platform-guarded Swift file
// (`#if os(iOS) ... #elseif os(macOS) ...`) into the unified `oidc_darwin`
// package, so one generated file serves both Apple platforms — there is
// nothing to copy or hand-edit.
//
// Pigeon (26.x) needs `analyzer >=10`, which conflicts with the pub-workspace
// resolution (`copy_with_extension_gen` caps analyzer lower), so it is run as a
// pinned *global* tool rather than a workspace dev-dependency. The activation
// is idempotent and performed here automatically (mirroring how melos.yaml
// already provisions `coverage` / `combine_coverage`).

import 'dart:io';

const _pigeonVersion = '26.3.4';

Future<void> main() async {
  // melos scripts and `dart run` both execute from the repo root.
  final root = Directory.current.path;
  final platformInterface = Directory('$root/packages/oidc_platform_interface');
  if (!platformInterface.existsSync()) {
    _fail(
      'Could not find packages/oidc_platform_interface. '
      'Run from the repo root: `melos run generate:native`.',
    );
  }

  // 1. Pin + activate Pigeon as a global tool (idempotent).
  await _run('dart', ['pub', 'global', 'activate', 'pigeon', _pigeonVersion]);

  // 2. Generate Dart + Kotlin + darwin Swift. Output paths (and the Kotlin
  //    package) come from the schema's @ConfigurePigeon block, which Pigeon
  //    resolves relative to its working directory. The darwin Swift is a single
  //    platform-guarded file shared by iOS and macOS (`sharedDarwinSource`), so
  //    there is no copy step.
  await _run('dart', [
    'pub',
    'global',
    'run',
    'pigeon',
    '--input',
    'pigeons/oidc_native.dart',
  ], workingDirectory: platformInterface.path);

  final darwinSwift = File(
    '$root/packages/oidc_darwin/darwin/oidc_darwin/Sources/oidc_darwin/'
    'OidcNative.g.swift',
  );
  if (!darwinSwift.existsSync()) {
    _fail('Expected generated Swift not found at ${darwinSwift.path}.');
  }

  stdout.writeln('\n[OK] Pigeon native transport regenerated (3 outputs).');
}

Future<void> _run(
  String executable,
  List<String> args, {
  String? workingDirectory,
}) async {
  stdout.writeln(
    '\$ $executable ${args.join(' ')}'
    '${workingDirectory != null ? '   (in $workingDirectory)' : ''}',
  );
  final process = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
    // `dart` resolves to dart.bat on Windows; a shell makes that transparent.
    runInShell: true,
  );
  final code = await process.exitCode;
  if (code != 0) {
    _fail('Command failed (exit $code): $executable ${args.join(' ')}');
  }
}

Never _fail(String message) {
  stderr.writeln('generate_native: $message');
  exit(1);
}
