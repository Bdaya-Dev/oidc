import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/oidc_core.dart';

part 'state.g.dart';

/// Represents a state that takes a snapshot of the request parameters
/// and some settings to ensure nothing changes during the flow.
@JsonSerializable(
  createFactory: true,
  createToJson: true,
  converters: OidcInternalUtilities.commonConverters,
)
class OidcEndSessionState extends OidcState {
  ///
  OidcEndSessionState({
    required this.postLogoutRedirectUri,
    required this.originalUri,
    required this.options,
    super.createdAt,
    super.data,
    super.id,
  }) : super(
          operationDiscriminator:
              OidcConstants_OperationDiscriminators.endSession,
        );

  ///
  factory OidcEndSessionState.fromJson(Map<String, dynamic> src) =>
      _$OidcEndSessionStateFromJson(src);

  @JsonKey(name: OidcConstants_Store.options)
  final Map<String, dynamic>? options;

  @JsonKey(name: OidcConstants_AuthParameters.postLogoutRedirectUri)
  final Uri postLogoutRedirectUri;

  /// The uri to go back to after the page in `redirectUri`
  /// processes the response.
  @JsonKey(name: OidcConstants_Store.originalUri)
  final Uri? originalUri;

  @override
  Map<String, dynamic> toJson() => _$OidcEndSessionStateToJson(this);
}
