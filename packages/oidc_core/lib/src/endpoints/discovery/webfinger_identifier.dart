import 'package:meta/meta.dart';

/// The output of OpenID Connect Discovery 1.0 §2.1 Identifier Normalization.
@immutable
class OidcWebFingerIdentifier {
  ///
  const OidcWebFingerIdentifier({required this.resource, required this.host});

  /// §2.1.2: the normalized URI, verbatim (case preserved). This is the exact
  /// value of the RFC 7033 §4.1 `resource` query parameter.
  final String resource;

  /// §2.1.2: the WebFinger Host — `host [":" port]`, lower-cased, with any
  /// userinfo removed. Becomes the authority of the WebFinger request URL.
  final String host;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OidcWebFingerIdentifier &&
          other.resource == resource &&
          other.host == host);

  @override
  int get hashCode => Object.hash(resource, host);

  @override
  String toString() =>
      'OidcWebFingerIdentifier(resource: $resource, host: $host)';
}
