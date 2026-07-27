import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';

class OidcInternalUtilities {
  static Future<http.Response> sendWithClient({
    required http.Client? client,
    required http.Request request,
  }) async {
    //
    final shouldDispose = client == null;
    client ??= http.Client();
    try {
      final res = await client.send(request).then(http.Response.fromStream);
      return res;
    } finally {
      if (shouldDispose) {
        client.close();
      }
    }
  }

  /// Converts a list of strings into a space-delimited string
  static String? joinSpaceDelimitedList(List<String>? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.join(' ');
  }

  static Object? readDurationSeconds(Map<dynamic, dynamic> p1, String p2) {
    final res = p1[p2];
    if (res == null) {
      return null;
    }
    if (res is int) {
      return res;
    }
    return int.tryParse(res.toString());
  }

  static Duration? durationFromJson(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is int) {
      return Duration(seconds: json);
    }
    final seconds = int.tryParse(json.toString());
    if (seconds == null) {
      return null;
    }
    return Duration(seconds: seconds);
  }

  static int? durationToJson(Duration? value) {
    return value?.inSeconds;
  }

  static List<String>? splitSpaceDelimitedStringNullable(Object? value) {
    if (value == null) {
      return null;
    }
    return splitSpaceDelimitedString(value);
  }

  static List<String> splitSpaceDelimitedString(Object? value) {
    if (value == null) {
      return [];
    }
    if (value is List) {
      return value.whereType<String>().toList();
    }
    if (value is String) {
      if (value.isEmpty) {
        return [];
      }
      return value.split(' ');
    }
    throw ArgumentError.value(
      value,
      'value',
      'parameter be null or List or String',
    );
  }

  static String? dateTimeToJson(DateTime? value) {
    if (value == null) {
      return null;
    }
    return value.toIso8601String();
  }

  static DateTime dateTimeFromJsonRequired(dynamic rawValue) {
    if (rawValue is String) {
      return DateTime.parse(rawValue);
    } else if (rawValue is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        rawValue,
        isUtc: true,
      );
    } else if (rawValue is DateTime) {
      return rawValue;
    }
    throw ArgumentError.value(rawValue, "Value can't be converted to DateTime");
  }

  static DateTime? dateTimeFromJson(dynamic rawValue) {
    if (rawValue == null) {
      return null;
    }
    return dateTimeFromJsonRequired(rawValue);
  }

  /// Tolerant parser for OPTIONAL `Uri` provider-metadata fields.
  ///
  /// Yields `null` instead of throwing on a malformed/non-string value so one
  /// bad OPTIONAL endpoint cannot abort the whole discovery parse
  /// (OIDC Discovery 1.0 §3 OPTIONAL fields / §4.3 robustness).
  ///
  /// Accepts an [Object] input (not `String`) on purpose so a non-string value
  /// no longer triggers the `as String` TypeError that the generated code would
  /// otherwise throw.
  static Uri? tryParseUri(Object? value) {
    if (value is! String) {
      return null; // also covers null and JSON numbers/objects
    }
    return Uri.tryParse(value); // never throws; null where Uri.parse would fail
  }

  static const commonConverters = <JsonConverter<dynamic, dynamic>>[
    OidcNumericDateConverter(),
    OidcDurationSecondsConverter(),
  ];

  static Map<String, Object> serializeQueryParameters(
    Map<String, Object?> input,
  ) {
    final result = <String, Object>{};
    for (final element in input.entries) {
      final k = element.key;
      final v = element.value;
      if (v == null) {
        continue;
      }
      if (v is Iterable) {
        result[k] = v.map((e) => e.toString()).toList();
      } else {
        result[k] = v.toString();
      }
    }
    return result;
  }
}

