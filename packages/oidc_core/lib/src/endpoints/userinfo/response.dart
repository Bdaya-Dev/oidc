import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_core/src/models/json_based_object.dart';

part 'response.g.dart';

@JsonSerializable(
  createFactory: true,
  createToJson: false,
  constructor: '_',
  converters: OidcInternalUtilities.commonConverters,
)
class OidcUserInfoResponse extends JsonBasedResponse {
  const OidcUserInfoResponse._({
    required super.src,
    this.sub,
    this.nbf,
    this.iat,
    this.jti,
    this.iss,
    this.aud = const [],
    this.exp,
    this.claimNames,
    this.claimSources,
  });

  /// Parses OidcUserInfoResponse from json object.
  factory OidcUserInfoResponse.fromJson(Map<String, dynamic> src) =>
      _$OidcUserInfoResponseFromJson(src);

  /// The "sub" (subject) claim identifies the principal that is the subject of
  /// the JWT.
  ///
  /// The claims in a JWT are normally statements about the subject.
  ///
  /// The subject value MUST either be scoped to be locally unique in the
  /// context of the issuer or be globally unique.
  ///
  /// The processing of this claim is generally application specific.
  ///
  /// The "sub" value is a case-sensitive string containing a
  /// StringOrURI value.
  @JsonKey(name: OidcConstants_AuthParameters.sub)
  final String? sub;

  /// The "iss" (issuer) claim identifies the principal that issued the JWT.
  ///
  /// The processing of this claim is generally application specific.
  ///
  /// The "iss" value is a case-sensitive string containing a StringOrURI value.
  @JsonKey(name: OidcConstants_AuthParameters.iss)
  final String? iss;

  @JsonKey(
    name: OidcConstants_AuthParameters.aud,
    fromJson: OidcInternalUtilities.splitSpaceDelimitedString,
  )
  final List<String> aud;

  /// The "exp" (expiration time) claim identifies the expiration time on or
  /// after which the JWT MUST NOT be accepted for processing.
  ///
  /// The processing of the "exp" claim requires that the current date/time
  /// MUST be before the expiration date/time listed in the "exp" claim.
  ///
  /// Implementers MAY provide for some small leeway, usually no more than a
  /// few minutes, to account for clock skew.
  ///
  /// Its value MUST be a number containing a NumericDate value.
  @JsonKey(name: OidcConstants_AuthParameters.exp)
  final DateTime? exp;

  /// The "nbf" (not before) claim identifies the time before which the JWT
  /// MUST NOT be accepted for processing.
  ///
  /// The processing of the "nbf" claim requires that the current date/time
  /// MUST be after or equal to the not-before date/time listed in the
  /// "nbf" claim.
  ///
  /// Implementers MAY provide for some small leeway, usually no more than
  /// a few minutes, to account for clock skew.
  ///
  /// Its value MUST be a number containing a NumericDate value.
  @JsonKey(name: OidcConstants_AuthParameters.nbf)
  final DateTime? nbf;

  /// The "iat" (issued at) claim identifies the time at which the JWT was
  /// issued.
  ///
  /// This claim can be used to determine the age of the JWT.
  ///
  /// Its value MUST be a number containing a NumericDate value.
  @JsonKey(name: OidcConstants_AuthParameters.iat)
  final DateTime? iat;

  /// The "jti" (JWT ID) claim provides a unique identifier for the JWT.
  ///
  /// The identifier value MUST be assigned in a manner that ensures that there
  /// is a negligible probability that the same value will be accidentally
  /// assigned to a different data object; if the application uses multiple
  /// issuers, collisions MUST be prevented among values produced by different
  /// issuers as well.
  ///
  /// The "jti" claim can be used to prevent the JWT from being replayed.
  ///
  /// The "jti" value is a case-sensitive string.
  @JsonKey(name: OidcConstants_AuthParameters.jti)
  final String? jti;

  /// JSON object whose member names are the Claim Names for
  /// the Aggregated and Distributed Claims.
  ///
  /// The member values are references to the member names in the `_claim_sources`
  /// member from which the actual Claim Values can be retrieved.
  @JsonKey(name: OidcConstants_JWTClaims.claimNames)
  final Map<String, String>? claimNames;

  /// JSON object whose member names are referenced by the member values of the `_claim_names` member.
  /// The member values contain sets of Aggregated Claims or reference locations for Distributed Claims.
  @JsonKey(name: OidcConstants_JWTClaims.claimSources)
  final Map<String, OidcClaimSource>? claimSources;
}
