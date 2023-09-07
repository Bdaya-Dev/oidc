import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oidc_core/oidc_core.dart';

const _authorizationHeaderKey = 'Authorization';
const _formUrlEncoded = 'application/x-www-form-urlencoded';

class OidcEndpoints {
  static T _handleResponse<T>({
    required Uri uri,
    required T Function(Map<String, dynamic> response) mapper,
    required http.Request request,
    required http.Response response,
  }) {
    final commonExtra = {
      OidcConstants_Exception.request: request,
      OidcConstants_Exception.response: response,
      OidcConstants_Exception.statusCode: response.statusCode,
    };
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body.containsKey(OidcConstants_AuthParameters.error)) {
        throw OidcException(
          'Error returned from the endpoint: $uri',
          errorResponse: OidcErrorResponse.fromJson(body),
          extra: commonExtra,
        );
      }
      return mapper(body);
    } on OidcException {
      rethrow;
    } catch (e, st) {
      throw OidcException(
        'Failed to handle the response from endpoint: $uri',
        internalException: e,
        internalStackTrace: st,
        extra: commonExtra,
      );
    }
  }

  static http.Request _prepareRequest({
    required String method,
    required Uri uri,
    required Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? bodyFields,
  }) {
    final req = http.Request(method, uri);
    if (headers != null) {
      req.headers.addAll(headers);
    }
    if (contentType != null) {
      req.headers['Content-Type'] = contentType;
    }
    if (bodyFields != null) {
      req.bodyFields = (bodyFields.map<String, String?>(
        (key, value) => MapEntry(
          key,
          value is List<String>
              ? OidcInternalUtilities.joinSpaceDelimitedList(value)
              : value?.toString(),
        ),
      )..removeWhere((key, value) => value is! String))
          .cast<String, String>();
    }
    return req;
  }

  /// Gets the Oidc provider metadata from a '.well-known' url
  static Future<OidcProviderMetadata> getProviderMetadata(
    Uri wellKnownUri, {
    Map<String, String>? headers,
    http.Client? client,
  }) async {
    final req = _prepareRequest(
      method: OidcConstants_RequestMethod.get,
      uri: wellKnownUri,
      headers: headers,
    );
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    return _handleResponse(
      mapper: OidcProviderMetadata.fromJson,
      request: req,
      response: resp,
      uri: wellKnownUri,
    );
  }

  /// parses the Uri from an /authorize response
  static Future<OidcAuthorizeResponse?> parseAuthorizeResponse({
    required Uri responseUri,
    required OidcStore store,
  }) async {
    var stateKey = responseUri.queryParameters[OidcConstants_AuthParameters.state];
    if (stateKey is! String) {
      //TODO: test this.
      final fragmentUri = Uri(query: responseUri.fragment);
      stateKey =
          fragmentUri.queryParameters[OidcConstants_AuthParameters.state];
    }
    if (stateKey is! String) {
      return null;
    }
    final stateStr = await store.get(OidcStoreNamespace.state, key: stateKey);
    if (stateStr == null) {
      throw OidcException(
        'State not found!',
        extra: {
          OidcConstants_AuthParameters.state: stateKey,
        },
      );
    }

    return OidcAuthorizeResponse.fromJson(
      jsonDecode(stateStr) as Map<String, dynamic>,
    );
  }

  /// Sends a token exchange request
  static Future<OidcTokenResponse> token({
    required Uri tokenEndpoint,
    required OidcTokenRequest request,
    required OidcClientAuthentication credentials,
    Map<String, String>? headers,
    http.Client? client,
  }) async {
    final authHeader = credentials.getAuthorizationHeader();
    final authBodyParams = credentials.getBodyParameters();
    final req = _prepareRequest(
      method: OidcConstants_RequestMethod.post,
      uri: tokenEndpoint,
      headers: {
        if (authHeader != null) _authorizationHeaderKey: authHeader,
        ...?headers,
      },
      contentType: _formUrlEncoded,
      bodyFields: {
        ...request.toMap(),
        if (authHeader == null) ...authBodyParams,
      },
    );
    final resp = await OidcInternalUtilities.sendWithClient(
      client: client,
      request: req,
    );
    return _handleResponse(
      uri: tokenEndpoint,
      mapper: OidcTokenResponse.fromJson,
      response: resp,
      request: req,
    );
  }
}
