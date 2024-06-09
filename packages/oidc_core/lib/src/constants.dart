// coverage:ignore-file
// ignore_for_file: camel_case_types, lines_longer_than_80_chars
//==========================================================================================================
// This file was collected from https://www.iana.org/assignments/oauth-parameters/oauth-parameters.xhtml  ||
//==========================================================================================================

///
class OidcConstants_OperationDiscriminators {
  /// for redirect-based auth
  static const authorize = 'auth';

  /// for redirect-based end_session
  static const endSession = 'end_session';
}

class OidcConstants_AccessTokenTypes {
  /// Bearer
  static const bearer = 'Bearer';

  /// N_A
  static const notApplicable = 'N_A';

  /// PoP
  static const poP = 'PoP';

  /// DPoP
  static const dPoP = 'DPoP';
}

class OidcConstants_ClientAuthenticationMethods {
  static const clientSecretBasic = 'client_secret_basic';
  static const clientSecretPost = 'client_secret_post';
  static const clientSecretJwt = 'client_secret_jwt';
  static const privateKeyJwt = 'private_key_jwt';
  static const none = 'none';
}

class OidcConstants_ClientAssertionTypes {
  static const jwtBearer =
      'urn:ietf:params:oauth:client-assertion-type:jwt-bearer';

  static const saml2Bearer =
      'urn:ietf:params:oauth:client-assertion-type:saml2-bearer';
}

class OidcConstants_GrantType {
  static const String implicit = 'implicit';
  static const String authorizationCode = 'authorization_code';
  static const String password = 'password';
  static const String clientCredentials = 'client_credentials';
  static const String refreshToken = 'refresh_token';
  static const String deviceCode =
      'urn:ietf:params:oauth:grant-type:device_code';
  static const String tokenExchange =
      'urn:ietf:params:oauth:grant-type:token-exchange';
  static const String saml2Bearer =
      'urn:ietf:params:oauth:grant-type:saml2-bearer';
  static const String ciba = 'urn:openid:params:grant-type:ciba';

  static const String jwtBearer = 'urn:ietf:params:oauth:grant-type:jwt-bearer';
  static const String umaTicket = 'urn:ietf:params:oauth:grant-type:uma-ticket';
}

class OidcConstants_Scopes {
  static const openid = 'openid';
  static const profile = 'profile';
  static const email = 'email';
  static const address = 'address';
  static const phone = 'phone';
}

class OidcConstants_JWTClaims {
  ///	Session ID
  static const sid = 'sid';

  /// Used for aggregated claims.
  static const jwt = 'JWT';

  /// Used for distributed claims.
  static const endpoint = 'endpoint';

  /// `_claim_names` https://openid.net/specs/openid-connect-core-1_0.html#AggregatedDistributedClaims
  static const claimNames = '_claim_names';

  /// `_claim_sources` https://openid.net/specs/openid-connect-core-1_0.html#AggregatedDistributedClaims
  static const claimSources = '_claim_sources';
}

class OidcConstants_AuthParameters {
  /// authorization request, token request
  static const clientId = 'client_id';

  /// token request
  static const clientSecret = 'client_secret';

  /// authorization request
  static const responseType = 'response_type';

  /// authorization request, token request
  static const redirectUri = 'redirect_uri';

  /// logout_hint
  static const logoutHint = 'logout_hint';

  /// post_logout_redirect_uri
  static const postLogoutRedirectUri = 'post_logout_redirect_uri';

  /// authorization request, authorization response, token request, token response
  static const scope = 'scope';

  /// authorization request, authorization response
  static const state = 'state';

  /// authorization response, token request
  static const code = 'code';

  /// authorization response, token response
  static const error = 'error';

  /// authorization response, token response
  static const errorDescription = 'error_description';

  /// authorization response, token response
  static const errorUri = 'error_uri';

  /// token request
  static const grantType = 'grant_type';

  /// authorization response, token response
  static const accessToken = 'access_token';

  /// authorization response, token response
  static const tokenType = 'token_type';

