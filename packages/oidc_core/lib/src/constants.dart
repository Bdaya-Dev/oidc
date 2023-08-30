/// These grant types are used when talking to the /token endpoint
class OidcGrantTypes {
  static const String deviceCode =
      'urn:ietf:params:oauth:grant-type:device_code';
  static const String authorizationCode = 'authorization_code';
  static const String refreshToken = 'refresh_token';
  static const String password = 'password';
  static const String clientCredentials = 'client_credentials';
  static const String jwtBearer = 'urn:ietf:params:oauth:grant-type:jwt-bearer';
  static const String umaTicket = 'urn:ietf:params:oauth:grant-type:uma-ticket';
  static const String saml2Bearer =
      'urn:ietf:params:oauth:grant-type:saml2-bearer';
  static const String tokenExchange =
      'urn:ietf:params:oauth:grant-type:token-exchange';
  static const String ciba = 'urn:openid:params:grant-type:ciba';
}
