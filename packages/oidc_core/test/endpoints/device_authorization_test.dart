@TestOn('vm')
library;

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

const eq = ListEquality<String>();
void main() {
  group('device authorization grant', () {
    final deviceAuthorizationEndpoint =
        Uri.parse('http://server.example.com/device_authorization');
    // cspell: disable
    final json = {
      'device_code': 'GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS',
      'user_code': 'WDJB-MJHT',
      'verification_uri': 'https://example.com/device',
      'verification_uri_complete':
          'https://example.com/device?user_code=WDJB-MJHT',
      'expires_in': 1800,
      'interval': 5
    };
    // cspell: enable

    final client = MockClient((request) async {
      if (request.url.host != deviceAuthorizationEndpoint.host) {
        return Response('Not found', 404);
      }
      if (eq.equals(
          request.url.pathSegments, deviceAuthorizationEndpoint.pathSegments)) {
        return Response(jsonEncode(json), 200);
      }
      return Response('Not found', 404);
    });

    test('device code', () async {
      final response = await OidcEndpoints.deviceAuthorization(
        deviceAuthorizationEndpoint: deviceAuthorizationEndpoint,
        client: client,
        request: OidcDeviceAuthorizationRequest(
          scope: ['example_scope'],
        ),
        credentials:
            const OidcClientAuthentication.none(clientId: '1406020730'),
      );
      //cspell: disable
      expect(response.deviceCode, json['device_code']);
      expect(response.userCode, json['user_code']);
      expect(response.verificationUri.toString(), json['verification_uri']);
      expect(response.verificationUriComplete.toString(),
          json['verification_uri_complete']);
      expect(response.expiresIn.inSeconds, json['expires_in']);
      expect(response.interval?.inSeconds, json['interval']);
      //cspell: enable
    });
  });
}