extension OidcDateTime on DateTime {
  int get secondsSinceEpoch => millisecondsSinceEpoch ~/ 1000;
  static DateTime fromSecondsSinceEpoch(int seconds) {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
}

/// Utilities for the Oidc spec
class OidcUtils {
  /// Drops trailing empty path segments (the encoding of a terminating `/`).
  ///
  /// OIDC Discovery 1.0 §4.1 / RFC 8414 §3.1 require any terminating `/` on the
  /// issuer to be removed before composing the well-known URL. `Uri.parse(
  /// 'https://op/realm/').pathSegments == ['realm', '']`, and spreading that
  /// empty tail produced a double slash (`/realm//.well-known/...`) → a 404 on
  /// path-bearing issuers (Keycloak/IdentityServer/Zitadel pattern).
  static List<String> _trimTrailingEmptySegments(List<String> segments) {
    final out = [...segments];
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out;
  }

  /// RFC 3986 §3.1 `scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )`.
  static final RegExp _webFingerSchemeGrammar = RegExp(
    r'^[A-Za-z][A-Za-z0-9+\-.]*$',
  );

  /// RFC 3986 §3.2.3 `port = *DIGIT` — possibly empty, hence `*` not `+`.
  static final RegExp _webFingerPortGrammar = RegExp(r'^[0-9]*$');

  /// OIDC Discovery 1.0 §2.1.1 item 1: "User input Identifiers starting with
  /// the XRI global context symbols ('=', '@', and '!') are RESERVED.
  /// Processing of these identifiers is out of scope for this specification."
  static const _xriGlobalContextSymbols = <String>{'=', '@', '!'};

  /// Index of the first occurrence of any of [chars], or `-1`.
  static int _indexOfAny(String input, List<String> chars) {
    var result = -1;
    for (final char in chars) {
      final index = input.indexOf(char);
      if (index >= 0 && (result < 0 || index < result)) {
        result = index;
      }
    }
    return result;
  }

  /// OIDC Discovery 1.0 §2.1.2, the branch point between rule 4 ("If the user
  /// input Identifier contains an explicit scheme…") and rules 1-3 (input that
  /// "does not have an RFC 3986 scheme component").
  ///
  /// This MUST be a string-level heuristic. Dart parses `example.com:8080` as
  /// scheme `example.com` with path `8080` — a correct RFC 3986 reading of
  /// `scheme ":" path-rootless` that §2.2.3 nevertheless overrides by requiring
  /// resource `https://example.com:8080/` and host `example.com:8080`. Handing
  /// raw user input to `Uri.parse` to decide this question is therefore wrong.
  static bool _webFingerHasScheme(String input) {
    // `scheme "://" authority path-abempty` is unambiguous, but only when the
    // text before the delimiter is actually a scheme. A bare `contains('://')`
    // also fires on a scheme-less input carrying a URL in its path, query or
    // fragment -- `joe@example.com/x?next=https://elsewhere` is rule 2, not
    // rule 4 -- and host derivation then fails outright.
    final schemeSep = input.indexOf('://');
    if (schemeSep > 0 &&
        _webFingerSchemeGrammar.hasMatch(input.substring(0, schemeSep))) {
      return true;
    }
    // Per rule 1 the input is read as
    // `[userinfo "@"] host [":" port] path-abempty ["?" query] ["#" fragment]`,
    // so only the leading authority can hold a scheme delimiter.
    final authorityEnd = _indexOfAny(input, ['/', '?', '#']);
    final authority = authorityEnd < 0
        ? input
        : input.substring(0, authorityEnd);
    final colon = authority.indexOf(':');
    if (colon < 0) {
      return false;
    }
    // A digits-only tail is an RFC 3986 `port`, not a scheme — the §2.2.3
    // override. Both reference implementations (pyoidc
    // `URINormalizer.has_scheme`, panva `webfinger_normalize.hasScheme`) use
    // exactly this test.
    if (_webFingerPortGrammar.hasMatch(authority.substring(colon + 1))) {
      return false;
    }
    // Stricter than pyoidc/panva, and changes no spec example: garbage such as
    // `joe@example.com:foo` falls to rule 3, where a typed "Invalid port"
    // error beats treating `joe@example.com` as a scheme.
    return _webFingerSchemeGrammar.hasMatch(authority.substring(0, colon));
  }

