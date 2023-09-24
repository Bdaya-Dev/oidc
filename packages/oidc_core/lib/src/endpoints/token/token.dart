import 'package:clock/clock.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';

part 'token.g.dart';

/// Represents a serializable token.
///
/// The only thing required for this token is its [creationTime], which
/// represents the reference date of the [expiresIn] duration.
@JsonSerializable(
  createFactory: true,
  createToJson: true,
  explicitToJson: true,
  includeIfNull: false,
  createFieldMap: true,
)
class OidcToken {
  OidcToken({
    required this.creationTime,
    this.scope,
    this.accessToken,
    this.tokenType,
    this.idToken,
    this.expiresIn,
    this.refreshToken,
    this.extra,
    this.sessionState,
  });

  factory OidcToken.fromJson(Map<String, dynamic> src) =>
      _$OidcTokenFromJson(src);

  factory OidcToken.fromResponse(
    OidcTokenResponse response, {
    required String? sessionState,
    DateTime? creationTime,
    Duration? overrideExpiresIn,
  }) {
    creationTime ??= clock.now().toUtc();
    return OidcToken.fromJson({
      ...response.src,
      if (overrideExpiresIn != null)
        OidcConstants_AuthParameters.expiresIn: overrideExpiresIn.inSeconds,
      OidcConstants_Store.expiresInReferenceDate:
          creationTime.toIso8601String(),
      if (sessionState != null)
        OidcConstants_AuthParameters.sessionState: sessionState,
    });
  }

  @JsonKey(
    name: OidcConstants_AuthParameters.scope,
    fromJson: OidcInternalUtilities.splitSpaceDelimitedStringNullable,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  final List<String>? scope;

  /// OPTIONAL.
  ///
  /// The access token issued by the authorization server.
  @JsonKey(name: OidcConstants_AuthParameters.accessToken)
  final String? accessToken;

  /// REQUIRED.
  ///
  /// The type of the access token issued.
  ///
  /// Value is case insensitive.
  @JsonKey(name: OidcConstants_AuthParameters.tokenType)
  final String? tokenType;

  /// REQUIRED, in the OIDC spec.
  ///
  /// ID Token value associated with the authenticated session.
  @JsonKey(name: OidcConstants_AuthParameters.idToken)
  final String? idToken;

  bool get isOidc => idToken?.isNotEmpty ?? false;

  /// RECOMMENDED.
  ///
  /// The lifetime in seconds of the access token.
  ///
  /// For example, the value 3600 denotes that the access token will expire in
  /// one hour from the time the response was generated.
  ///
  /// If omitted, the authorization server SHOULD provide the expiration time
  /// via other means or document the default value.
  @JsonKey(
    name: OidcConstants_AuthParameters.expiresIn,
    fromJson: OidcInternalUtilities.durationFromJson,
    toJson: OidcInternalUtilities.durationToJson,
  )
  final Duration? expiresIn;

  /// OPTIONAL.
  ///
  /// The refresh token, which can be used to obtain new access tokens based on
  /// the grant passed in the corresponding token request.
  @JsonKey(name: OidcConstants_AuthParameters.refreshToken)
  final String? refreshToken;

  /// Store when this token was originally created.
  @JsonKey(
    name: OidcConstants_Store.expiresInReferenceDate,
    fromJson: OidcInternalUtilities.dateTimeFromJsonRequired,
    toJson: OidcInternalUtilities.dateTimeToJson,
    disallowNullValue: true,
  )
  final DateTime creationTime;

  /// The received session state.
  @JsonKey(name: OidcConstants_AuthParameters.sessionState)
  final String? sessionState;

  @JsonKey(
    includeFromJson: true,
    includeToJson: false,
    readValue: _readExtra,
  )
  final Map<String, dynamic>? extra;

  Duration? calculateExpiresInFromNow({
    DateTime? now,
    DateTime? overrideCreationTime,
  }) {
    now ??= clock.now().toUtc();

    final expiresIn = this.expiresIn;
    if (expiresIn == null) {
      return null;
    }
    final expiresAt = calculateExpiresAt(
      overrideCreationTime: overrideCreationTime,
    );
    if (expiresAt == null) {
      return null;
    }
    return expiresAt.difference(now);
  }

  /// Returns true if access token expired or is about to expire.
  bool isAccessTokenExpired({
    DateTime? now,
    DateTime? overrideCreationTime,
  }) {
    return isAccessTokenAboutToExpire(
      now: now,
      overrideCreationTime: overrideCreationTime,
      tolerance: Duration.zero,
    );
  }

  /// Returns true if access token expired or is about to expire.
  bool isAccessTokenAboutToExpire({
    DateTime? now,
    DateTime? overrideCreationTime,
    Duration tolerance = const Duration(minutes: 1),
  }) {
    now ??= clock.now().toUtc();
    final expAt = calculateExpiresAt(
      overrideCreationTime: overrideCreationTime,
    );
    final refreshTime = expAt?.difference(now);
    if (refreshTime == null) {
      return true;
    }
    return refreshTime < tolerance;
  }

  /// Calculates the expiry date of the access token from [expiresIn] and
  /// [overrideCreationTime].
  DateTime? calculateExpiresAt({DateTime? overrideCreationTime}) {
    final expiresIn = this.expiresIn;
    if (expiresIn == null) {
      return null;
    }
    final refDate = overrideCreationTime ?? creationTime;

    return refDate.add(expiresIn);
  }

  /// Returns a serializable json representation of this token.
  ///
  /// mainly used to store it.
  Map<String, dynamic> toJson() => {
        ..._$OidcTokenToJson(this),
        ...?extra,
      };
}

Object? _readExtra(Map<dynamic, dynamic> p1, String p2) {
  final processedKeys = _$OidcTokenFieldMap.values.toSet();
  return Map.fromEntries(
    p1.entries.where((element) => !processedKeys.contains(element.key)),
  ).cast<String, dynamic>();
}
