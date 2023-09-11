import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';
import 'json_based_object.dart';

part 'user_metadata.g.dart';

/// Represents the metadata of a user.
@JsonSerializable(
  createToJson: false,
  createFactory: true,
  explicitToJson: true,
  createFieldMap: true,
  converters: [
    OidcDurationSecondsConverter(),
  ],
  constructor: '_',
)
class OidcUserMetadata extends JsonBasedResponse {
  ///
  factory OidcUserMetadata.fromJson(Map<String, dynamic> src) =>
      _$OidcUserMetadataFromJson(src);

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
  const OidcUserMetadata.empty() : this._(src: const {});

  /// All the used field keys.
  static final fieldKeys = _$OidcUserMetadataFieldMap.values.toSet();

  /// converts the metadata to json
  Map<String, dynamic> toJson() => src;

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
  @JsonKey(
    name: OidcConstants_AuthParameters.scope,
    fromJson: OidcInternalUtilities.splitSpaceDelimitedString,
    toJson: OidcInternalUtilities.joinSpaceDelimitedList,
  )
  final List<String>? scope;

  ///
  @JsonKey(
    name: OidcConstants_AuthParameters.expiresIn,
    readValue: OidcInternalUtilities.readDurationSeconds,
  )
  final Duration? expiresIn;

  /// The start date of calculating [expiresIn].
  @JsonKey(
    name: OidcConstants_Store.expiresInReferenceDate,
    fromJson: OidcInternalUtilities.dateTimeFromJson,
    toJson: OidcInternalUtilities.dateTimeToJson,
  )
  final DateTime? expiresInReferenceDate;

  /// Calculates the expirey date of the access token from [expiresIn] and
  /// [expiresInReferenceDate].
  DateTime? get calculatedExpiresAt {
    final expIn = expiresIn;
    final refDate = expiresInReferenceDate;
    if (expIn == null || refDate == null) {
      return null;
    }
    return refDate.add(expIn);
  }
}
