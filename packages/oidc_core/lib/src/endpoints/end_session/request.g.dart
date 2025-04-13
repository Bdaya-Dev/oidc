// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcEndSessionRequestToJson(
        OidcEndSessionRequest instance) =>
    <String, dynamic>{
      if (instance.idTokenHint case final value?) 'id_token_hint': value,
      if (instance.logoutHint case final value?) 'logout_hint': value,
      if (instance.clientId case final value?) 'client_id': value,
      if (instance.postLogoutRedirectUri?.toString() case final value?)
        'post_logout_redirect_uri': value,
      if (instance.state case final value?) 'state': value,
      if (OidcInternalUtilities.joinSpaceDelimitedList(instance.uiLocales)
          case final value?)
        'ui_locales': value,
    };
