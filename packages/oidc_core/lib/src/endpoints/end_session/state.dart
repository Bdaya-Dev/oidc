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
    this.sessionState,
    super.createdAt,
    super.data,
    super.id,
    super.managerId,
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

  /// A snapshot of the ending session's `session_state` (OIDC Session
  /// Management 1.0 §2), captured from [OidcUserManagerBase.currentUser] at
  /// the moment [OidcUserManagerBase.logout] built this state.
  ///
  /// [OidcUserManagerBase.handleEndSessionResponse] uses it to perform one
  /// final `check_session_iframe` probe before forgetting the user: on a web
  /// `samePage` navigation, the browser fully reloads at
  /// `post_logout_redirect_uri`, so by the time the response is handled,
  /// [OidcUserManagerBase.currentUser] is no longer available to read it from
  /// (the fresh page processes this very state before ever restoring a
  /// cached user) -- this field is the only way that code path still has it.
  @JsonKey(name: OidcConstants_AuthParameters.sessionState)
  final String? sessionState;

  @override
  Map<String, dynamic> toJson() => _$OidcEndSessionStateToJson(this);
}
