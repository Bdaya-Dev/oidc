// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resp.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcProviderMetadata _$OidcProviderMetadataFromJson(
        Map<String, dynamic> json) =>
    OidcProviderMetadata(
      src: readSrcMap(json, '') as Map<String, dynamic>,
      issuer:
          json['issuer'] == null ? null : Uri.parse(json['issuer'] as String),
      authorizationEndpoint: json['authorization_endpoint'] == null
          ? null
          : Uri.parse(json['authorization_endpoint'] as String),
      jwksUri: json['jwks_uri'] == null
          ? null
          : Uri.parse(json['jwks_uri'] as String),
      responseTypesSupported:
          (json['response_types_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      subjectTypesSupported: (json['subject_types_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      idTokenSigningAlgValuesSupported:
          (json['id_token_signing_alg_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      tokenEndpoint: json['token_endpoint'] == null
          ? null
          : Uri.parse(json['token_endpoint'] as String),
      userinfoEndpoint: json['userinfo_endpoint'] == null
          ? null
          : Uri.parse(json['userinfo_endpoint'] as String),
      registrationEndpoint: json['registration_endpoint'] == null
          ? null
          : Uri.parse(json['registration_endpoint'] as String),
      scopesSupported: (json['scopes_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      responseModesSupported:
          (json['response_modes_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      grantTypesSupported: (json['grant_types_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
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
              .toList(),
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
      serviceDocumentation: json['service_documentation'] == null
          ? null
          : Uri.parse(json['service_documentation'] as String),
      claimsLocalesSupported:
          (json['claims_locales_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      uiLocalesSupported: (json['ui_locales_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      pushedAuthorizationRequestEndpoint:
          json['pushed_authorization_request_endpoint'] == null
              ? null
              : Uri.parse(
                  json['pushed_authorization_request_endpoint'] as String),
      claimsParameterSupported: json['claims_parameter_supported'] as bool?,
      requestParameterSupported: json['request_parameter_supported'] as bool?,
      requireRequestUriRegistration:
          json['require_request_uri_registration'] as bool?,
      requestUriParameterSupported:
          json['request_uri_parameter_supported'] as bool?,
      requirePushedAuthorizationRequests:
          json['require_pushed_authorization_requests'] as bool?,
      opPolicyUri: json['op_policy_uri'] == null
          ? null
          : Uri.parse(json['op_policy_uri'] as String),
      opTosUri: json['op_tos_uri'] == null
          ? null
          : Uri.parse(json['op_tos_uri'] as String),
      checkSessionIframe: json['check_session_iframe'] == null
          ? null
          : Uri.parse(json['check_session_iframe'] as String),
      endSessionEndpoint: json['end_session_endpoint'] == null
          ? null
          : Uri.parse(json['end_session_endpoint'] as String),
      revocationEndpoint: json['revocation_endpoint'] == null
          ? null
          : Uri.parse(json['revocation_endpoint'] as String),
      revocationEndpointAuthMethodsSupported:
          (json['revocation_endpoint_auth_methods_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      revocationEndpointAuthSigningAlgValuesSupported:
          (json['revocation_endpoint_auth_signing_alg_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      introspectionEndpoint: json['introspection_endpoint'] == null
          ? null
          : Uri.parse(json['introspection_endpoint'] as String),
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
