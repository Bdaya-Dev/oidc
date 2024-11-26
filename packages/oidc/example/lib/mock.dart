import 'dart:convert';

final duendeDiscoveryDocument = jsonEncode({
  'issuer': 'https://demo.duendesoftware.com',
  'jwks_uri':
      'https://demo.duendesoftware.com/.well-known/openid-configuration/jwks',
  'authorization_endpoint': 'https://demo.duendesoftware.com/connect/authorize',
  'token_endpoint': 'https://demo.duendesoftware.com/connect/token',
  'userinfo_endpoint': 'https://demo.duendesoftware.com/connect/userinfo',
  'end_session_endpoint': 'https://demo.duendesoftware.com/connect/endsession',
  'check_session_iframe':
      'https://demo.duendesoftware.com/connect/checksession',
  'revocation_endpoint': 'https://demo.duendesoftware.com/connect/revocation',
  'introspection_endpoint':
      'https://demo.duendesoftware.com/connect/introspect',
  'device_authorization_endpoint':
      'https://demo.duendesoftware.com/connect/deviceauthorization',
  'backchannel_authentication_endpoint':
      'https://demo.duendesoftware.com/connect/ciba',
  'pushed_authorization_request_endpoint':
      'https://demo.duendesoftware.com/connect/par',
  'require_pushed_authorization_requests': false,
  'frontchannel_logout_supported': true,
  'frontchannel_logout_session_supported': true,
  'backchannel_logout_supported': true,
  'backchannel_logout_session_supported': true,
  'scopes_supported': [
    'openid',
    'profile',
    'email',
    'api',
    'resource1.scope1',
    'resource1.scope2',
    'resource2.scope1',
    'resource2.scope2',
    'resource3.scope1',
    'resource3.scope2',
    'scope3',
    'scope4',
    'shared.scope',
    'transaction',
    'offline_access',
  ],
  'claims_supported': [
    'sub',
    'name',
    'family_name',
    'given_name',
    'middle_name',
    'nickname',
    'preferred_username',
    'profile',
    'picture',
    'website',
    'gender',
    'birthdate',
    'zoneinfo',
    'locale',
    'updated_at',
    'email',
    'email_verified',
  ],
  'grant_types_supported': [
    'authorization_code',
    'client_credentials',
    'refresh_token',
    'implicit',
    'password',
    'urn:ietf:params:oauth:grant-type:device_code',
    'urn:openid:params:grant-type:ciba',
  ],
  'response_types_supported': [
    'code',
    'token',
    'id_token',
    'id_token token',
    'code id_token',
    'code token',
    'code id_token token',
  ],
  'response_modes_supported': ['form_post', 'query', 'fragment'],
  'token_endpoint_auth_methods_supported': [
    'client_secret_basic',
    'client_secret_post',
    'private_key_jwt',
  ],
  'id_token_signing_alg_values_supported': ['RS256'],
  'subject_types_supported': ['public'],
  'code_challenge_methods_supported': ['plain', 'S256'],
  'request_parameter_supported': true,
  'request_object_signing_alg_values_supported': [
    'RS256',
    'RS384',
    'RS512',
    'PS256',
    'PS384',
    'PS512',
    'ES256',
    'ES384',
    'ES512',
    'HS256',
    'HS384',
    'HS512',
  ],
  'prompt_values_supported': ['none', 'login', 'consent', 'select_account'],
  'authorization_response_iss_parameter_supported': true,
  'backchannel_token_delivery_modes_supported': ['poll'],
  'backchannel_user_code_parameter_supported': true,
  'dpop_signing_alg_values_supported': [
    'RS256',
    'RS384',
    'RS512',
    'PS256',
    'PS384',
    'PS512',
    'ES256',
    'ES384',
    'ES512',
  ],
});
