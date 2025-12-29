import 'package:mason_logger/mason_logger.dart';
import 'package:oidc_core/oidc_core.dart';

/// Requests an access token using the `client_credentials` grant.
Future<String?> requestClientCredentialsAccessToken({
  required String issuer,
  required String clientId,
  required List<String> scopes,
  Logger? logger,
  String? clientSecret,
}) async {
  final log = logger ?? Logger();
  final wellKnown = OidcUtils.getOpenIdConfigWellKnownUri(Uri.parse(issuer));
  try {
    final metadata = await OidcEndpoints.getProviderMetadata(wellKnown);
    final tokenEndpoint = metadata.tokenEndpoint;
    if (tokenEndpoint == null) {
      log.err("Error: discovery document doesn't provide token_endpoint.");
      return null;
    }

    final credentials = clientSecret == null
        ? OidcClientAuthentication.none(clientId: clientId)
        : OidcClientAuthentication.clientSecretPost(
            clientId: clientId,
            clientSecret: clientSecret,
          );

    final tokenResp = await OidcEndpoints.token(
      tokenEndpoint: tokenEndpoint,
      credentials: credentials,
      request: OidcTokenRequest.clientCredentials(
        scope: scopes.isEmpty ? null : scopes,
      ),
    );

    return tokenResp.accessToken;
  } on Exception catch (e) {
    log.err('Error requesting client credentials token: $e');
    return null;
  }
}

/// Requests an access token using the `device_code` grant.
Future<String?> requestDeviceCodeAccessToken({
  required String issuer,
  required String clientId,
  required List<String> scopes,
  Logger? logger,
  String? clientSecret,
}) async {
  final log = logger ?? Logger();
  final wellKnown = OidcUtils.getOpenIdConfigWellKnownUri(Uri.parse(issuer));
  try {
    final metadata = await OidcEndpoints.getProviderMetadata(wellKnown);
    final tokenEndpoint = metadata.tokenEndpoint;
    if (tokenEndpoint == null) {
      log.err("Error: discovery document doesn't provide token_endpoint.");
      return null;
    }

    final deviceAuthEndpointValue = metadata
        .src[OidcConstants_ProviderMetadata.deviceAuthorizationEndpoint];
    if (deviceAuthEndpointValue == null) {
      log.err(
        "Error: discovery document doesn't provide device_authorization_endpoint.",
      );
      return null;
    }

    final deviceAuthEndpoint = Uri.parse(deviceAuthEndpointValue.toString());

    final credentials = clientSecret == null
        ? OidcClientAuthentication.none(clientId: clientId)
        : OidcClientAuthentication.clientSecretPost(
            clientId: clientId,
            clientSecret: clientSecret,
          );

    final deviceResp = await OidcEndpoints.deviceAuthorization(
      deviceAuthorizationEndpoint: deviceAuthEndpoint,
      credentials: credentials,
      request: OidcDeviceAuthorizationRequest(scope: scopes),
    );

    final verificationUri =
        deviceResp.verificationUriComplete ?? deviceResp.verificationUri;

    log.info('Open this URL to authenticate: $verificationUri');
    if (deviceResp.verificationUriComplete == null) {
      log.info('User code: ${deviceResp.userCode}');
    }

    final deadline = DateTime.now().add(deviceResp.expiresIn);
    var pollInterval = deviceResp.interval ?? const Duration(seconds: 5);

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      try {
        final tokenResp = await OidcEndpoints.token(
          tokenEndpoint: tokenEndpoint,
          credentials: credentials,
          request: OidcTokenRequest.deviceCode(
            deviceCode: deviceResp.deviceCode,
            scope: scopes,
          ),
        );

        if (tokenResp.accessToken != null) {
          return tokenResp.accessToken;
        }
      } on OidcException catch (e) {
        final code = e.errorResponse?.error;
        switch (code) {
          case 'authorization_pending':
            continue;
          case 'slow_down':
            pollInterval += const Duration(seconds: 5);
            continue;
          case 'access_denied':
            log.err('Authentication was denied.');
            return null;
          case 'expired_token':
            log.err('Device code expired.');
            return null;
          default:
            rethrow;
        }
      }
    }

    log.err('Timed out waiting for device authorization.');
    return null;
  } on Exception catch (e) {
    log.err('Error requesting device code token: $e');
    return null;
  }
}