  /// Parses an already-normalized resource, converting the [FormatException]
  /// Dart raises for a syntactically invalid URI into the library's typed
  /// [OidcException].
  static Uri _parseWebFingerResource(String resource) {
    try {
      return Uri.parse(resource);
    } on FormatException catch (e, st) {
      throw OidcException(
        'The normalized WebFinger resource is not a valid URI: $resource',
        internalException: e,
        internalStackTrace: st,
      );
    }
  }

  /// OIDC Discovery 1.0 §2.1.2 closing paragraph: "The WebFinger `[RFC7033]`
  /// Resource in this case is the resulting URI, and the WebFinger Host is the
  /// authority component."
  ///
  /// Userinfo is deliberately EXCLUDED even though RFC 3986's `authority`
  /// includes it: the Host is spliced into a request URL and an HTTP `Host:`
  /// header, so carrying `joe@` there would both be wrong and leak the
  /// userinfo into a header. pyoidc (`urlparse().hostname`) and panva (Node's
  /// `url.host`) both exclude it too.
  /// Matches a percent-triplet in the `%80`-`%FF` range, i.e. a byte of a
  /// UTF-8 sequence Dart emitted in place of the A-label it should have been.
  static final _webFingerNonAsciiPct = RegExp('%[89a-fA-F][0-9a-fA-F]');

  /// Refuses an internationalized host instead of emitting an unresolvable one.
  ///
  /// RFC 5891 requires an IDN to be converted to its ASCII A-label
  /// (`xn--mnchen-3ya.de`) before it appears in a URL or a `Host:` header.
  /// Dart does not do that: `Uri.parse('https://münchen.de/joe').host` is
  /// `m%C3%BCnchen.de`, the percent-encoded UTF-8, which no resolver can
  /// answer. IDNA is not implemented here -- it needs Punycode plus Unicode
  /// normalization, neither of which is in the SDK -- so the identifier is
  /// rejected at normalization with the reason named. A caller holding an IDN
  /// converts it and passes the A-label, which flows through untouched.
  static String _requireAsciiWebFingerHost(String host, Uri parsed) {
    final nonAscii =
        host.codeUnits.any((unit) => unit > 127) ||
        _webFingerNonAsciiPct.hasMatch(host);
    if (!nonAscii) {
      return host;
    }
    throw OidcException(
      'The WebFinger host "$host" is internationalized, and this library does '
      'not implement IDNA. Convert it to its punycode A-label first (RFC '
      '5891, e.g. "xn--mnchen-3ya.de"). Resource: $parsed',
    );
  }

  static String _webFingerHost(Uri parsed) {
    if (parsed.hasAuthority) {
      if (parsed.host.isEmpty) {
        throw OidcException(
          'No WebFinger Host could be derived from the resource: $parsed',
        );
      }
      // RFC 3986 §6.2.2.1: the host is case-insensitive, so it is case-folded
      // even though the resource itself preserves the input's case.
      final host = parsed.host.toLowerCase();
      // Dart drops the RFC 3986 §3.2.2 IP-literal brackets, and the bare form
      // is not a host: `Uri.parse('https://2001:db8::1')` throws "Invalid port
      // (at character 14)" when [getWebFingerUri] splices it back. A colon can
      // only occur inside a host as part of an IP-literal, so it is the test.
      final literal = host.contains(':') ? '[$host]' : host;
      return _requireAsciiWebFingerHost(literal, parsed) +
          (parsed.hasPort ? ':${parsed.port}' : '');
    }
    // `scheme ":" path-rootless` (acct:, mailto:, …). §2.2.4 derives host
    // `shopping.example.com` from
    // `acct:juliet%40capulet.example@shopping.example.com`, i.e. the segment
    // after the LAST '@'.
    final path = parsed.path;
    final at = path.lastIndexOf('@');
    if (at < 0) {
      throw OidcException(
        'No WebFinger Host could be derived from the resource: $parsed',
      );
    }
    var host = path.substring(at + 1);
    final hostEnd = _indexOfAny(host, ['/', '?']);
    if (hostEnd >= 0) {
      host = host.substring(0, hostEnd);
    }
    if (host.isEmpty) {
      throw OidcException(
        'No WebFinger Host could be derived from the resource: $parsed',
      );
    }
    return _requireAsciiWebFingerHost(host.toLowerCase(), parsed);
  }

