// The code here is mostly from https://github.com/authts/oidc-client-ts/blob/main/src/SigninRequest.ts

import 'package:json_annotation/json_annotation.dart';
import '../../helpers/converters.dart';
import '../enums/response_mode.dart';
import '../state/sign_in.dart';
part 'auth.g.dart';

String _stateToJson(OidcSignInState value) {
  return value.id;
}

/// From https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest
@JsonSerializable(
  createFactory: false,
  includeIfNull: false,
  explicitToJson: true,
  converters: [
    UriJsonConverter(),
    DurationSecondsConverter(),
  ],
)
class OidcAuthRequestArgs {
  @JsonKey(name: 'scope', toJson: spaceDelimitedToJson)
  final List<String> scope;
  @JsonKey(name: 'response_type', toJson: spaceDelimitedToJson)
  final List<String> responseType;
  @JsonKey(name: 'client_id')
  final String clientId;
  @JsonKey(name: 'redirect_uri')
  final Uri redirectUri;

  @JsonKey(name: 'state', toJson: _stateToJson)
  final OidcSignInState state;
  //optional
  @JsonKey(name: 'response_mode')
  final OidcResponseMode? responseMode;
  @JsonKey(name: 'nonce')
  final String? nonce;
  @JsonKey(name: 'display')
  final String? display;
  @JsonKey(name: 'prompt', toJson: spaceDelimitedToJson)
  final List<String> prompt;

  @JsonKey(name: 'max_age')
  final Duration? maxAge;
  @JsonKey(name: 'ui_locales', toJson: spaceDelimitedToJson)
  final List<String> uiLocales;
  @JsonKey(name: 'id_token_hint')
  final String? idTokenHint;
  @JsonKey(name: 'login_hint')
  final String? loginHint;
  @JsonKey(name: 'acr_values', toJson: spaceDelimitedToJson)
  final List<String> acrValues;
  //other
  @JsonKey(name: 'resource')
  final List<String> resource;
  @JsonKey(name: 'request')
  final String? request;
  @JsonKey(name: 'request_uri')
  final Uri? requestUri;
  @JsonKey(includeToJson: false)
  final Map<String, String> extraQueryParams;

  const OidcAuthRequestArgs({
    required this.redirectUri,
    required this.responseType,
    required this.scope,
    required this.clientId,
    required this.state,
    this.responseMode,
    this.nonce,
    this.display,
    this.maxAge,
    this.prompt = const [],
    this.uiLocales = const [],
    this.idTokenHint,
    this.loginHint,
    this.acrValues = const [],
    this.resource = const [],
    this.request,
    this.requestUri,
    this.extraQueryParams = const {},
  });

  Map<String, dynamic> _toMap() => {
        ..._$OidcAuthRequestArgsToJson(this),
        ...extraQueryParams,
        if (state.codeChallenge != null) ...{
          'code_challenge': state.codeChallenge,
          'code_challenge_method': 'S256',
        },
      };
}

/// From https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest
class OidcAuthRequest {
  /// The url that should be navigated to in order to start the request
  final Uri url;

  /// The input state.
  final OidcSignInState state;

  const OidcAuthRequest._({
    required this.url,
    required this.state,
  });

  factory OidcAuthRequest.fromArgs({
    required Uri authorizationEndpoint,
    required OidcAuthRequestArgs args,
  }) {
    return OidcAuthRequest._(
      url: authorizationEndpoint.replace(
        queryParameters: {
          //perserve old query parameters
          ...authorizationEndpoint.queryParameters,
          //add parameters from the args
          ...args._toMap(),
        },
      ),
      state: args.state,
    );
  }
}
