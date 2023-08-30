// ignore_for_file: camel_case_types

class OidcAuthorizeRequestConstants_ResponseMode {
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
class OidcAuthorizeRequestConstants_ResponseType {
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
class OidcAuthorizeRequestConstants_Display {
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
class OidcAuthorizeRequestConstants_Prompt {
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

class OidcAuthorizeRequestConstants_CodeChallengeMethod {
  /// code_challenge = code_verifier
  static const String plain = 'plain';

  /// code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))
  static const String s256 = 'S256';
}
