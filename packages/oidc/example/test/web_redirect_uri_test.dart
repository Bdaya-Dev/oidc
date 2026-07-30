import 'package:flutter_test/flutter_test.dart';
import 'package:oidc_example/web_redirect_uri.dart';

// The conformance harness registers a redirect_uri with the test plan
// (shared_e2e.dart passes it to prepareTestPlanRequest), and the app under test
// builds its own at runtime. Those were two independent code paths: the app
// resolved `redirect.html` against `Uri.base`, while the harness returned a
// hardcoded `http://localhost:22433/redirect.html`.
//
// They agreed only because CI happened to serve the app at exactly that origin.
// Nothing tested the agreement, so nothing could notice the coincidence -- and
// the moment the origin has to move, the registered URI and the one the app
// actually sends diverge, and the OP rejects the request as unregistered.
//
// The origin has to move. OpenID Connect Dynamic Client Registration 1.0
// section 2: "Web Clients using the OAuth Implicit Grant Type MUST only
// register URLs using the https scheme as redirect_uris; they MUST NOT use
// localhost as the hostname."
void main() {
  // The origin an OIDC-conformant web RP must be served from: https, and not
  // localhost. Both halves of the section 2 sentence.
  final conformantBase = Uri.parse('https://rp.oidc.test:22433/');

  group('resolveWebRedirectUri follows the serving origin', () {
    test('an https non-localhost origin is carried through', () {
      expect(
        resolveWebRedirectUri('redirect.html', base: conformantBase),
        Uri.parse('https://rp.oidc.test:22433/redirect.html'),
      );
    });

    test('the legacy http localhost origin still resolves', () {
      // The default local-development origin must keep working; this change is
      // about not hardcoding it, not about abandoning it.
      expect(
        resolveWebRedirectUri(
          'redirect.html',
          base: Uri.parse('http://localhost:22433/'),
        ),
        Uri.parse('http://localhost:22433/redirect.html'),
      );
    });

    test('a deep SPA route resolves against its directory, not the route', () {
      expect(
        resolveWebRedirectUri(
          'redirect.html',
          base: Uri.parse('https://rp.oidc.test:22433/app/secret-route'),
        ),
        Uri.parse('https://rp.oidc.test:22433/app/redirect.html'),
      );
    });

    test('query parameters are merged onto the resolved URI', () {
      // The front-channel logout URI is the same page with a marker query.
      expect(
        resolveWebRedirectUri(
          'redirect.html',
          base: conformantBase,
          queryParameters: {'requestType': 'front-channel-logout'},
        ),
        Uri.parse(
          'https://rp.oidc.test:22433/redirect.html'
          '?requestType=front-channel-logout',
        ),
      );
    });

    test('an absolute configured URI overrides the base', () {
      expect(
        resolveWebRedirectUri(
          'https://elsewhere.test/cb.html',
          base: conformantBase,
        ),
        Uri.parse('https://elsewhere.test/cb.html'),
      );
    });

    test('a non-http base is rejected by name, not by StateError', () {
      // On every non-web platform Uri.base is a file:// URI, and Uri.origin
      // throws a bare "Bad state: Origin is only applicable schemes http and
      // https" from dart:core -- a message that names neither this function nor
      // the caller that passed the wrong base. That is exactly what reached CI:
      // the front-channel logout URI was derived unconditionally, so all five
      // native conformance jobs died inside dart:core with no indication that
      // an origin-derived web URI was the cause.
      //
      // Resolving against a file:// base is never meaningful here, so refuse it
      // where the caller can see why.
      expect(
        () => resolveWebRedirectUri(
          'redirect.html',
          base: Uri.parse('file:///home/runner/work/oidc/example'),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('http'), contains('file')),
          ),
        ),
      );
    });

    test('an empty configured URI is rejected', () {
      expect(
        () => resolveWebRedirectUri('  ', base: conformantBase),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('the harness and the app cannot drift apart', () {
    // The regression lock. Before this existed the two derivations were
    // separate literals; re-introducing a second one breaks this test rather
    // than surfacing as an unregistered-redirect_uri failure against a live
    // provider, minutes into a conformance run.
    test('both derive the same redirect URI from one origin', () {
      expect(
        harnessWebRedirectUri(base: conformantBase),
        appWebRedirectUri(base: conformantBase),
      );
    });

    test('and neither is pinned to the old hardcoded origin', () {
      expect(
        harnessWebRedirectUri(base: conformantBase).toString(),
        isNot(contains('localhost')),
      );
    });
  });
}
