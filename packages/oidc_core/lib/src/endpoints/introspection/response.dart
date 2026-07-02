import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'response.g.dart';

/// Response from an OAuth 2.0 Token Introspection endpoint (RFC 7662 §2.2).
///
/// Only [active] is REQUIRED; all other members are OPTIONAL and read from
/// [src], which also exposes any non-standard members the server returned.
@JsonSerializable(
  createFactory: true,
  createToJson: false,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcIntrospectionResponse extends JsonBasedResponse {
  ///
  const OidcIntrospectionResponse({required super.src});

  /// Creates an [OidcIntrospectionResponse] from a JSON map.
  factory OidcIntrospectionResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcIntrospectionResponseFromJson(src);

  /// REQUIRED. Whether the presented token is currently active. A server that
  /// is unable to determine the state, or for any reason will not honor the
  /// request, returns `active: false`.
  bool get active => src['active'] == true;

  /// A space-separated list of scopes associated with the token.
  String? get scope => src['scope'] as String?;

  /// Client identifier for the OAuth 2.0 client that requested the token.
  String? get clientId => src['client_id'] as String?;

  /// Human-readable identifier for the resource owner who authorized the token.
  String? get username => src['username'] as String?;

  /// Type of the token, e.g. `Bearer`.
  String? get tokenType => src['token_type'] as String?;

  /// Subject of the token.
  String? get subject => src['sub'] as String?;

  /// Issuer of the token.
  String? get issuer => src['iss'] as String?;

  /// String identifier for the token (`jti`).
  String? get jwtId => src['jti'] as String?;

  /// Intended audience(s) of the token (`aud` may be a string or an array).
  List<String>? get audience {
    final aud = src['aud'];
    if (aud is String) return [aud];
    if (aud is List) return aud.map((e) => e.toString()).toList();
    return null;
  }

  DateTime? _numericDate(String key) {
    final value = src[key];
    return value is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (value * 1000).round(),
            isUtc: true,
          )
        : null;
  }

  /// Expiration time on or after which the token MUST NOT be accepted.
  DateTime? get expiry => _numericDate('exp');

  /// Time at which the token was issued.
  DateTime? get issuedAt => _numericDate('iat');

  /// Time before which the token MUST NOT be accepted.
  DateTime? get notBefore => _numericDate('nbf');
}