  /// OpenID Connect Discovery 1.0 §2.1 Identifier Normalization: turns a raw
  /// End-User input Identifier into the RFC 7033 §4.1 `resource` and the
  /// WebFinger Host to query.
  ///
  /// Applies §2.1.2's five numbered rules IN ORDER, which is load-bearing:
  ///
  /// 1. the input is read as
  ///    `[userinfo "@"] host [":" port] path-abempty ["?" query] ["#" fragment]`;
  /// 2. userinfo + host present and scheme/path/query/port/fragment ALL absent
  ///    → the `acct` scheme is assumed, percent-encoding any `@` inside the
  ///    userinfo (RFC 7565);
  /// 3. any other scheme-less input → `https://` is prefixed;
  /// 4. an explicit scheme → NO normalization at all (case, trailing slash and
  ///    encoding are all left exactly as the user typed them);
  /// 5. only THEN is a fragment stripped.
  ///
  /// Because rule 5 runs last, `joe@example.com#frag` fails rule 2's
  /// "fragment absent" precondition and normalizes to `https://joe@example.com/`
  /// rather than `acct:joe@example.com`. pyoidc and panva strip the fragment
  /// first and disagree here; this follows the spec's literal step order.
  ///
  /// Throws [OidcException] for XRI identifiers (§2.1.1 item 1: leading `=`,
  /// `@` or `!` are RESERVED and out of scope), for an empty identifier, for a
  /// syntactically invalid URI, and when no WebFinger Host can be derived.
  static OidcWebFingerIdentifier normalizeWebFingerIdentifier(
    String identifier,
  ) {
    final input = identifier.trim();
    if (input.isEmpty) {
      throw const OidcException('The WebFinger identifier is empty.');
    }
    if (_xriGlobalContextSymbols.contains(input[0])) {
      throw OidcException(
        'XRI identifiers (starting with "=", "@" or "!") are RESERVED and '
        'out of scope for OpenID Connect Discovery: $input',
      );
    }

    final hasScheme = _webFingerHasScheme(input);
    final authorityEnd = _indexOfAny(input, ['/', '?', '#']);
    final authority = authorityEnd < 0
        ? input
        : input.substring(0, authorityEnd);
    // Non-empty ⇒ a path, query or fragment component is present, which defeats
    // rule 2's precondition.
    final rest = authorityEnd < 0 ? '' : input.substring(authorityEnd);

    final lastAt = authority.lastIndexOf('@');
    final hasUserinfo = lastAt > 0;
    final hostPart = hasUserinfo ? authority.substring(lastAt + 1) : authority;

    String resource;
    final acctAssumed =
        !hasScheme &&
        hasUserinfo &&
        hostPart.isNotEmpty &&
        !hostPart.contains(':') &&
        rest.isEmpty;

    if (hasScheme) {
      // Rule 4: "no input normalization is performed". `http://` stays
      // `http://` — the resource is an identifier, never a fetch target; the
      // WebFinger request itself is still HTTPS (RFC 7033 §4.2).
      resource = input;
    } else if (acctAssumed) {
      // Rule 2 + RFC 7565: encode ONLY the literal '@'. Running
      // `Uri.encodeComponent` here would turn an already-encoded `%40` into
      // `%2540`; encoding just the delimiter keeps the step idempotent.
      final userinfo = authority.substring(0, lastAt).replaceAll('@', '%40');
      resource = '${OidcConstants_WebFinger.acctScheme}:$userinfo@$hostPart';
    } else {
      // Rule 3: pure string prefixing, so the input's case survives. Building
      // this through `Uri` instead would silently lower-case the host.
      resource = '${OidcConstants_WebFinger.httpsScheme}://$input';
    }

    // Rule 5: "If the resulting URI contains a fragment component, it MUST be
    // stripped off, together with the fragment delimiter character '#'."
    final hash = resource.indexOf('#');
    if (hash >= 0) {
      resource = resource.substring(0, hash);
    }

    var parsed = _parseWebFingerResource(resource);

    // RFC 3986 §6.2.3 scheme-based normalization: an empty path in an http(s)
    // URI is equivalent to "/". §2.2.3's table — the only authoritative rule-3
    // output in the document — reads `https://example.com:8080/`, which literal
    // prefixing does not produce and Dart does not add on its own. Applied ONLY
    // to the rule-3 branch: rule 4's own examples (`https://example.com`) show
    // no trailing slash and rule 4 forbids normalization outright.
    if (!hasScheme && !acctAssumed && parsed.path.isEmpty) {
      final query = resource.indexOf('?');
      resource = query < 0
          ? '$resource/'
          : '${resource.substring(0, query)}/${resource.substring(query)}';
      // Re-parsed purely to keep [parsed] and [resource] in sync; the inserted
      // slash does not affect the authority the Host is taken from.
      parsed = _parseWebFingerResource(resource);
    }

    return OidcWebFingerIdentifier(
      resource: resource,
      host: _webFingerHost(parsed),
    );
  }

