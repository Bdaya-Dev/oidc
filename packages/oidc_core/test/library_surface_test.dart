// Ensures every part of the public barrel (`oidc_core.dart`) is actually
// exercised at least once, so coverage tooling loads it even for symbols
// that no other test happens to touch. `OidcPushedAuthorizationRequest` in
// particular is a marker type with no fields, so nothing in the rest of the
// suite ever constructs it even though the barrel exports it transitively.
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('oidc_core library surface', () {
    test(
      'OidcPushedAuthorizationRequest is a constructible, non-canonicalized '
      'marker type',
      () {
        // See https://datatracker.ietf.org/doc/html/rfc9126 - this type
        // documents the PAR request shape; today it carries no fields, but
        // constructing it proves the barrel export resolves to a real,
        // instantiable class (not an unresolved forward reference), and
        // since the constructor isn't `const`, two separate calls must
        // allocate two distinct instances rather than one canonicalized
        // value.
        final a = OidcPushedAuthorizationRequest();
        final b = OidcPushedAuthorizationRequest();
        expect(a.runtimeType, OidcPushedAuthorizationRequest);
        expect(identical(a, b), isFalse);
      },
    );

    test(
      'OidcUserInfoAccessTokenLocations has the two RFC-documented values',
      () {
        expect(
          OidcUserInfoAccessTokenLocations.values,
          const [
            OidcUserInfoAccessTokenLocations.authorizationHeader,
            OidcUserInfoAccessTokenLocations.formParameter,
          ],
        );
      },
    );
  });
}