  /// authorization response, token response
  static const expiresIn = 'expires_in';

  /// token request
  static const username = 'username';

  /// device authorization grant
  static const verificationUri = 'verification_uri';

  /// device authorization grant
  static const verificationUriComplete = 'verification_uri_complete';

  /// device authorization grant
  static const interval = 'interval';

  /// device authorization grant
  static const userCode = 'user_code';

  /// token request
  static const password = 'password';

  /// token request, token response
  static const refreshToken = 'refresh_token';

  /// authorization request
  static const nonce = 'nonce';

  /// authorization request
  static const display = 'display';

  /// authorization request
  static const prompt = 'prompt';

  /// authorization request
  static const maxAge = 'max_age';

  /// authorization request
  static const uiLocales = 'ui_locales';

  /// authorization request
  static const claimsLocales = 'claims_locales';

  /// authorization request
  static const idTokenHint = 'id_token_hint';

  /// authorization request
  static const loginHint = 'login_hint';

  /// authorization request
  static const acrValues = 'acr_values';

  /// authorization request
  static const claims = 'claims';

  /// authorization request
  static const registration = 'registration';

  /// authorization request
  static const request = 'request';

  /// authorization request
  static const requestUri = 'request_uri';

  /// authorization response, access token response
  static const idToken = 'id_token';

  /// authorization response, access token response
  static const sessionState = 'session_state';

  /// token request
  static const assertion = 'assertion';

  /// token request
  static const clientAssertion = 'client_assertion';

  /// token request
  static const clientAssertionType = 'client_assertion_type';

  /// token request
  static const codeVerifier = 'code_verifier';

  /// authorization request
  static const codeChallenge = 'code_challenge';

  /// authorization request
  static const codeChallengeMethod = 'code_challenge_method';

  /// client request, token endpoint
  static const claimToken = 'claim_token';

  /// client request, token endpoint, authorization server response,
  /// token endpoint.
  static const pct = 'pct';

  /// client request, token endpoint
  static const rpt = 'rpt';

  /// client request, token endpoint
  static const ticket = 'ticket';

  /// authorization server response, token endpoint
  static const upgraded = 'upgraded';

  /// authorization request, token request
  static const vtr = 'vtr';

  /// token request
  static const deviceCode = 'device_code';

  /// authorization request, token request
  static const resource = 'resource';

  /// token request
  static const audience = 'audience';

  /// token request
  static const requestedTokenType = 'requested_token_type';

  /// token request
  static const subjectToken = 'subject_token';

  /// token request
  static const subjectTokenType = 'subject_token_type';

  /// token request
  static const actorToken = 'actor_token';

  /// token request
  static const actorTokenType = 'actor_token_type';

  /// token response
  static const issuedTokenType = 'issued_token_type';

  /// Authorization Request
  static const responseMode = 'response_mode';

  /// Access Token Response
  static const nfvToken = 'nfv_token';

  /// authorization request, authorization response
  static const iss = 'iss';

  /// authorization request
  static const sub = 'sub';

  /// authorization request
  static const aud = 'aud';

  /// authorization request
  static const exp = 'exp';

  /// authorization request
  static const nbf = 'nbf';

  /// authorization request
  static const iat = 'iat';

  /// authorization request
  static const jti = 'jti';

  /// token response
  static const aceProfile = 'ace_profile';

  /// client-rs request
  static const nonce1 = 'nonce1';

  /// rs-client response
  static const nonce2 = 'nonce2';

  /// client-rs request
  static const aceClientRecipientId = 'ace_client_recipientid';

  /// rs-client response
  static const aceServerRecipientId = 'ace_server_recipientid';

  /// token request
  static const reqCnf = 'req_cnf';

  /// token response
  static const rsCnf = 'rs_cnf';

  /// token response
  static const cnf = 'cnf';

  /// authorization request, token request, token response
  static const authorizationDetails = 'authorization_details';

  /// authorization request
  static const dpopJkt = 'dpop_jkt';
}

