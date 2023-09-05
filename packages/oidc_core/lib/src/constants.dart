// ignore_for_file: camel_case_types

class OidcConstants_GrantType {
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

class OidcConstants_AuthorizeRequest {
  static const nonce = 'nonce';
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
class OidcConstants_AuthorizeRequest_ResponseType {
  /// Authorization Code Flow
  static const String code = 'code';

  /// Used for implicit + hybrid flows.
  static const String idToken = 'id_token';

  /// Used for implicit + hybrid flows.
  static const String token = 'token';

  ///https://openid.net/specs/oauth-v2-multiple-response-types-1_0.html#none
  static const String none = 'none';
}

/// The display options defind by the spec.
class OidcConstants_AuthorizeRequest_Display {
  /// The Authorization Server SHOULD display the authentication and consent UI
  /// consistent with a full User Agent page view. If the display parameter is
  /// not specified, this is the default display mode.
  static const String page = 'page';

  /// The Authorization Server SHOULD display the authentication and consent UI
  /// consistent with a popup User Agent window. The popup User Agent window
  /// should be of an appropriate size for a login-focused dialog and should not
  /// obscure the entire window that it is popping up over.
  static const String popup = 'popup';

  /// The Authorization Server SHOULD display the authentication and consent UI
  /// consistent with a device that leverages a touch interface.
  static const String touch = 'touch';

  /// The Authorization Server SHOULD display the authentication and consent UI
  /// consistent with a "feature phone" type display.
  static const String wap = 'wap';
}

/// The prompt options defind by the spec
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

  /// The Authorization Server SHOULD prompt the End-User for reauthentication.
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
  static const latestToken = 'latest';
  static const idToken = 'id_token';
  static const accessToken = 'access_token';
  static const refreshToken = 'refresh_token';
}

class OidcConstants_PKCE {
  static const codeVerifier = 'code_verifier';
  static const codeChallenge = 'code_challenge';
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
