// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$OidcEndSessionRequestToJson(
    OidcEndSessionRequest instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('id_token_hint', instance.idTokenHint);
  writeNotNull('logout_hint', instance.logoutHint);
  writeNotNull('client_id', instance.clientId);
  writeNotNull(
      'post_logout_redirect_uri', instance.postLogoutRedirectUri?.toString());
  writeNotNull('state', instance.state);
  writeNotNull('ui_locales',
      OidcInternalUtilities.joinSpaceDelimitedList(instance.uiLocales));
  return val;
}