class OidcConstants_ProviderMetadata {
  ///Authorization server's issuer identifier URL
  static const issuer = 'issuer';

  ///URL of the authorization server's authorization endpoint
  static const authorizationEndpoint = 'authorization_endpoint';

  ///URL of the authorization server's token endpoint
  static const tokenEndpoint = 'token_endpoint';

  ///URL of the authorization server's JWK Set document
  static const jwksUri = 'jwks_uri';

  ///URL of the authorization server's OAuth 2.0 Dynamic Client Registration Endpoint
  static const registrationEndpoint = 'registration_endpoint';

  ///JSON array containing a list of the OAuth 2.0 "scope" values that this authorization server supports
  static const scopesSupported = 'scopes_supported';

  ///JSON array containing a list of the OAuth 2.0 "response_type" values that this authorization server supports
  static const responseTypesSupported = 'response_types_supported';

  ///JSON array containing a list of the OAuth 2.0 "response_mode" values that this authorization server supports
  static const responseModesSupported = 'response_modes_supported';

  ///JSON array containing a list of the OAuth 2.0 grant type values that this authorization server supports
  static const grantTypesSupported = 'grant_types_supported';

  ///JSON array containing a list of client authentication methods supported by this token endpoint
  static const tokenEndpointAuthMethodsSupported =
      'token_endpoint_auth_methods_supported';

  ///"JSON array containing a list of the JWS signing algorithms supported by the token endpoint for the signature on the JWT used to authenticate the client at the token endpoint"
  static const tokenEndpointAuthSigningAlgValuesSupported =
      'token_endpoint_auth_signing_alg_values_supported';

  ///URL of a page containing human-readable information that developers might want or need to know when using the authorization server
  static const serviceDocumentation = 'service_documentation';

  ///Languages and scripts supported for the user interface, represented as a JSON array of language tag values from BCP 47 RFC5646.
  static const uiLocalesSupported = 'ui_locales_supported';

  ///"URL that the authorization server provides to the person registering the client to read about the authorization server's requirements on how the client can use the data provided by the authorization server"
  static const opPolicyUri = 'op_policy_uri';

  ///"URL that the authorization server provides to the person registering the client to read about the authorization server's terms of service"
  static const opTosUri = 'op_tos_uri';

  ///URL of the authorization server's OAuth 2.0 revocation endpoint
  static const revocationEndpoint = 'revocation_endpoint';

  ///JSON array containing a list of client authentication methods supported by this revocation endpoint
  static const revocationEndpointAuthMethodsSupported =
      'revocation_endpoint_auth_methods_supported';

  ///"JSON array containing a list of the JWS signing algorithms supported by the revocation endpoint for the signature on the JWT used to authenticate the client at the revocation endpoint"
  static const revocationEndpointAuthSigningAlgValuesSupported =
      'revocation_endpoint_auth_signing_alg_values_supported';

  ///URL of the authorization server's OAuth 2.0 introspection endpoint
  static const introspectionEndpoint = 'introspection_endpoint';

  ///JSON array containing a list of client authentication methods supported by this introspection endpoint
  static const introspectionEndpointAuthMethodsSupported =
      'introspection_endpoint_auth_methods_supported';

  ///"JSON array containing a list of the JWS signing algorithms supported by the introspection endpoint for the signature on the JWT used to authenticate the client at the introspection endpoint"
  static const introspectionEndpointAuthSigningAlgValuesSupported =
      'introspection_endpoint_auth_signing_alg_values_supported';

  ///PKCE code challenge methods supported by this authorization server
  static const codeChallengeMethodsSupported =
      'code_challenge_methods_supported';

  ///"Signed JWT containing metadata values about the authorization server as claims"
  static const signedMetadata = 'signed_metadata';

  ///URL of the authorization server's device authorization endpoint
  static const deviceAuthorizationEndpoint = 'device_authorization_endpoint';

  ///"Indicates authorization server support for mutual-TLS client certificate-bound access tokens."
  static const tlsClientCertificateBoundAccessTokens =
      'tls_client_certificate_bound_access_tokens';