  /// Builds the RFC 7033 §4/§4.1 WebFinger request URL:
  /// `https://{host}/.well-known/webfinger?resource=...&rel=...`.
  ///
  /// The scheme is always `https` (RFC 7033 §4.2: "A client MUST query the
  /// WebFinger resource using HTTPS only"; §9.1: "clients MUST NOT issue
  /// queries over a non-secure connection"), regardless of [resource]'s own
  /// scheme. [rel] may carry several values; each is emitted as its own `rel`
  /// parameter (§4.3: "The 'rel' parameter MAY be included multiple times").
  /// Pass `const []` to omit `rel` entirely. Throws [OidcException] when [host]
  /// yields no authority.
  ///
  /// [host] is NOT sent as a query parameter: OIDC Discovery §2 lists it as a
  /// WebFinger parameter, but every §2.2.x example conveys it as the request
  /// URL's authority (and thus the HTTP `Host` header).
  static Uri getWebFingerUri({
    required String host,
    required String resource,
    List<String> rel = const [OidcConstants_WebFinger.relOpenIdIssuer],
  }) {
    // The dartdoc promises [OidcException]; without this, a host Dart refuses
    // to parse (an unbracketed IPv6 literal, a non-numeric port) escapes as a
    // raw FormatException and bypasses the typed-error contract that
    // [_parseWebFingerResource] exists to uphold.
    final Uri base;
    try {
      base = Uri.parse('${OidcConstants_WebFinger.httpsScheme}://$host');
    } on FormatException catch (e, st) {
      throw OidcException(
        'The WebFinger host is not a valid authority: "$host"',
        internalException: e,
        internalStackTrace: st,
      );
    }
    if (base.host.isEmpty) {
      throw OidcException(
        'The WebFinger host does not yield an authority: "$host"',
      );
    }
    // Built by hand rather than with `queryParameters:`, which applies
    // application/x-www-form-urlencoded and emits U+0020 as `+`. RFC 7033 §4.1
    // wants an RFC 3986 query, where a space is `%20`; `Uri.encodeComponent`
    // gives that and `Uri.encodeQueryComponent` does not.
    final encodedResource = Uri.encodeComponent(resource);
    final query = [
      '${OidcConstants_WebFinger.resource}=$encodedResource',
      for (final value in rel)
        '${OidcConstants_WebFinger.rel}=${Uri.encodeComponent(value)}',
    ].join('&');
    return base.replace(
      pathSegments: OidcConstants_WebFinger.wellKnownPathSegments,
      query: query,
    );
  }

