@TestOn('browser')
library;

import 'package:oidc_web_core/oidc_web_core.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Every one of the 75 fragment-mode conformance modules on web failed with the
// SAME opaque error and nothing else:
//
//   OidcException: The authentication flow timed out after 10 seconds without
//   a redirect., extra: {reason: flow_timeout}
//
// That is true of a popup the browser refused to open, a popup that opened and
// never navigated, a provider that rejected the request, and a user who walked
// away -- four different bugs wearing one message. The conformance run could
// not distinguish them, which is a large part of why the defect survived a
// whole session of investigation (web job 90242238007: 0/48 Hybrid and 0/27
// Implicit, with the suite recording no authorization request at all).
//
// The window itself answers the first fork. After `location.replace`, reading
// `location.href` on a window that navigated CROSS-ORIGIN throws a SecurityError
// -- the same-origin policy is the signal. A window still sitting on
// `about:blank` reads back fine, and means the navigation never happened.
void main() {
  web.HTMLIFrameElement makeFrame() {
    final frame = web.document.createElement('iframe') as web.HTMLIFrameElement;
    web.document.body!.append(frame);
    // A closure, not a tear-off: dart2js rejects tearing off an external
    // extension-type interop member ("Tear-offs of external extension type
    // interop member 'remove' are disallowed"), so the lint's preferred form
    // does not compile. Same reason as the addTearDown in
    // redirect_fragment_test.dart.
    // ignore: unnecessary_lambdas
    addTearDown(() => frame.remove());
    return frame;
  }

  group('the auth window is described, not just timed out', () {
    test('a window that never navigated is reported as such', () {
      final frame = makeFrame();
      final w = frame.contentWindow!;

      final description = OidcWebCore.describeAuthWindow(w);

      expect(
        description.toLowerCase(),
        contains('never navigated'),
        reason:
            'a window still on about:blank did not navigate; saying so is the '
            'difference between "the browser refused the popup" and "the '
            'provider refused the request"',
      );
      // The observed location is part of the message, so a future shape we do
      // not anticipate is still legible rather than bucketed into a guess.
      expect(description, contains('about:blank'));
    });

    test('the description never throws, whatever the window is doing', () {
      // It runs inside an error path. A probe that can itself throw would
      // replace the diagnosis with a second, worse failure.
      final frame = makeFrame();
      expect(
        () => OidcWebCore.describeAuthWindow(frame.contentWindow!),
        returnsNormally,
      );
    });
  });
}