  ///"JSON object containing alternative authorization server endpoints, which a client intending to do mutual TLS will use in preference to the conventional endpoints."
  static const mtlsEndpointAliases = 'mtls_endpoint_aliases';

  ///"JSON array containing a list of the JWS signing algorithms supported by the server for signing the JWT used as NFV Token"
  static const nfvTokenSigningAlgValuesSupported =
      'nfv_token_signing_alg_values_supported';

  ///"JSON array containing a list of the JWE encryption algorithms (alg values) supported by the server to encode the JWT used as NFV Token"
  static const nfvTokenEncryptionAlgValuesSupported =
      'nfv_token_encryption_alg_values_supported';

  ///"JSON array containing a list of the JWE encryption algorithms (enc values) supported by the server to encode the JWT used as NFV Token"
  static const nfvTokenEncryptionEncValuesSupported =
      'nfv_token_encryption_enc_values_supported';

  ///URL of the OP's UserInfo Endpoint
  static const userinfoEndpoint = 'userinfo_endpoint';

  ///JSON array containing a list of the Authentication Context Class References that this OP supports
  static const acrValuesSupported = 'acr_values_supported';

  ///JSON array containing a list of the Subject Identifier types that this OP supports
  static const subjectTypesSupported = 'subject_types_supported';

  ///JSON array containing a list of the JWS "alg" values supported by the OP for the ID Token
  static const idTokenSigningAlgValuesSupported =
      'id_token_signing_alg_values_supported';

  ///JSON array containing a list of the JWE "alg" values supported by the OP for the ID Token
  static const idTokenEncryptionAlgValuesSupported =
      'id_token_encryption_alg_values_supported';

  ///JSON array containing a list of the JWE "enc" values supported by the OP for the ID Token
  static const idTokenEncryptionEncValuesSupported =
      'id_token_encryption_enc_values_supported';

  ///JSON array containing a list of the JWS "alg" values supported by the UserInfo Endpoint
  static const userinfoSigningAlgValuesSupported =
      'userinfo_signing_alg_values_supported';

  ///JSON array containing a list of the JWE "alg" values supported by the UserInfo Endpoint
  static const userinfoEncryptionAlgValuesSupported =
      'userinfo_encryption_alg_values_supported';

  ///JSON array containing a list of the JWE "enc" values supported by the UserInfo Endpoint
  static const userinfoEncryptionEncValuesSupported =
      'userinfo_encryption_enc_values_supported';

  ///JSON array containing a list of the JWS "alg" values supported by the OP for Request Objects
  static const requestObjectSigningAlgValuesSupported =
      'request_object_signing_alg_values_supported';

  ///JSON array containing a list of the JWE "alg" values supported by the OP for Request Objects
  static const requestObjectEncryptionAlgValuesSupported =
      'request_object_encryption_alg_values_supported';

  ///JSON array containing a list of the JWE "enc" values supported by the OP for Request Objects
  static const requestObjectEncryptionEncValuesSupported =
      'request_object_encryption_enc_values_supported';

  ///JSON array containing a list of the "display" parameter values that the OpenID Provider supports
  static const displayValuesSupported = 'display_values_supported';

  ///JSON array containing a list of the Claim Types that the OpenID Provider supports
  static const claimTypesSupported = 'claim_types_supported';

  ///JSON array containing a list of the Claim Names of the Claims that the OpenID Provider MAY be able to supply values for
  static const claimsSupported = 'claims_supported';

  ///Languages and scripts supported for values in Claims being returned, represented as a JSON array of BCP 47 RFC5646 language tag values
  static const claimsLocalesSupported = 'claims_locales_supported';

  ///Boolean value specifying whether the OP supports use of the "claims" parameter
  static const claimsParameterSupported = 'claims_parameter_supported';

  ///Boolean value specifying whether the OP supports use of the "request" parameter
  static const requestParameterSupported = 'request_parameter_supported';

