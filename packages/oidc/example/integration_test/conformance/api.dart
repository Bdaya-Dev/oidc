// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Variant dimensions a plan's modules require to be stated outright.
///
/// The suite defaults some dimensions and demands others, and which is which
/// cannot be read off the plan name. Getting it wrong is not a test failure:
/// it is an HTTP 400 at plan creation, from a live third-party server, so the
/// mistake costs a full CI round trip to discover. `client_auth_type` is
/// recorded here because the config plan's discovery module refuses the whole
/// plan without it, while the basic plan resolves it to `client_secret_basic`
/// on its own -- which is exactly why the omission went unnoticed on the only
/// plan that had ever been run.
///
/// Add a plan here when the suite rejects it for a missing dimension. The
/// entry turns that network round trip into an immediate local error.
const _requiredExtraVariants = <String, List<String>>{
  'oidcc-client-config-certification-test-plan': ['client_auth_type'],
  // All four logout plans demand it too, like config and unlike hybrid and
  // implicit, which reject it. Five plans, three answers, one dimension.
  'oidcc-client-rp-initiated-logout-rp-basic': ['client_auth_type'],
  'oidcc-client-front-channel-logout-rp-basic': ['client_auth_type'],
  'oidcc-client-back-channel-logout-rp-basic': ['client_auth_type'],
  'oidcc-client-rp-session-management-rp-basic': ['client_auth_type'],
  'oidcc-client-test-3rd-party-init-login-test-plan': [
    'client_auth_type',
    'response_type',
  ],
  // Dynamic RP is the fourth distinct combination for the same three
  // dimensions: FORBIDS request_type and client_registration (below), and
  // REQUIRES client_auth_type. Its webfinger module said so:
  //   TestModule 'oidcc-client-test-discovery-webfinger-acct' requires a
  //   value for variant 'client_auth_type'
  'oidcc-client-dynamic-certification-test-plan': ['client_auth_type'],
};

/// Variant dimensions a plan sets ITSELF, and rejects the caller for setting.
///
/// The exact inverse of [_requiredExtraVariants], for the same dimension:
///
///   Variant 'client_auth_type' has been set by user, but test plan already
///   sets this variant for module 'oidcc-client-test'
///
/// So `client_auth_type` is optional on the basic plan, mandatory on the
/// config plan, and forbidden on these two. Three rules for one dimension,
/// none of them derivable from the plan name -- each cost an HTTP 400 to
/// learn, which is precisely why both directions are recorded here instead of
/// being rediscovered from CI.
const _forbiddenExtraVariants = <String, List<String>>{
  'oidcc-client-hybrid-certification-test-plan': ['client_auth_type'],
  'oidcc-client-implicit-certification-test-plan': ['client_auth_type'],
  // A SECOND dimension with per-plan rules. Dynamic RP sets request_type
  // itself, so the plain_http_request every other plan needs is rejected here.
  // request_type is therefore nullable below: "always send it" was an
  // assumption, not a requirement.
  // Dynamic RP sets BOTH itself. Passing client_registration: dynamic_client
  // looked like the obvious counterpart to static_client and was rejected --
  // the plan is "dynamic" precisely because it owns that dimension.
  'oidcc-client-dynamic-certification-test-plan': [
    'request_type',
    'client_registration',
  ],
};

(String path, Map<String, dynamic> body) prepareTestPlanRequest({
  // oidcc-client-basic-certification-test-plan
  required String planName,
  required String description,
  required String clientId,
  required String redirectUri,
  // {"request_type":"plain_http_request","client_registration":"static_client"}
  String? clientRegistration,
  String? requestType,
  String? alias,
  String? clientSecret,
  String? postLogoutRedirectUri,
  String? frontChannelLogoutUri,
  Map<String, String>? extraVariant,
  String publish = 'everything',
}) {
  final variant = {
    if (requestType != null) 'request_type': requestType,
    if (clientRegistration != null) 'client_registration': clientRegistration,
    ...?extraVariant,
  };
  final missing = (_requiredExtraVariants[planName] ?? const <String>[])
      .where((dimension) => !variant.containsKey(dimension))
      .toList();
  if (missing.isNotEmpty) {
    throw ArgumentError(
      'The "$planName" plan requires the variant dimension(s) '
      '${missing.join(', ')}. The conformance suite enforces this at plan '
      'creation and answers HTTP 400, so pass them via extraVariant rather '
      'than discovering it from CI.',
    );
  }
  final forbidden = (_forbiddenExtraVariants[planName] ?? const <String>[])
      .where(variant.containsKey)
      .toList();
  if (forbidden.isNotEmpty) {
    throw ArgumentError(
      'The "$planName" plan sets the variant dimension(s) '
      '${forbidden.join(', ')} itself and rejects a caller-supplied value '
      'with HTTP 400. Drop them rather than discovering it from CI.',
    );
  }
  final uri = Uri(
    path: '/api/plan',
    queryParameters: {'planName': planName, 'variant': jsonEncode(variant)},
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
    queryParameters: {'public': public.toString()},
  );
  // Assuming you have a Dio instance or similar HTTP client
  final response = await dio.getUri<Map<String, dynamic>>(uri);
  return response.data ?? {};
}

Future<void> deletePlan({required Dio dio, required String planId}) async {
  final uri = Uri(path: 'api/plan/$planId');
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

  var attempt = 0;
  const maxAttempts = 5;
  const initialDelay = Duration(seconds: 1);

  while (true) {
    try {
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
      final response = await dio.postUri<Uint8List>(
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
    } on DioException catch (e) {
      if (e.response?.statusCode != 422 || attempt >= maxAttempts - 1) {
        rethrow;
      }

      // Calculate backoff delay: initialDelay * 2^attempt, with jitter
      final backoff = initialDelay * (1 << attempt);
      final jitter = Duration(
        milliseconds:
            (backoff.inMilliseconds * 0.2 * (Random().nextDouble() * 2 - 1))
                .toInt(),
      );
      final delay = backoff + jitter;

      print(
        'Retrying publishCertificationPackage (attempt ${attempt + 1}/$maxAttempts) after ${delay.inMilliseconds}ms',
      );
      await Future<void>.delayed(delay);
      attempt++;
    }
  }
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
