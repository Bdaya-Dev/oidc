// ignore_for_file: avoid_print, omit_local_variable_types

import 'dart:async';
import 'dart:io';

import 'package:jose_plus/jose.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_loopback_listener/oidc_loopback_listener.dart';

/// This example shows how to use the authorization code flow using
/// https://demo.duendesoftware.com idp from the cli.
/// you can login with google, or with bob/bob, or with alice/alice.

final idp = Uri.parse('https://demo.duendesoftware.com/');
const String clientId = 'interactive.public';

void main() async {
  final OidcUser user = await getUser();
  print('user validated!\n'
      'subject: ${user.claims.subject}\n'
      'claims: ${user.claims.toJson()}\n'
      'userInfo: ${user.userInfo}');
  return;
}

Future<OidcUser> getUser() async {
  final keystore = JsonWebKeyStore();

  final OidcProviderMetadata parsedMetadata =
      await OidcEndpoints.getProviderMetadata(
    OidcUtils.getOpenIdConfigWellKnownUri(idp),
  );
  if (parsedMetadata.jwksUri != null) {
    keystore.addKeySetUrl(parsedMetadata.jwksUri!);
  }
  final Uri? userInfoEndpoint = parsedMetadata.userinfoEndpoint;
  final Uri? authEndpoint = parsedMetadata.authorizationEndpoint;
  final Uri? tokenEndpoint = parsedMetadata.tokenEndpoint;
  if (authEndpoint == null || tokenEndpoint == null) {
    throw Exception(
        'idp does not have an authorizationEndpoint or a tokenEndpoint');
  }
  // create an in-memory store, since no data persistence is needed.
  final store = OidcMemoryStore();

  // creates a listener that waits for redirects.
  const listener = OidcLoopbackListener(path: 'redirect-me');
  final serverCompleter = Completer<HttpServer>();
  // we only need the http server to wait for a single response.
  final Future<Uri?> responseFuture =
      listener.listenForSingleResponse(serverCompleter: serverCompleter);
  final HttpServer server = await serverCompleter.future;

  print('started listening on port ${server.port}');

  final Uri redirectUri = Uri(
    scheme: 'http',
    host: server.address.host,
    port: server.port,
    path: listener.path,
  );

  final OidcSimpleAuthorizationRequestContainer requestContainer =
      await OidcEndpoints.prepareAuthorizationCodeFlowRequest(
    metadata: parsedMetadata,
    input: OidcSimpleAuthorizationCodeFlowRequest(
      scope: [OidcConstants_Scopes.openid, OidcConstants_Scopes.profile],
      clientId: clientId,
      redirectUri: redirectUri,
      prompt: [OidcConstants_AuthorizeRequest_Prompt.login],
    ),
    store: store,
  );
  final Uri requestUri = requestContainer.request.generateUri(authEndpoint);

  print('please login using the following link: $requestUri');

  final response = await responseFuture;
  if (response == null) {
    throw Exception('did not receive a response, please try again.');
  }
  final parsedResponse = await OidcEndpoints.parseAuthorizeResponse(
    responseUri: response,
    //resolve by state parameter since we provided it.
    resolveResponseModeByKey: OidcConstants_AuthParameters.state,
  );
  final tokenResponse = await OidcEndpoints.token(
    tokenEndpoint: tokenEndpoint,
    request: OidcTokenRequest.authorizationCode(
      code: parsedResponse.code!,
      codeVerifier: requestContainer.stateData.codeVerifier,
      redirectUri: redirectUri,
      clientId: clientId,
    ),
    credentials: const OidcClientAuthentication.none(
      clientId: clientId,
    ),
  );

  print('Token received!');
  final parsedToken = OidcToken.fromResponse(
    tokenResponse,
    sessionState: parsedResponse.sessionState,
  );
  OidcUser user = await OidcUser.fromIdToken(
    token: parsedToken,
    keystore: keystore,
    allowedAlgorithms:
        parsedMetadata.tokenEndpointAuthSigningAlgValuesSupported,
    strictVerification: true,
  );
  if (userInfoEndpoint != null) {
    final userInfo = await OidcEndpoints.userInfo(
      userInfoEndpoint: userInfoEndpoint,
      accessToken: parsedToken.accessToken!,
    );
    user = user.withUserInfo(userInfo.src);
  }
  return user;
}