  ///Boolean value specifying whether the OP supports use of the "request_uri" parameter
  static const requestUriParameterSupported = 'request_uri_parameter_supported';

  ///Boolean value specifying whether the OP requires any "request_uri" values used to be pre-registered
  static const requireRequestUriRegistration =
      'require_request_uri_registration';

  ///"Indicates where authorization request needs to be protected as Request Object and provided through either request or request_uri parameter."
  static const requireSignedRequestObject = 'require_signed_request_object';

  ///"URL of the authorization server's pushed authorization request endpoint"
  static const pushedAuthorizationRequestEndpoint =
      'pushed_authorization_request_endpoint';

  ///"Indicates whether the authorization server accepts authorization requests only via PAR."
  static const requirePushedAuthorizationRequests =
      'require_pushed_authorization_requests';

  ///"JSON array containing a list of algorithms supported by the authorization server for introspection response signing."
  static const introspectionSigningAlgValuesSupported =
      'introspection_signing_alg_values_supported';

  ///"JSON array containing a list of algorithms supported by the authorization server for introspection response content key encryption (alg value)."
  static const introspectionEncryptionAlgValuesSupported =
      'introspection_encryption_alg_values_supported';

  ///"JSON array containing a list of algorithms supported by the authorization server for introspection response content encryption (enc value)."
  static const introspectionEncryptionEncValuesSupported =
      'introspection_encryption_enc_values_supported';

  ///Boolean value indicating whether the authorization server provides the iss parameter in the authorization response.
  static const authorizationResponseIssParameterSupported =
      'authorization_response_iss_parameter_supported';

  ///URL of an OP iframe that supports cross-origin communications for session state information with the RP Client, using the HTML5 postMessage API
  static const checkSessionIframe = 'check_session_iframe';

  ///Boolean value specifying whether the OP supports HTTP-based logout, with true indicating support
  static const frontchannelLogoutSupported = 'frontchannel_logout_supported';

  ///Boolean value specifying whether the OP supports back-channel logout, with true indicating support
  static const backchannelLogoutSupported = 'backchannel_logout_supported';

  ///Boolean value specifying whether the OP can pass a sid (session ID) Claim in the Logout Token to identify the RP session with the OP
  static const backchannelLogoutSessionSupported =
      'backchannel_logout_session_supported';

  ///URL at the OP to which an RP can perform a redirect to request that the End-User be logged out at the OP
  static const endSessionEndpoint = 'end_session_endpoint';

  ///Supported CIBA authentication result delivery modes
  static const backchannelTokenDeliveryModesSupported =
      'backchannel_token_delivery_modes_supported';

  ///CIBA Backchannel Authentication Endpoint
  static const backchannelAuthenticationEndpoint =
      'backchannel_authentication_endpoint';

  ///JSON array containing a list of the JWS signing algorithms supported for validation of signed CIBA authentication requests
  static const backchannelAuthenticationRequestSigningAlgValuesSupported =
      'backchannel_authentication_request_signing_alg_values_supported';

  ///Indicates whether the OP supports the use of the CIBA user_code parameter.
  static const backchannelUserCodeParameterSupported =
      'backchannel_user_code_parameter_supported';

  ///JSON array containing the authorization details types the AS supports
  static const authorizationDetailsTypesSupported =
      'authorization_details_types_supported';

  ///JSON array containing a list of the JWS algorithms supported for DPoP proof JWTs
  static const dpopSigningAlgValuesSupported =
      'dpop_signing_alg_values_supported';
}

class OidcConstants_AuthorizeRequest_ResponseMode {
  /// query
  static const String query = 'query';

  /// fragment
  static const String fragment = 'fragment';

  /// form_post
  static const String formPost = 'form_post';

  /// web_message
  static const String webMessage = 'web_message';
}

/// The response_type options defined by the spec
class OidcConstants_AuthorizationEndpoint_ResponseType {
  /// `id_token token`, used for the implicit flow
  // ignore: constant_identifier_names
  static const idToken_Token = <String>[idToken, token];

