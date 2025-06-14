import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

(String path, Map<String, dynamic> body) prepareTestPlanRequest({
  // oidcc-client-basic-certification-test-plan
  required String planName,
  required String description,
  required String clientId,
  required String redirectUri,
  // {"request_type":"plain_http_request","client_registration":"static_client"}
  required String requestType,
  required String clientRegistration,
  String? alias,
  String? clientSecret,
  String? postLogoutRedirectUri,
  String? frontChannelLogoutUri,
  Map<String, String>? extraVariant,
  String publish = 'everything',
}) {
  final variant = {
    'request_type': requestType,
    'client_registration': clientRegistration,
    ...?extraVariant,
  };
  final uri = Uri(
    path: '/api/plan',
    queryParameters: {
      'planName': planName,
      'variant': jsonEncode(variant),
    },
  );
  final body = {
    'description': description,
    'client': {
      'client_id': clientId,
      if (clientSecret != null) 'client_secret': clientSecret,
      'redirect_uri': redirectUri,
      if (postLogoutRedirectUri != null)
        'post_logout_redirect_uri': postLogoutRedirectUri,
      if (frontChannelLogoutUri != null)
        'frontchannel_logout_uri': frontChannelLogoutUri,
    },
    if (alias != null) 'alias': alias,
    'publish': publish,
  };
  return (uri.toString(), body);
}

Future<Map<String, dynamic>> getPlan({
  required Dio dio,
  required String planId,
  bool public = false,
}) async {
  final uri = Uri(
    path: 'api/plan/$planId',
    queryParameters: {
      'public': public.toString(),
    },
  );
  // Assuming you have a Dio instance or similar HTTP client
  final response = await dio.getUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

Future<void> deletePlan({
  required Dio dio,
  required String planId,
}) async {
  final uri = Uri(
    path: 'api/plan/$planId',
  );
  // Assuming you have a Dio instance or similar HTTP client
  await dio.deleteUri<void>(uri);
}

/*
returns:
{
    "name": "oidcc-client-test-invalid-iss",
    "id": "5KqBAUA5ZqCKzci",
    "url": "https://www.certification.openid.net/test/a/package_oidc_windows"
}
*/
Future<Map<String, dynamic>> createTestModuleInstance({
  required Dio dio,
  required String planId,
  required String moduleName,
  String clientAuthType = 'client_secret_basic',
  String responseType = 'code',
  String responseMode = 'default',
  Map<String, dynamic>? extraVariant,
}) async {
  /*
  {"client_auth_type":"client_secret_basic","response_type":"code","response_mode":"default"}
   */
  final uri = Uri(
    path: 'api/runner',
    queryParameters: {
      'plan': planId,
      'test': moduleName,
      'variant': jsonEncode({
        'client_auth_type': clientAuthType,
        'response_type': responseType,
        'response_mode': responseMode,
        ...?extraVariant,
      }),
    },
  );
  final response = await dio.postUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

Future<Map<String, dynamic>> getTestStatus({
  required Dio dio,
  required String instanceId,
}) async {
  final uri = Uri(path: 'api/runner/$instanceId');
  final response = await dio.getUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

Future<Map<String, dynamic>> startTest({
  required Dio dio,
  required String instanceId,
}) async {
  final uri = Uri(path: 'api/runner/$instanceId');
  final response = await dio.postUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

Future<Map<String, dynamic>> cancelTest({
  required Dio dio,
  required String instanceId,
}) async {
  final uri = Uri(path: 'api/runner/$instanceId');
  final response = await dio.deleteUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

//api/plan/:id/certificationpackage
Future<List<int>?> publishCertificationPackage({
  required Dio dio,
  required String planId,
  required Uint8List clientSideData,
}) async {
  final uri = Uri(path: 'api/plan/$planId/certificationpackage');
  final formData = FormData();
  formData.files.add(
    MapEntry(
      'clientSideData',
      MultipartFile.fromBytes(
        clientSideData,
        filename: 'client_side_logs.zip',
        contentType: DioMediaType('application', 'zip'),
      ),
    ),
  );
  final response = await dio.postUri<List<int>>(
    uri,
    data: formData,
    options: Options(
      responseType: ResponseType.bytes,
      headers: {
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/zip',
      },
    ),
  );
  return response.data;
}

Future<Map<String, dynamic>> getTestSummary({
  required Dio dio,
  required String instanceId,
}) async {
  final uri = Uri(path: 'api/info/$instanceId');
  final response = await dio.getUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

Stream<List<Map<String, dynamic>>> monitorTestLogs({
  required Dio dio,
  required String instanceId,
  Duration interval = const Duration(seconds: 1),
}) {
  late StreamController<List<Map<String, dynamic>>> controller;
  Timer? timer;
  int? since;

  Future<void> fetchLogs() async {
    try {
      final uri = Uri(
        path: 'api/log/$instanceId',
        queryParameters: {
          'public': 'false',
          if (since != null) 'since': since.toString(),
        },
      );

      final response = await dio.getUri<List<dynamic>>(uri);
      final logs = (response.data ?? []).cast<Map<String, dynamic>>();

      if (logs.isNotEmpty && !controller.isClosed) {
        final lastLog = logs.last;
        if (lastLog['time'] case final int lastLogTime) {
          since = lastLogTime;
        }
        controller.add(logs);
      }
    } catch (error, st) {
      if (!controller.isClosed) {
        controller.addError(error, st);
      }
    }
  }

  controller = StreamController<List<Map<String, dynamic>>>(
    onListen: () {
      fetchLogs();
      timer = Timer.periodic(interval, (_) => fetchLogs());
    },
    onCancel: () {
      timer?.cancel();
      timer = null;
      controller.close();
    },
    onPause: () {
      timer?.cancel();
      timer = null;
    },
    onResume: () {
      timer = Timer.periodic(interval, (_) => fetchLogs());
    },
  );

  return controller.stream;
}
