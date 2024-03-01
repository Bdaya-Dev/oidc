// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resp.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OidcProviderMetadataCWProxy {
  OidcProviderMetadata src(Map<String, dynamic> src);

  OidcProviderMetadata issuer(Uri? issuer);

  OidcProviderMetadata authorizationEndpoint(Uri? authorizationEndpoint);

  OidcProviderMetadata jwksUri(Uri? jwksUri);

  OidcProviderMetadata responseTypesSupported(
      List<String>? responseTypesSupported);

  OidcProviderMetadata subjectTypesSupported(
      List<String>? subjectTypesSupported);

  OidcProviderMetadata idTokenSigningAlgValuesSupported(
      List<String>? idTokenSigningAlgValuesSupported);

  OidcProviderMetadata tokenEndpoint(Uri? tokenEndpoint);

  OidcProviderMetadata userinfoEndpoint(Uri? userinfoEndpoint);

  OidcProviderMetadata registrationEndpoint(Uri? registrationEndpoint);

  OidcProviderMetadata scopesSupported(List<String>? scopesSupported);

  OidcProviderMetadata responseModesSupported(
      List<String>? responseModesSupported);

  OidcProviderMetadata grantTypesSupported(List<String>? grantTypesSupported);

  OidcProviderMetadata acrValuesSupported(List<String>? acrValuesSupported);

  OidcProviderMetadata idTokenEncryptionAlgValuesSupported(
      List<String>? idTokenEncryptionAlgValuesSupported);

  OidcProviderMetadata requestObjectSigningAlgValuesSupported(
      List<String>? requestObjectSigningAlgValuesSupported);

  OidcProviderMetadata requestObjectEncryptionAlgValuesSupported(
      List<String>? requestObjectEncryptionAlgValuesSupported);

  OidcProviderMetadata requestObjectEncryptionEncValuesSupported(
      List<String>? requestObjectEncryptionEncValuesSupported);

  OidcProviderMetadata tokenEndpointAuthSigningAlgValuesSupported(
      List<String>? tokenEndpointAuthSigningAlgValuesSupported);

  OidcProviderMetadata tokenEndpointAuthMethodsSupported(
      List<String>? tokenEndpointAuthMethodsSupported);

  OidcProviderMetadata displayValuesSupported(
      List<String>? displayValuesSupported);

  OidcProviderMetadata claimTypesSupported(List<String>? claimTypesSupported);

  OidcProviderMetadata claimsSupported(List<String>? claimsSupported);

  OidcProviderMetadata serviceDocumentation(Uri? serviceDocumentation);

  OidcProviderMetadata claimsLocalesSupported(
      List<String>? claimsLocalesSupported);

  OidcProviderMetadata uiLocalesSupported(List<String>? uiLocalesSupported);

  OidcProviderMetadata pushedAuthorizationRequestEndpoint(
      Uri? pushedAuthorizationRequestEndpoint);

  OidcProviderMetadata claimsParameterSupported(bool? claimsParameterSupported);

  OidcProviderMetadata requestParameterSupported(
      bool? requestParameterSupported);

  OidcProviderMetadata requireRequestUriRegistration(
      bool? requireRequestUriRegistration);

  OidcProviderMetadata requestUriParameterSupported(
      bool? requestUriParameterSupported);

  OidcProviderMetadata requirePushedAuthorizationRequests(
      bool? requirePushedAuthorizationRequests);

  OidcProviderMetadata opPolicyUri(Uri? opPolicyUri);

  OidcProviderMetadata opTosUri(Uri? opTosUri);

  OidcProviderMetadata checkSessionIframe(Uri? checkSessionIframe);

  OidcProviderMetadata endSessionEndpoint(Uri? endSessionEndpoint);

  OidcProviderMetadata revocationEndpoint(Uri? revocationEndpoint);

  OidcProviderMetadata revocationEndpointAuthMethodsSupported(
      List<String>? revocationEndpointAuthMethodsSupported);

  OidcProviderMetadata revocationEndpointAuthSigningAlgValuesSupported(
      List<String>? revocationEndpointAuthSigningAlgValuesSupported);

  OidcProviderMetadata introspectionEndpoint(Uri? introspectionEndpoint);

  OidcProviderMetadata introspectionEndpointAuthMethodsSupported(
      List<String>? introspectionEndpointAuthMethodsSupported);

  OidcProviderMetadata introspectionEndpointAuthSigningAlgValuesSupported(
      List<String>? introspectionEndpointAuthSigningAlgValuesSupported);

  OidcProviderMetadata codeChallengeMethodsSupported(
      List<String>? codeChallengeMethodsSupported);

  OidcProviderMetadata idTokenEncryptionEncValuesSupported(
      List<String>? idTokenEncryptionEncValuesSupported);

  OidcProviderMetadata userinfoSigningAlgValuesSupported(
      List<String>? userinfoSigningAlgValuesSupported);

  OidcProviderMetadata userinfoEncryptionAlgValuesSupported(
      List<String>? userinfoEncryptionAlgValuesSupported);

  OidcProviderMetadata userinfoEncryptionEncValuesSupported(
      List<String>? userinfoEncryptionEncValuesSupported);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OidcProviderMetadata(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OidcProviderMetadata(...).copyWith(id: 12, name: "My name")
  /// ````
  OidcProviderMetadata call({
    Map<String, dynamic>? src,
    Uri? issuer,
    Uri? authorizationEndpoint,
    Uri? jwksUri,
    List<String>? responseTypesSupported,
    List<String>? subjectTypesSupported,
    List<String>? idTokenSigningAlgValuesSupported,
    Uri? tokenEndpoint,
    Uri? userinfoEndpoint,
    Uri? registrationEndpoint,
    List<String>? scopesSupported,
    List<String>? responseModesSupported,
    List<String>? grantTypesSupported,
    List<String>? acrValuesSupported,
    List<String>? idTokenEncryptionAlgValuesSupported,
    List<String>? requestObjectSigningAlgValuesSupported,
    List<String>? requestObjectEncryptionAlgValuesSupported,
    List<String>? requestObjectEncryptionEncValuesSupported,
    List<String>? tokenEndpointAuthSigningAlgValuesSupported,
    List<String>? tokenEndpointAuthMethodsSupported,
    List<String>? displayValuesSupported,
    List<String>? claimTypesSupported,
    List<String>? claimsSupported,
    Uri? serviceDocumentation,
    List<String>? claimsLocalesSupported,
    List<String>? uiLocalesSupported,
    Uri? pushedAuthorizationRequestEndpoint,
    bool? claimsParameterSupported,
    bool? requestParameterSupported,
    bool? requireRequestUriRegistration,
    bool? requestUriParameterSupported,
    bool? requirePushedAuthorizationRequests,
    Uri? opPolicyUri,
    Uri? opTosUri,
    Uri? checkSessionIframe,
    Uri? endSessionEndpoint,
    Uri? revocationEndpoint,
    List<String>? revocationEndpointAuthMethodsSupported,
    List<String>? revocationEndpointAuthSigningAlgValuesSupported,
    Uri? introspectionEndpoint,
    List<String>? introspectionEndpointAuthMethodsSupported,
    List<String>? introspectionEndpointAuthSigningAlgValuesSupported,
    List<String>? codeChallengeMethodsSupported,
    List<String>? idTokenEncryptionEncValuesSupported,
    List<String>? userinfoSigningAlgValuesSupported,
    List<String>? userinfoEncryptionAlgValuesSupported,
    List<String>? userinfoEncryptionEncValuesSupported,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOidcProviderMetadata.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOidcProviderMetadata.copyWith.fieldName(...)`
class _$OidcProviderMetadataCWProxyImpl
    implements _$OidcProviderMetadataCWProxy {
  const _$OidcProviderMetadataCWProxyImpl(this._value);

  final OidcProviderMetadata _value;

  @override
  OidcProviderMetadata src(Map<String, dynamic> src) => this(src: src);

  @override
  OidcProviderMetadata issuer(Uri? issuer) => this(issuer: issuer);

  @override
  OidcProviderMetadata authorizationEndpoint(Uri? authorizationEndpoint) =>
      this(authorizationEndpoint: authorizationEndpoint);

  @override
  OidcProviderMetadata jwksUri(Uri? jwksUri) => this(jwksUri: jwksUri);

  @override
  OidcProviderMetadata responseTypesSupported(
          List<String>? responseTypesSupported) =>
      this(responseTypesSupported: responseTypesSupported);

  @override
  OidcProviderMetadata subjectTypesSupported(
          List<String>? subjectTypesSupported) =>
      this(subjectTypesSupported: subjectTypesSupported);

  @override
  OidcProviderMetadata idTokenSigningAlgValuesSupported(
          List<String>? idTokenSigningAlgValuesSupported) =>
      this(idTokenSigningAlgValuesSupported: idTokenSigningAlgValuesSupported);

  @override
  OidcProviderMetadata tokenEndpoint(Uri? tokenEndpoint) =>
      this(tokenEndpoint: tokenEndpoint);

  @override
  OidcProviderMetadata userinfoEndpoint(Uri? userinfoEndpoint) =>
      this(userinfoEndpoint: userinfoEndpoint);

  @override
  OidcProviderMetadata registrationEndpoint(Uri? registrationEndpoint) =>
      this(registrationEndpoint: registrationEndpoint);

  @override
  OidcProviderMetadata scopesSupported(List<String>? scopesSupported) =>
      this(scopesSupported: scopesSupported);

  @override
  OidcProviderMetadata responseModesSupported(
          List<String>? responseModesSupported) =>
      this(responseModesSupported: responseModesSupported);

  @override
  OidcProviderMetadata grantTypesSupported(List<String>? grantTypesSupported) =>
      this(grantTypesSupported: grantTypesSupported);

  @override
  OidcProviderMetadata acrValuesSupported(List<String>? acrValuesSupported) =>
      this(acrValuesSupported: acrValuesSupported);

  @override
  OidcProviderMetadata idTokenEncryptionAlgValuesSupported(
          List<String>? idTokenEncryptionAlgValuesSupported) =>
      this(
          idTokenEncryptionAlgValuesSupported:
              idTokenEncryptionAlgValuesSupported);

  @override
  OidcProviderMetadata requestObjectSigningAlgValuesSupported(
          List<String>? requestObjectSigningAlgValuesSupported) =>
      this(
          requestObjectSigningAlgValuesSupported:
              requestObjectSigningAlgValuesSupported);

  @override
  OidcProviderMetadata requestObjectEncryptionAlgValuesSupported(
          List<String>? requestObjectEncryptionAlgValuesSupported) =>
      this(
          requestObjectEncryptionAlgValuesSupported:
              requestObjectEncryptionAlgValuesSupported);

  @override
  OidcProviderMetadata requestObjectEncryptionEncValuesSupported(
          List<String>? requestObjectEncryptionEncValuesSupported) =>
      this(
          requestObjectEncryptionEncValuesSupported:
              requestObjectEncryptionEncValuesSupported);

  @override
  OidcProviderMetadata tokenEndpointAuthSigningAlgValuesSupported(
          List<String>? tokenEndpointAuthSigningAlgValuesSupported) =>
      this(
          tokenEndpointAuthSigningAlgValuesSupported:
              tokenEndpointAuthSigningAlgValuesSupported);

  @override
  OidcProviderMetadata tokenEndpointAuthMethodsSupported(
          List<String>? tokenEndpointAuthMethodsSupported) =>
      this(
          tokenEndpointAuthMethodsSupported: tokenEndpointAuthMethodsSupported);

  @override
  OidcProviderMetadata displayValuesSupported(
          List<String>? displayValuesSupported) =>
      this(displayValuesSupported: displayValuesSupported);

  @override
  OidcProviderMetadata claimTypesSupported(List<String>? claimTypesSupported) =>
      this(claimTypesSupported: claimTypesSupported);

  @override
  OidcProviderMetadata claimsSupported(List<String>? claimsSupported) =>
      this(claimsSupported: claimsSupported);

  @override
  OidcProviderMetadata serviceDocumentation(Uri? serviceDocumentation) =>
      this(serviceDocumentation: serviceDocumentation);

  @override
  OidcProviderMetadata claimsLocalesSupported(
          List<String>? claimsLocalesSupported) =>
      this(claimsLocalesSupported: claimsLocalesSupported);

  @override
  OidcProviderMetadata uiLocalesSupported(List<String>? uiLocalesSupported) =>
      this(uiLocalesSupported: uiLocalesSupported);

  @override
  OidcProviderMetadata pushedAuthorizationRequestEndpoint(
          Uri? pushedAuthorizationRequestEndpoint) =>
      this(
          pushedAuthorizationRequestEndpoint:
              pushedAuthorizationRequestEndpoint);

  @override
  OidcProviderMetadata claimsParameterSupported(
          bool? claimsParameterSupported) =>
      this(claimsParameterSupported: claimsParameterSupported);

  @override
  OidcProviderMetadata requestParameterSupported(
          bool? requestParameterSupported) =>
      this(requestParameterSupported: requestParameterSupported);

  @override
  OidcProviderMetadata requireRequestUriRegistration(
          bool? requireRequestUriRegistration) =>
      this(requireRequestUriRegistration: requireRequestUriRegistration);

  @override
  OidcProviderMetadata requestUriParameterSupported(
          bool? requestUriParameterSupported) =>
      this(requestUriParameterSupported: requestUriParameterSupported);

  @override
  OidcProviderMetadata requirePushedAuthorizationRequests(
          bool? requirePushedAuthorizationRequests) =>
      this(
          requirePushedAuthorizationRequests:
              requirePushedAuthorizationRequests);

  @override
  OidcProviderMetadata opPolicyUri(Uri? opPolicyUri) =>
      this(opPolicyUri: opPolicyUri);

  @override
  OidcProviderMetadata opTosUri(Uri? opTosUri) => this(opTosUri: opTosUri);

  @override
  OidcProviderMetadata checkSessionIframe(Uri? checkSessionIframe) =>
      this(checkSessionIframe: checkSessionIframe);

  @override
  OidcProviderMetadata endSessionEndpoint(Uri? endSessionEndpoint) =>
      this(endSessionEndpoint: endSessionEndpoint);

  @override
  OidcProviderMetadata revocationEndpoint(Uri? revocationEndpoint) =>
      this(revocationEndpoint: revocationEndpoint);

  @override
  OidcProviderMetadata revocationEndpointAuthMethodsSupported(
          List<String>? revocationEndpointAuthMethodsSupported) =>
      this(
          revocationEndpointAuthMethodsSupported:
              revocationEndpointAuthMethodsSupported);

  @override
  OidcProviderMetadata revocationEndpointAuthSigningAlgValuesSupported(
          List<String>? revocationEndpointAuthSigningAlgValuesSupported) =>
      this(
          revocationEndpointAuthSigningAlgValuesSupported:
              revocationEndpointAuthSigningAlgValuesSupported);

  @override
  OidcProviderMetadata introspectionEndpoint(Uri? introspectionEndpoint) =>
      this(introspectionEndpoint: introspectionEndpoint);

  @override
  OidcProviderMetadata introspectionEndpointAuthMethodsSupported(
          List<String>? introspectionEndpointAuthMethodsSupported) =>
      this(
          introspectionEndpointAuthMethodsSupported:
              introspectionEndpointAuthMethodsSupported);

  @override
  OidcProviderMetadata introspectionEndpointAuthSigningAlgValuesSupported(
          List<String>? introspectionEndpointAuthSigningAlgValuesSupported) =>
      this(
          introspectionEndpointAuthSigningAlgValuesSupported:
              introspectionEndpointAuthSigningAlgValuesSupported);

  @override
  OidcProviderMetadata codeChallengeMethodsSupported(
          List<String>? codeChallengeMethodsSupported) =>
      this(codeChallengeMethodsSupported: codeChallengeMethodsSupported);

  @override
  OidcProviderMetadata idTokenEncryptionEncValuesSupported(
          List<String>? idTokenEncryptionEncValuesSupported) =>
      this(
          idTokenEncryptionEncValuesSupported:
              idTokenEncryptionEncValuesSupported);

  @override
  OidcProviderMetadata userinfoSigningAlgValuesSupported(
          List<String>? userinfoSigningAlgValuesSupported) =>
      this(
          userinfoSigningAlgValuesSupported: userinfoSigningAlgValuesSupported);

  @override
  OidcProviderMetadata userinfoEncryptionAlgValuesSupported(
          List<String>? userinfoEncryptionAlgValuesSupported) =>
      this(
          userinfoEncryptionAlgValuesSupported:
              userinfoEncryptionAlgValuesSupported);

  @override
  OidcProviderMetadata userinfoEncryptionEncValuesSupported(
          List<String>? userinfoEncryptionEncValuesSupported) =>
      this(
          userinfoEncryptionEncValuesSupported:
              userinfoEncryptionEncValuesSupported);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OidcProviderMetadata(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OidcProviderMetadata(...).copyWith(id: 12, name: "My name")
  /// ````
  OidcProviderMetadata call({
    Object? src = const $CopyWithPlaceholder(),
    Object? issuer = const $CopyWithPlaceholder(),
    Object? authorizationEndpoint = const $CopyWithPlaceholder(),
    Object? jwksUri = const $CopyWithPlaceholder(),
    Object? responseTypesSupported = const $CopyWithPlaceholder(),
    Object? subjectTypesSupported = const $CopyWithPlaceholder(),
    Object? idTokenSigningAlgValuesSupported = const $CopyWithPlaceholder(),
    Object? tokenEndpoint = const $CopyWithPlaceholder(),
    Object? userinfoEndpoint = const $CopyWithPlaceholder(),
    Object? registrationEndpoint = const $CopyWithPlaceholder(),
    Object? scopesSupported = const $CopyWithPlaceholder(),
    Object? responseModesSupported = const $CopyWithPlaceholder(),
    Object? grantTypesSupported = const $CopyWithPlaceholder(),
    Object? acrValuesSupported = const $CopyWithPlaceholder(),
    Object? idTokenEncryptionAlgValuesSupported = const $CopyWithPlaceholder(),
    Object? requestObjectSigningAlgValuesSupported =
        const $CopyWithPlaceholder(),
    Object? requestObjectEncryptionAlgValuesSupported =
        const $CopyWithPlaceholder(),
    Object? requestObjectEncryptionEncValuesSupported =
        const $CopyWithPlaceholder(),
    Object? tokenEndpointAuthSigningAlgValuesSupported =
        const $CopyWithPlaceholder(),
    Object? tokenEndpointAuthMethodsSupported = const $CopyWithPlaceholder(),
    Object? displayValuesSupported = const $CopyWithPlaceholder(),
    Object? claimTypesSupported = const $CopyWithPlaceholder(),
    Object? claimsSupported = const $CopyWithPlaceholder(),
    Object? serviceDocumentation = const $CopyWithPlaceholder(),
    Object? claimsLocalesSupported = const $CopyWithPlaceholder(),
    Object? uiLocalesSupported = const $CopyWithPlaceholder(),
    Object? pushedAuthorizationRequestEndpoint = const $CopyWithPlaceholder(),
    Object? claimsParameterSupported = const $CopyWithPlaceholder(),
    Object? requestParameterSupported = const $CopyWithPlaceholder(),
    Object? requireRequestUriRegistration = const $CopyWithPlaceholder(),
    Object? requestUriParameterSupported = const $CopyWithPlaceholder(),
    Object? requirePushedAuthorizationRequests = const $CopyWithPlaceholder(),
    Object? opPolicyUri = const $CopyWithPlaceholder(),
    Object? opTosUri = const $CopyWithPlaceholder(),
    Object? checkSessionIframe = const $CopyWithPlaceholder(),
    Object? endSessionEndpoint = const $CopyWithPlaceholder(),
    Object? revocationEndpoint = const $CopyWithPlaceholder(),
    Object? revocationEndpointAuthMethodsSupported =
        const $CopyWithPlaceholder(),
    Object? revocationEndpointAuthSigningAlgValuesSupported =
        const $CopyWithPlaceholder(),
    Object? introspectionEndpoint = const $CopyWithPlaceholder(),
    Object? introspectionEndpointAuthMethodsSupported =
        const $CopyWithPlaceholder(),
    Object? introspectionEndpointAuthSigningAlgValuesSupported =
        const $CopyWithPlaceholder(),
    Object? codeChallengeMethodsSupported = const $CopyWithPlaceholder(),
    Object? idTokenEncryptionEncValuesSupported = const $CopyWithPlaceholder(),
    Object? userinfoSigningAlgValuesSupported = const $CopyWithPlaceholder(),
    Object? userinfoEncryptionAlgValuesSupported = const $CopyWithPlaceholder(),
    Object? userinfoEncryptionEncValuesSupported = const $CopyWithPlaceholder(),
  }) {
    return OidcProviderMetadata._(
      src: src == const $CopyWithPlaceholder() || src == null
          ? _value.src
          // ignore: cast_nullable_to_non_nullable
          : src as Map<String, dynamic>,
      issuer: issuer == const $CopyWithPlaceholder()
          ? _value.issuer
          // ignore: cast_nullable_to_non_nullable
          : issuer as Uri?,
      authorizationEndpoint:
          authorizationEndpoint == const $CopyWithPlaceholder()
              ? _value.authorizationEndpoint
              // ignore: cast_nullable_to_non_nullable
              : authorizationEndpoint as Uri?,
      jwksUri: jwksUri == const $CopyWithPlaceholder()
          ? _value.jwksUri
          // ignore: cast_nullable_to_non_nullable
          : jwksUri as Uri?,
      responseTypesSupported:
          responseTypesSupported == const $CopyWithPlaceholder()
              ? _value.responseTypesSupported
              // ignore: cast_nullable_to_non_nullable
              : responseTypesSupported as List<String>?,
      subjectTypesSupported:
          subjectTypesSupported == const $CopyWithPlaceholder()
              ? _value.subjectTypesSupported
              // ignore: cast_nullable_to_non_nullable
              : subjectTypesSupported as List<String>?,
      idTokenSigningAlgValuesSupported:
          idTokenSigningAlgValuesSupported == const $CopyWithPlaceholder()
              ? _value.idTokenSigningAlgValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : idTokenSigningAlgValuesSupported as List<String>?,
      tokenEndpoint: tokenEndpoint == const $CopyWithPlaceholder()
          ? _value.tokenEndpoint
          // ignore: cast_nullable_to_non_nullable
          : tokenEndpoint as Uri?,
      userinfoEndpoint: userinfoEndpoint == const $CopyWithPlaceholder()
          ? _value.userinfoEndpoint
          // ignore: cast_nullable_to_non_nullable
          : userinfoEndpoint as Uri?,
      registrationEndpoint: registrationEndpoint == const $CopyWithPlaceholder()
          ? _value.registrationEndpoint
          // ignore: cast_nullable_to_non_nullable
          : registrationEndpoint as Uri?,
      scopesSupported: scopesSupported == const $CopyWithPlaceholder()
          ? _value.scopesSupported
          // ignore: cast_nullable_to_non_nullable
          : scopesSupported as List<String>?,
      responseModesSupported:
          responseModesSupported == const $CopyWithPlaceholder()
              ? _value.responseModesSupported
              // ignore: cast_nullable_to_non_nullable
              : responseModesSupported as List<String>?,
      grantTypesSupported: grantTypesSupported == const $CopyWithPlaceholder()
          ? _value.grantTypesSupported
          // ignore: cast_nullable_to_non_nullable
          : grantTypesSupported as List<String>?,
      acrValuesSupported: acrValuesSupported == const $CopyWithPlaceholder()
          ? _value.acrValuesSupported
          // ignore: cast_nullable_to_non_nullable
          : acrValuesSupported as List<String>?,
      idTokenEncryptionAlgValuesSupported:
          idTokenEncryptionAlgValuesSupported == const $CopyWithPlaceholder()
              ? _value.idTokenEncryptionAlgValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : idTokenEncryptionAlgValuesSupported as List<String>?,
      requestObjectSigningAlgValuesSupported:
          requestObjectSigningAlgValuesSupported == const $CopyWithPlaceholder()
              ? _value.requestObjectSigningAlgValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : requestObjectSigningAlgValuesSupported as List<String>?,
      requestObjectEncryptionAlgValuesSupported:
          requestObjectEncryptionAlgValuesSupported ==
                  const $CopyWithPlaceholder()
              ? _value.requestObjectEncryptionAlgValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : requestObjectEncryptionAlgValuesSupported as List<String>?,
      requestObjectEncryptionEncValuesSupported:
          requestObjectEncryptionEncValuesSupported ==
                  const $CopyWithPlaceholder()
              ? _value.requestObjectEncryptionEncValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : requestObjectEncryptionEncValuesSupported as List<String>?,
      tokenEndpointAuthSigningAlgValuesSupported:
          tokenEndpointAuthSigningAlgValuesSupported ==
                  const $CopyWithPlaceholder()
              ? _value.tokenEndpointAuthSigningAlgValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : tokenEndpointAuthSigningAlgValuesSupported as List<String>?,
      tokenEndpointAuthMethodsSupported:
          tokenEndpointAuthMethodsSupported == const $CopyWithPlaceholder()
              ? _value.tokenEndpointAuthMethodsSupported
              // ignore: cast_nullable_to_non_nullable
              : tokenEndpointAuthMethodsSupported as List<String>?,
      displayValuesSupported:
          displayValuesSupported == const $CopyWithPlaceholder()
              ? _value.displayValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : displayValuesSupported as List<String>?,
      claimTypesSupported: claimTypesSupported == const $CopyWithPlaceholder()
          ? _value.claimTypesSupported
          // ignore: cast_nullable_to_non_nullable
          : claimTypesSupported as List<String>?,
      claimsSupported: claimsSupported == const $CopyWithPlaceholder()
          ? _value.claimsSupported
          // ignore: cast_nullable_to_non_nullable
          : claimsSupported as List<String>?,
      serviceDocumentation: serviceDocumentation == const $CopyWithPlaceholder()
          ? _value.serviceDocumentation
          // ignore: cast_nullable_to_non_nullable
          : serviceDocumentation as Uri?,
      claimsLocalesSupported:
          claimsLocalesSupported == const $CopyWithPlaceholder()
              ? _value.claimsLocalesSupported
              // ignore: cast_nullable_to_non_nullable
              : claimsLocalesSupported as List<String>?,
      uiLocalesSupported: uiLocalesSupported == const $CopyWithPlaceholder()
          ? _value.uiLocalesSupported
          // ignore: cast_nullable_to_non_nullable
          : uiLocalesSupported as List<String>?,
      pushedAuthorizationRequestEndpoint:
          pushedAuthorizationRequestEndpoint == const $CopyWithPlaceholder()
              ? _value.pushedAuthorizationRequestEndpoint
              // ignore: cast_nullable_to_non_nullable
              : pushedAuthorizationRequestEndpoint as Uri?,
      claimsParameterSupported:
          claimsParameterSupported == const $CopyWithPlaceholder()
              ? _value.claimsParameterSupported
              // ignore: cast_nullable_to_non_nullable
              : claimsParameterSupported as bool?,
      requestParameterSupported:
          requestParameterSupported == const $CopyWithPlaceholder()
              ? _value.requestParameterSupported
              // ignore: cast_nullable_to_non_nullable
              : requestParameterSupported as bool?,
      requireRequestUriRegistration:
          requireRequestUriRegistration == const $CopyWithPlaceholder()
              ? _value.requireRequestUriRegistration
              // ignore: cast_nullable_to_non_nullable
              : requireRequestUriRegistration as bool?,
      requestUriParameterSupported:
          requestUriParameterSupported == const $CopyWithPlaceholder()
              ? _value.requestUriParameterSupported
              // ignore: cast_nullable_to_non_nullable
              : requestUriParameterSupported as bool?,
      requirePushedAuthorizationRequests:
          requirePushedAuthorizationRequests == const $CopyWithPlaceholder()
              ? _value.requirePushedAuthorizationRequests
              // ignore: cast_nullable_to_non_nullable
              : requirePushedAuthorizationRequests as bool?,
      opPolicyUri: opPolicyUri == const $CopyWithPlaceholder()
          ? _value.opPolicyUri
          // ignore: cast_nullable_to_non_nullable
          : opPolicyUri as Uri?,
      opTosUri: opTosUri == const $CopyWithPlaceholder()
          ? _value.opTosUri
          // ignore: cast_nullable_to_non_nullable
          : opTosUri as Uri?,
      checkSessionIframe: checkSessionIframe == const $CopyWithPlaceholder()
          ? _value.checkSessionIframe
          // ignore: cast_nullable_to_non_nullable
          : checkSessionIframe as Uri?,
      endSessionEndpoint: endSessionEndpoint == const $CopyWithPlaceholder()
          ? _value.endSessionEndpoint
          // ignore: cast_nullable_to_non_nullable
          : endSessionEndpoint as Uri?,
      revocationEndpoint: revocationEndpoint == const $CopyWithPlaceholder()
          ? _value.revocationEndpoint
          // ignore: cast_nullable_to_non_nullable
          : revocationEndpoint as Uri?,
      revocationEndpointAuthMethodsSupported:
          revocationEndpointAuthMethodsSupported == const $CopyWithPlaceholder()
              ? _value.revocationEndpointAuthMethodsSupported
              // ignore: cast_nullable_to_non_nullable
              : revocationEndpointAuthMethodsSupported as List<String>?,
      revocationEndpointAuthSigningAlgValuesSupported:
          revocationEndpointAuthSigningAlgValuesSupported ==
                  const $CopyWithPlaceholder()
              ? _value.revocationEndpointAuthSigningAlgValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : revocationEndpointAuthSigningAlgValuesSupported
                  as List<String>?,
      introspectionEndpoint:
          introspectionEndpoint == const $CopyWithPlaceholder()
              ? _value.introspectionEndpoint
              // ignore: cast_nullable_to_non_nullable
              : introspectionEndpoint as Uri?,
      introspectionEndpointAuthMethodsSupported:
          introspectionEndpointAuthMethodsSupported ==
                  const $CopyWithPlaceholder()
              ? _value.introspectionEndpointAuthMethodsSupported
              // ignore: cast_nullable_to_non_nullable
              : introspectionEndpointAuthMethodsSupported as List<String>?,
      introspectionEndpointAuthSigningAlgValuesSupported:
          introspectionEndpointAuthSigningAlgValuesSupported ==
                  const $CopyWithPlaceholder()
              ? _value.introspectionEndpointAuthSigningAlgValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : introspectionEndpointAuthSigningAlgValuesSupported
                  as List<String>?,
      codeChallengeMethodsSupported:
          codeChallengeMethodsSupported == const $CopyWithPlaceholder()
              ? _value.codeChallengeMethodsSupported
              // ignore: cast_nullable_to_non_nullable
              : codeChallengeMethodsSupported as List<String>?,
      idTokenEncryptionEncValuesSupported:
          idTokenEncryptionEncValuesSupported == const $CopyWithPlaceholder()
              ? _value.idTokenEncryptionEncValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : idTokenEncryptionEncValuesSupported as List<String>?,
      userinfoSigningAlgValuesSupported:
          userinfoSigningAlgValuesSupported == const $CopyWithPlaceholder()
              ? _value.userinfoSigningAlgValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : userinfoSigningAlgValuesSupported as List<String>?,
      userinfoEncryptionAlgValuesSupported:
          userinfoEncryptionAlgValuesSupported == const $CopyWithPlaceholder()
              ? _value.userinfoEncryptionAlgValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : userinfoEncryptionAlgValuesSupported as List<String>?,
      userinfoEncryptionEncValuesSupported:
          userinfoEncryptionEncValuesSupported == const $CopyWithPlaceholder()
              ? _value.userinfoEncryptionEncValuesSupported
              // ignore: cast_nullable_to_non_nullable
              : userinfoEncryptionEncValuesSupported as List<String>?,
    );
  }
}

extension $OidcProviderMetadataCopyWith on OidcProviderMetadata {
  /// Returns a callable class that can be used as follows: `instanceOfOidcProviderMetadata.copyWith(...)` or like so:`instanceOfOidcProviderMetadata.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OidcProviderMetadataCWProxy get copyWith =>
      _$OidcProviderMetadataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OidcProviderMetadata _$OidcProviderMetadataFromJson(
        Map<String, dynamic> json) =>
    OidcProviderMetadata._(
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
