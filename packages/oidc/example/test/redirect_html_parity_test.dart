@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The web conformance job serves THIS app's `web/redirect.html`, but the test
// that actually executes the page -- loading it in a browser and asserting it
// relays the URL fragment --
// (`packages/oidc_web_core/test/redirect_html_fragment_test.dart`) runs inside
// `oidc_web_core` and can only reach that package's own copy.
//
// The copies are duplicated by hand: `redirect.html` is a template users are
// told to copy into their app ("If you upgrade the package you should RE-COPY
// this file", redirect.html:18), so the example apps hold copies too. Without
// this check the browser test proves a property of a file the web job never
// serves, and a fragment regression in the served copy would show up only as
// two conformance profiles silently timing out in CI -- the exact failure this
// whole change exists to make impossible.

File _resolve(String relative) {
  // `flutter test` runs with the package root as cwd.
  final file = File(relative);
  if (file.existsSync()) {
    return file;
  }
  fail(
    'Could not find $relative from ${Directory.current.path}. '
    'If the layout moved, update this test rather than deleting it: it is '
    'what makes the browser-side fragment test apply to the file CI serves.',
  );
}

void main() {
  test('the served redirect.html is identical to the one the browser test '
      'executes', () {
    final served = _resolve('web/redirect.html');
    final tested = _resolve('../../oidc_web_core/example/web/redirect.html');

    expect(
      served.readAsStringSync(),
      tested.readAsStringSync(),
      reason:
          'packages/oidc/example/web/redirect.html (served by the web '
          'conformance job) has drifted from '
          'packages/oidc_web_core/example/web/redirect.html (the copy executed '
          'by redirect_html_fragment_test.dart). Re-copy the template so the '
          'fragment-relay guarantee still covers what CI runs.',
    );
  });
}