  /// Takes a base issuer Url and APPENDS `/.well-known/openid-configuration`
  /// (OpenID Connect Discovery 1.0 §4.1), stripping any terminating slash first.
  static Uri getOpenIdConfigWellKnownUri(Uri base) {
    return base.replace(
      pathSegments: [
        ..._trimTrailingEmptySegments(base.pathSegments),
        '.well-known',
        'openid-configuration',
      ],
      query: null,
      fragment: null,
    );
  }

  /// Takes a base issuer Url and INSERTS `/.well-known/oauth-authorization-server`
  /// BEFORE the path (RFC 8414 §3.1 — the OPPOSITE layout to OIDC §4.1):
  /// `https://op/issuer1` → `https://op/.well-known/oauth-authorization-server/issuer1`.
  static Uri getOAuthAuthServerWellKnownUri(Uri base) {
    return base.replace(
      pathSegments: [
        '.well-known',
        'oauth-authorization-server',
        ..._trimTrailingEmptySegments(base.pathSegments),
      ],
      query: null,
      fragment: null,
    );
  }

  /// The inverse of [getOpenIdConfigWellKnownUri]: given an OIDC §4.1
  /// `.well-known/openid-configuration` URL, recovers the issuer it was built
  /// from by dropping the trailing `['.well-known','openid-configuration']`
  /// path segments (and clearing query/fragment).
  ///
  /// Returns `null` when [wellKnown] does not end with those two segments
  /// (e.g. an RFC 8414 insert-layout URL), so callers can detect that the
  /// issuer could not be derived. A query-carrying well-known URL with the
  /// standard path layout (e.g. an Entra `?appid=` form) IS inverted: the
  /// query and fragment are dropped from the derived issuer, and any
  /// downstream mismatch is caught by [issuersAreIdentical].
  static Uri? getIssuerFromOpenIdConfigWellKnownUri(Uri wellKnown) {
    final segments = wellKnown.pathSegments;
    if (segments.length < 2 ||
        segments[segments.length - 2] != '.well-known' ||
        segments[segments.length - 1] != 'openid-configuration') {
      return null;
    }
    // NOTE: `wellKnown.replace(query: null, fragment: null)` would NOT clear
    // an existing query/fragment — `Uri.replace`'s `null` means "keep the
    // current value", not "clear it" (and `query: ''` would instead leave a
    // dangling `?`). Building a fresh [Uri] from components is the only way
    // to genuinely omit them.
    return Uri(
      scheme: wellKnown.scheme,
      userInfo: wellKnown.userInfo.isEmpty ? null : wellKnown.userInfo,
      host: wellKnown.host,
      port: wellKnown.hasPort ? wellKnown.port : null,
      pathSegments: segments.sublist(0, segments.length - 2),
    );
  }

  /// OIDC Discovery 1.0 §4.3 / RFC 8414 §3.3: the discovery document's `issuer`
  /// MUST be identical to the issuer used to fetch it (mix-up defense). Compares
  /// by simple string equality, case-folding ONLY scheme + host (a genuine path
  /// difference, including a trailing slash, is a real mismatch and stays
  /// significant — do NOT normalize it away).
  static bool issuersAreIdentical(Uri expected, Uri actual) {
    String norm(Uri u) => u
        .replace(scheme: u.scheme.toLowerCase(), host: u.host.toLowerCase())
        .toString();
    return norm(expected) == norm(actual);
  }
}