  /// Authorization Code Flow
  static const String code = 'code';

  /// Used for implicit + hybrid flows.
  static const String idToken = 'id_token';

  /// Used for implicit + hybrid flows.
  static const String token = 'token';

  ///https://openid.net/specs/oauth-v2-multiple-response-types-1_0.html#none
  static const String none = 'none';
}

/// The display options defined by the spec.
class OidcConstants_AuthorizeRequest_Display {
  /// The Authorization Server SHOULD display the authentication and consent UI
  /// consistent with a full User Agent page view.
  ///
  /// If the display parameter is not specified, this is the default display mode.
  static const String page = 'page';

  /// The Authorization Server SHOULD display the authentication and consent UI
  /// consistent with a popup User Agent window.
  ///
  /// The popup User Agent window should be of an appropriate size for a
  /// login-focused dialog and should not obscure the entire window
  /// that it is popping up over.
  static const String popup = 'popup';

  /// The Authorization Server SHOULD display the authentication and consent UI
  /// consistent with a device that leverages a touch interface.
  static const String touch = 'touch';

  /// The Authorization Server SHOULD display the authentication and consent UI
  /// consistent with a "feature phone" type display.
  static const String wap = 'wap';
}

/// The prompt options defined by the spec
class OidcConstants_AuthorizeRequest_Prompt {
  /// The Authorization Server MUST NOT display any authentication or consent
  /// user interface pages.
  ///
  /// An error is returned if an End-User is not already authenticated or the
  /// Client does not have pre-configured consent for the requested Claims or
  /// does not fulfill other conditions for processing the request.
  ///
  /// The error code will typically be login_required, interaction_required, or
  /// another code defined in Section 3.1.2.6.
  ///
  /// This can be used as a method to check for existing authentication and/or consent.
  static const String none = 'none';

  /// The Authorization Server SHOULD prompt the End-User for re-authentication.
  /// If it cannot reauthenticate the End-User, it MUST return an error,
  /// typically login_required.
  static const String login = 'login';

  /// The Authorization Server SHOULD prompt the End-User for consent before
  /// returning information to the Client.
  ///
  /// If it cannot obtain consent, it MUST return an error,
  /// typically consent_required.
  static const String consent = 'consent';

  /// The Authorization Server SHOULD prompt the End-User to select
  /// a user account.
  ///
  /// This enables an End-User who has multiple accounts at the Authorization
  /// Server to select amongst the multiple accounts
  /// that they might have current sessions for.
  ///
  /// If it cannot obtain an account selection choice made by the End-User,
  /// it MUST return an error, typically account_selection_required.
  static const String selectAccount = 'select_account';
}

class OidcConstants_AuthorizeRequest_CodeChallengeMethod {
  /// code_challenge = code_verifier
  static const String plain = 'plain';

  /// code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))
  static const String s256 = 'S256';
}

class OidcConstants_Store {
  static const expiresAt = 'expiresAt';
  static const expiresInReferenceDate = 'expiresInReferenceDate';
  static const currentUserAttributes = 'userAttributes';
  static const currentUserInfo = 'userInfo';
  static const originalUri = 'original_uri';
  static const operationDiscriminator = 'operationDiscriminator';

  static const options = 'options';
  static const extraTokenParams = 'extraTokenParams';
  static const extraTokenHeaders = 'extraTokenHeaders';
  static const currentToken = 'currentToken';

  static const requestType = 'requestType';
  static const frontChannelLogout = 'front-channel-logout';
  // static const latestToken = 'latest';
  // static const idToken = 'id_token';
  // static const accessToken = 'access_token';
  // static const refreshToken = 'refresh_token';
}

class OidcConstants_Exception {
  static const discoveryDocumentUri = 'discoveryDocumentUri';
  static const idToken = 'idToken';
  static const request = 'request';
  static const response = 'response';
  static const statusCode = 'statusCode';
}

///
class OidcConstants_RequestMethod {
  /// GET http method
  static const get = 'GET';

  /// POST http method
  static const post = 'POST';
}
