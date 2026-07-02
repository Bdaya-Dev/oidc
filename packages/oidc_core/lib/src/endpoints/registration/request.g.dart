// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcClientRegistrationRequestToJson(
  OidcClientRegistrationRequest instance,
) => <String, dynamic>{
  'redirect_uris': ?instance.redirectUris?.map((e) => e.toString()).toList(),
  'response_types': ?instance.responseTypes,
  'grant_types': ?instance.grantTypes,
  'application_type': ?instance.applicationType,
  'contacts': ?instance.contacts,
  'client_name': ?instance.clientName,
  'logo_uri': ?instance.logoUri?.toString(),
  'client_uri': ?instance.clientUri?.toString(),
  'policy_uri': ?instance.policyUri?.toString(),
  'tos_uri': ?instance.tosUri?.toString(),
  'jwks_uri': ?instance.jwksUri?.toString(),
  'jwks': ?instance.jwks,
  'sector_identifier_uri': ?instance.sectorIdentifierUri?.toString(),
  'subject_type': ?instance.subjectType,
  'token_endpoint_auth_method': ?instance.tokenEndpointAuthMethod,
  'id_token_signed_response_alg': ?instance.idTokenSignedResponseAlg,
  'scope': ?OidcInternalUtilities.joinSpaceDelimitedList(instance.scope),
  'software_id': ?instance.softwareId,
  'software_version': ?instance.softwareVersion,
  'software_statement': ?instance.softwareStatement,
};
