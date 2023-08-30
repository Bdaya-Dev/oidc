// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcProviderMetadata _$OidcProviderMetadataFromJson(
        Map<String, dynamic> json) =>
    OidcProviderMetadata(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      issuer: const UriJsonConverter().fromJson(json['issuer'] as String),
      authorizationEndpoint: const UriJsonConverter()
          .fromJson(json['authorization_endpoint'] as String),
      jwksUri: const UriJsonConverter().fromJson(json['jwks_uri'] as String),
      responseTypesSupported:
          (json['response_types_supported'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      subjectTypesSupported: (json['subject_types_supported'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      idTokenSigningAlgValuesSupported:
          (json['id_token_signing_alg_values_supported'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      tokenEndpoint: _$JsonConverterFromJson<String, Uri>(
          json['token_endpoint'], const UriJsonConverter().fromJson),
      userinfoEndpoint: _$JsonConverterFromJson<String, Uri>(
          json['userinfo_endpoint'], const UriJsonConverter().fromJson),
      registrationEndpoint: _$JsonConverterFromJson<String, Uri>(
          json['registration_endpoint'], const UriJsonConverter().fromJson),
      scopesSupported: (json['scopes_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      responseModesSupported:
          (json['response_modes_supported'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              const ['query', 'fragment'],
      grantTypesSupported: (json['grant_types_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['authorization_code', 'implicit'],
      acrValuesSupported: (json['acr_values_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      idTokenEncryptionAlgValuesSupported:
          (json['id_token_encryption_alg_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      requestObjectSigningAlgValuesSupported:
          (json['request_object_signing_alg_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      requestObjectEncryptionAlgValuesSupported:
          (json['request_object_encryption_alg_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      requestObjectEncryptionEncValuesSupported:
          (json['request_object_encryption_enc_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      tokenEndpointAuthSigningAlgValuesSupported:
          (json['token_endpoint_auth_signing_alg_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      tokenEndpointAuthMethodsSupported:
          (json['token_endpoint_auth_methods_supported'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              const ['client_secret_basic'],
      displayValuesSupported:
          (json['display_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      claimTypesSupported: (json['claim_types_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      claimsSupported: (json['claims_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      serviceDocumentation: _$JsonConverterFromJson<String, Uri>(
          json['service_documentation'], const UriJsonConverter().fromJson),
      claimsLocalesSupported:
          (json['claims_locales_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      uiLocalesSupported: (json['ui_locales_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      pushedAuthorizationRequestEndpoint: _$JsonConverterFromJson<String, Uri>(
          json['pushed_authorization_request_endpoint'],
          const UriJsonConverter().fromJson),
      claimsParameterSupported:
          json['claims_parameter_supported'] as bool? ?? false,
      requestParameterSupported:
          json['request_parameter_supported'] as bool? ?? false,
      requireRequestUriRegistration:
          json['require_request_uri_registration'] as bool? ?? false,
      requestUriParameterSupported:
          json['request_uri_parameter_supported'] as bool? ?? true,
      requirePushedAuthorizationRequests:
          json['require_pushed_authorization_requests'] as bool? ?? false,
      opPolicyUri: _$JsonConverterFromJson<String, Uri>(
          json['op_policy_uri'], const UriJsonConverter().fromJson),
      opTosUri: _$JsonConverterFromJson<String, Uri>(
          json['op_tos_uri'], const UriJsonConverter().fromJson),
      checkSessionIframe: _$JsonConverterFromJson<String, Uri>(
          json['check_session_iframe'], const UriJsonConverter().fromJson),
      endSessionEndpoint: _$JsonConverterFromJson<String, Uri>(
          json['end_session_endpoint'], const UriJsonConverter().fromJson),
      revocationEndpoint: _$JsonConverterFromJson<String, Uri>(
          json['revocation_endpoint'], const UriJsonConverter().fromJson),
      revocationEndpointAuthMethodsSupported:
          (json['revocation_endpoint_auth_methods_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      revocationEndpointAuthSigningAlgValuesSupported:
          (json['revocation_endpoint_auth_signing_alg_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      introspectionEndpoint: _$JsonConverterFromJson<String, Uri>(
          json['introspection_endpoint'], const UriJsonConverter().fromJson),
      introspectionEndpointAuthMethodsSupported:
          (json['introspection_endpoint_auth_methods_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      introspectionEndpointAuthSigningAlgValuesSupported:
          (json['introspection_endpoint_auth_signing_alg_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      codeChallengeMethodsSupported:
          (json['code_challenge_methods_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      idTokenEncryptionEncValuesSupported:
          (json['id_token_encryption_enc_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      userinfoSigningAlgValuesSupported:
          (json['userinfo_signing_alg_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      userinfoEncryptionAlgValuesSupported:
          (json['userinfo_encryption_alg_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      userinfoEncryptionEncValuesSupported:
          (json['userinfo_encryption_enc_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
    );

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
