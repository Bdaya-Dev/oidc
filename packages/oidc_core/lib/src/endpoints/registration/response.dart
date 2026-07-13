import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'response.g.dart';

/// Response from an OAuth 2.0 Dynamic Client Registration endpoint
/// (RFC 7591 §3.2.1), also returned by RFC 7592 read/update operations.
///
/// All registered client metadata is echoed back and available via [src]; the
/// registration-specific members below are surfaced as typed accessors.
@JsonSerializable(
  createFactory: true,
  createToJson: false,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcClientRegistrationResponse extends JsonBasedResponse {
  ///
  const OidcClientRegistrationResponse({required super.src});

  /// Creates an [OidcClientRegistrationResponse] from a JSON map.
  factory OidcClientRegistrationResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcClientRegistrationResponseFromJson(src);

  /// REQUIRED. The issued client identifier.
  String? get clientId => src['client_id'] as String?;

  /// The issued client secret, if any.
  String? get clientSecret => src['client_secret'] as String?;

  /// RFC 7592 registration access token, used to read/update/delete the client
  /// configuration at [registrationClientUri].
  String? get registrationAccessToken =>
      src['registration_access_token'] as String?;

  /// RFC 7592 client configuration endpoint for this client.
  Uri? get registrationClientUri {
    final value = src['registration_client_uri'];
    return value is String ? Uri.tryParse(value) : null;
  }

  /// Time at which the client identifier was issued.
  DateTime? get clientIdIssuedAt => _numericDate('client_id_issued_at');

  /// Time at which the client secret will expire. `null` when absent; a value
  /// equal to the epoch (`0`) means the secret never expires (RFC 7591 §3.2.1).
  DateTime? get clientSecretExpiresAt =>
      _numericDate('client_secret_expires_at');

  /// Whether the issued client secret never expires (`client_secret_expires_at`
  /// is present and `0`).
  bool get clientSecretNeverExpires => src['client_secret_expires_at'] == 0;

  /// Registered redirection URIs.
  List<Uri>? get redirectUris {
    final value = src['redirect_uris'];
    return value is List
        ? value.map((e) => Uri.tryParse(e.toString())).whereType<Uri>().toList()
        : null;
  }

  /// Registered grant types.
  List<String>? get grantTypes => _stringList('grant_types');

  /// Registered response types.
  List<String>? get responseTypes => _stringList('response_types');

  /// Registered token-endpoint authentication method.
  String? get tokenEndpointAuthMethod =>
      src['token_endpoint_auth_method'] as String?;

  /// Registered (space-separated) scope string.
  String? get scope => src['scope'] as String?;

  /// Registered human-readable client name.
  String? get clientName => src['client_name'] as String?;

  /// Server-managed members that a client MUST NOT send back in an RFC 7592
  /// §2.2 update request.
  static const _updateExcludedKeys = {
    'registration_access_token',
    'registration_client_uri',
    'client_id_issued_at',
    'client_secret_expires_at',
  };

  /// Builds the full-metadata body for an RFC 7592 §2.2 client update (PUT to
  /// [registrationClientUri]).
  ///
  /// Per RFC 7592 §2.2 the update MUST carry the complete set of client
  /// metadata as returned by the server — values replace, not augment, the
  /// prior registration — so this echoes every member of [src] except the
  /// server-managed fields (`registration_access_token`,
  /// `registration_client_uri`, `client_id_issued_at`,
  /// `client_secret_expires_at`). `client_id`, and `client_secret` when it was
  /// issued, are retained (the spec requires `client_id`, and a returned
  /// `client_secret` MUST match the currently-issued secret).
  ///
  /// Note on rotation: the update *response* MAY return a new `client_secret`
  /// and/or a new `registration_access_token` (RFC 7592 §2.2 / §3). Those
  /// rotated credentials supersede the previous ones — read them from the
  /// returned [OidcClientRegistrationResponse] (via [clientSecret] /
  /// [registrationAccessToken]) and use them for subsequent requests; the old
  /// values may no longer be valid.
  OidcClientRegistrationRequest toUpdateRequest() {
    final extra = <String, dynamic>{
      for (final entry in src.entries)
        if (!_updateExcludedKeys.contains(entry.key)) entry.key: entry.value,
    };
    return OidcClientRegistrationRequest(extra: extra);
  }

  List<String>? _stringList(String key) {
    final value = src[key];
    return value is List ? value.map((e) => e.toString()).toList() : null;
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
}
