// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcEndSessionRequestToJson(
  OidcEndSessionRequest instance,
) => <String, dynamic>{
  'id_token_hint': ?instance.idTokenHint,
  'logout_hint': ?instance.logoutHint,
  'client_id': ?instance.clientId,
  'post_logout_redirect_uri': ?instance.postLogoutRedirectUri?.toString(),
  'state': ?instance.state,
  'ui_locales': ?OidcInternalUtilities.joinSpaceDelimitedList(
    instance.uiLocales,
  ),
};
