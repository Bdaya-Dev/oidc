import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
// ignore: implementation_imports
import 'package:oidc_core/src/models/json_based_object.dart';

part 'user_metadata.g.dart';

///
@JsonSerializable(
  createToJson: true,
  createFactory: true,
  explicitToJson: true,
  createFieldMap: true,
  converters: OidcInternalUtilities.commonConverters,
  constructor: '_',
)
class OidcUserMetadata extends JsonBasedResponse {
  ///
  const OidcUserMetadata._({
    required super.src,
    this.scope,
    this.expiresIn,
    this.expiresInReferenceDate,
    this.accessToken,
    this.refreshToken,
    this.tokenType,
  });

  ///
  const OidcUserMetadata.empty()
      : this._(
          src: const {},
        );

  static final fieldKeys = _$OidcUserMetadataFieldMap.values.toSet();

  ///
  factory OidcUserMetadata.fromJson(Map<String, dynamic> src) =>
      _$OidcUserMetadataFromJson(src);

  /// converts the metadata to json
  Map<String, dynamic> toJson() => _$OidcUserMetadataToJson(this);

  ///
  @JsonKey(name: OidcConstants_AuthParameters.accessToken)
  final String? accessToken;

  ///
  @JsonKey(name: OidcConstants_AuthParameters.refreshToken)
  final String? refreshToken;

  ///
  @JsonKey(name: OidcConstants_AuthParameters.tokenType)
  final String? tokenType;

  ///
  @JsonKey(name: OidcConstants_AuthParameters.scope)
  final List<String>? scope;

  ///
  @JsonKey(name: OidcConstants_AuthParameters.expiresIn)
  final Duration? expiresIn;

  /// The start date of calculating [expiresIn].
  @JsonKey(name: OidcConstants_Store.expiresInReferenceDate)
  final DateTime? expiresInReferenceDate;

  /// Calculates the expirey date of the access token from [expiresIn] and [expiresInReferenceDate].
  DateTime? get calculatedExpiresAt {
    final expIn = expiresIn;
    final refDate = expiresInReferenceDate;
    if (expIn == null || refDate == null) {
      return null;
    }
    return refDate.add(expIn);
  }
}
