import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

/// Reads a RFC 7033 map-of-strings member (`properties`, `titles`).
///
/// §4.4.3 allows a property VALUE to be `null`, so the map is `String?`-valued;
/// any non-string, non-null value is dropped rather than throwing, per §4.4's
/// "MUST ignore any unknown member" robustness posture.
Map<String, String?> _stringMap(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  final result = <String, String?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is String && (value == null || value is String)) {
      result[key] = value as String?;
    }
  }
  return result;
}

/// RFC 7033 §4.4 JSON Resource Descriptor (JRD).
///
/// Every getter is deliberately tolerant: §4.4 requires a client to "ignore any
/// unknown member and not treat the presence of an unknown member as an error",
/// and every member except a link's `rel` is OPTIONAL. A malformed member
/// therefore degrades to an empty/`null` value instead of aborting the parse.
class OidcWebFingerResponse extends JsonBasedResponse {
  ///
  const OidcWebFingerResponse({required super.src});

  ///
  factory OidcWebFingerResponse.fromJson(Map<String, dynamic> src) =>
      OidcWebFingerResponse(src: src);

  /// RFC 7033 §4.4.1. SHOULD be present; MAY differ from the request
  /// `resource`, and is deliberately NOT validated against it.
  String? get subject {
    final raw = src[OidcConstants_WebFinger_JRD.subject];
    return raw is String ? raw : null;
  }

  /// RFC 7033 §4.4.2. `const []` when absent or malformed.
  List<String> get aliases {
    final raw = src[OidcConstants_WebFinger_JRD.aliases];
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<String>().toList();
  }

  /// RFC 7033 §4.4.3. `const {}` when absent or malformed.
  Map<String, String?> get properties =>
      _stringMap(src[OidcConstants_WebFinger_JRD.properties]);

  /// RFC 7033 §4.4.4. `const []` when absent, not a list, or malformed;
  /// non-object elements are skipped.
  List<OidcWebFingerLink> get links {
    final raw = src[OidcConstants_WebFinger_JRD.links];
    if (raw is! List) {
      return const [];
    }
    return [
      // Tested as `is Map`, not `is Map<String, dynamic>`: only jsonDecode
      // hands back the latter. This is public API, and a JRD arriving from a
      // platform channel, `Map.from`, or a cache round-trip is
      // `Map<dynamic, dynamic>` -- against which the narrow test is false and
      // every well-formed link is silently dropped.
      for (final element in raw)
        if (element is Map)
          OidcWebFingerLink(
            src: element.map((k, v) => MapEntry(k.toString(), v)),
          ),
    ];
  }

  /// Client-side rel filter — MANDATORY, never optional: RFC 7033 §4.3 lets a
  /// server ignore the `rel` parameter and return every link ("If the resource
  /// does not support the 'rel' parameter, it MUST ignore the parameter and
  /// process the request as if no 'rel' parameter values were present").
  ///
  /// The comparison is exact and case-sensitive: the OIDC issuer rel is a URI
  /// compared as a string, not an RFC 8288 registered relation type.
  List<OidcWebFingerLink> linksWithRel(String rel) =>
      links.where((link) => link.rel == rel).toList();

  /// OIDC Discovery 1.0 §2: the Issuer location from the FIRST link whose
  /// `rel` equals [rel] and whose `href` is a valid Issuer location. `null`
  /// when no such link exists.
  ///
  /// A matching link whose `href` is absent or unparseable is SKIPPED and
  /// iteration continues, because RFC 7033 §4.4.4.3 makes `href` OPTIONAL — a
  /// spec-legal response can therefore carry a matching link with no target.
  /// §4.4.4 also states the array order MAY indicate an order of preference,
  /// which is why the first passing candidate wins.
  Uri? getIssuer({String rel = OidcConstants_WebFinger.relOpenIdIssuer}) {
    for (final link in linksWithRel(rel)) {
      final href = link.href;
      if (OidcWebFingerLink.isValidIssuerLocation(href)) {
        return href;
      }
    }
    return null;
  }
}

/// RFC 7033 §4.4.4 link relation object.
class OidcWebFingerLink extends JsonBasedResponse {
  ///
  const OidcWebFingerLink({required super.src});

  ///
  factory OidcWebFingerLink.fromJson(Map<String, dynamic> src) =>
      OidcWebFingerLink(src: src);

  /// §4.4.4.1 — the only REQUIRED member; `null` when absent/malformed.
  String? get rel {
    final raw = src[OidcConstants_WebFinger_Link.rel];
    return raw is String ? raw : null;
  }

  /// §4.4.4.2 OPTIONAL.
  String? get type {
    final raw = src[OidcConstants_WebFinger_Link.type];
    return raw is String ? raw : null;
  }

  /// §4.4.4.3 OPTIONAL. Parsed via [OidcInternalUtilities.tryParseUri], so a
  /// malformed value yields `null` instead of throwing.
  Uri? get href =>
      OidcInternalUtilities.tryParseUri(src[OidcConstants_WebFinger_Link.href]);

  /// §4.4.4.4 OPTIONAL.
  Map<String, String?> get titles =>
      _stringMap(src[OidcConstants_WebFinger_Link.titles]);

  /// §4.4.4.5 OPTIONAL.
  Map<String, String?> get properties =>
      _stringMap(src[OidcConstants_WebFinger_Link.properties]);

  /// OIDC Discovery 1.0 §2: an Issuer location "MUST be a URI `[RFC3986]` with
  /// a scheme component that MUST be https, a host component, and optionally,
  /// port and path components and no query or fragment components".
  static bool isValidIssuerLocation(Uri? href) =>
      href != null &&
      href.scheme == OidcConstants_WebFinger.httpsScheme &&
      href.host.isNotEmpty &&
      !href.hasQuery &&
      !href.hasFragment;
}
