import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:oidc_core/src/helpers/pkce.dart';
import 'package:oidc_core/src/models/enums/response_mode.dart';
import 'package:oidc_core/src/models/state/state.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/converters.dart';

part 'sign_in.g.dart';

@JsonSerializable(
  createFactory: true,
  createToJson: true,
  converters: [
    DateTimeEpochConverter(),
    UriJsonConverter(),
  ],
)
class OidcSignInState extends OidcState {
  const OidcSignInState({
    required this.skipUserInfo,
    required super.id,
    required super.createdAt,
    required super.requestType,
    required super.data,
    required this.codeVerifier,
    required this.codeChallenge,
    required this.authority,
    required this.clientId,
    required this.redirectUri,
    required this.scope,
    required this.clientSecret,
    required this.extraTokenParams,
    required this.responseMode,
  });

  factory OidcSignInState.fromDefaults({
    String? id,
    DateTime? createdAt,
    String? requestType,
    dynamic data,
    bool generateCodeVerifierIfNull = true,
    String? codeVerifier,
    required Uri authority,
    required String clientId,
    required Uri redirectUri,
    required String scope,
    String? clientSecret,
    Map<String, dynamic>? extraTokenParams,
    OidcResponseMode? responseMode,
    bool? skipUserInfo,
  }) {
    createdAt ??= DateTime.now().toUtc();
    id ??= const Uuid().v4();

    if (generateCodeVerifierIfNull) {
      codeVerifier ??= PkcePair.generateVerifier(length: 32);
    }
    String? challenge;
    if (codeVerifier != null) {
      challenge ??= PkcePair.generateChallenge(codeVerifier);
    }
    return OidcSignInState(
      skipUserInfo: skipUserInfo,
      id: id,
      createdAt: createdAt,
      requestType: requestType,
      data: data,
      codeVerifier: codeVerifier,
      codeChallenge: challenge,
      authority: authority,
      clientId: clientId,
      redirectUri: redirectUri,
      scope: scope,
      clientSecret: clientSecret,
      extraTokenParams: extraTokenParams,
      responseMode: responseMode,      
    );
  }

  /// The same code_verifier that was used to obtain the authorization_code via PKCE.
  @JsonKey(name: 'code_verifier')
  final String? codeVerifier;

  ///Used to secure authorization code grants via Proof Key for Code Exchange (PKCE).
  @JsonKey(name: 'code_challenge')
  final String? codeChallenge;

  //to ensure state still matches settings
  @JsonKey(name: 'authority')
  final Uri authority;
  @JsonKey(name: 'client_id')
  final String clientId;
  @JsonKey(name: 'redirect_uri')
  final Uri redirectUri;
  @JsonKey(name: 'scope')
  final String scope;
  @JsonKey(name: 'client_secret')
  final String? clientSecret;
  @JsonKey(name: 'extraTokenParams')
  final Map<String, dynamic>? extraTokenParams;
  @JsonKey(name: 'response_mode')
  final OidcResponseMode? responseMode;
  @JsonKey(name: 'skipUserInfo')
  final bool? skipUserInfo;

  @override
  Map<String, dynamic> toJson() => _$OidcSignInStateToJson(this);
  factory OidcSignInState.fromJson(Map<String, dynamic> src) =>
      _$OidcSignInStateFromJson(src);
  factory OidcSignInState.fromStorageString(String storageString) =>
      OidcSignInState.fromJson(jsonDecode(storageString));
}
