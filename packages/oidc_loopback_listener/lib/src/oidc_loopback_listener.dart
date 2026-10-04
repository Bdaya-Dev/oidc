import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// {@template oidc_loopback_listener}
/// A server that listens on loopback address for an authorization response
/// {@endtemplate}
class OidcLoopbackListener {
  /// {@macro oidc_loopback_listener}
  const OidcLoopbackListener({
    this.successfulPageResponse,
    this.methodMismatchResponse,
    this.notFoundResponse,
    this.path,
    this.port = 0,
    this.captureFragment = false,
  });

  /// What to return if a URI is matched
  final String? successfulPageResponse;

  /// What to return if a method other than `GET` or `POST` is requested.
  ///
  /// `POST` is accepted because it is how an authorization response arrives
  /// under OAuth 2.0 Form Post Response Mode; it is a delivery method, not a
  /// mismatch.
  final String? methodMismatchResponse;

  /// Whether to recover an authorization response delivered in the URI
  /// FRAGMENT.
  ///
  /// A fragment never reaches the server -- the browser strips it before
  /// sending the request -- so a plain loopback listener sees an empty query
  /// and the response is lost. `code id_token` (hybrid) and `id_token`
  /// (implicit) default to `response_mode=fragment`, so those flows cannot work
  /// on a loopback redirect without this.
  ///
  /// When true, the first request is answered with a page whose script reads
  /// `location.hash`, promotes it to the query string, and re-requests. The
  /// listener completes on that second request.
  ///
  /// Off by default: it costs an extra round trip and REQUIRES the caller to be
  /// a real browser running JavaScript. A non-browser client (a `curl`, a test
  /// harness, a native http client) never performs the relay, so the listener
  /// would wait out its timeout instead of completing on the first request.
  final bool captureFragment;

  /// What to return if a different [path] is used.
  ///
  /// NOTE: if `path == null` this is not used.
  final String? notFoundResponse;

  /// The exact path to listen to.
  ///
  /// passing null will listen to all paths.
  final String? path;

  /// The port to listen to.
  ///
  /// passing `0` (default) will listen to any port.
  final int port;

  /// Listens for a single successful response from the server.
  ///
  /// pass [serverCompleter] to get the [HttpServer] instance that was bound.
  ///
  /// When [timeout] is non-null, the listener auto-cancels after that duration
  /// by force-closing the bound socket and throwing a [TimeoutException]; this
  /// prevents an unattended flow from hanging forever and leaking the loopback
  /// socket. The bound server is ALWAYS released (success, IO error, and
  /// timeout paths) via the `finally` below.
  Future<Uri?> listenForSingleResponse({
    Completer<HttpServer>? serverCompleter,
    Duration? timeout,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    if (serverCompleter != null) {
      serverCompleter.complete(server);
    }
    final targetUri = path == null ? null : Uri(path: path);
    Timer? timeoutTimer;
    var timedOut = false;
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        timedOut = true;
        // Force-close so a half-open connection (socket opened, request never
        // completed) cannot keep the `await for` stream alive past the
        // deadline; this terminates the loop below.
        unawaited(server.close(force: true));
      });
    }
    try {
      await for (final request in server) {
        request.response.headers.contentType = ContentType.html;
        // POST is how a form_post authorization response arrives; anything
        // else is a genuine mismatch.
        if (request.method != 'GET' && request.method != 'POST') {
          request.response.statusCode = HttpStatus.methodNotAllowed;
          if (methodMismatchResponse != null) {
            request.response.write(methodMismatchResponse);
          }
          await request.response.close();
          continue;
        }

        if (targetUri != null) {
          if (!_listsAreEqual(
            request.uri.pathSegments,
            targetUri.pathSegments,
          )) {
            // return not found and close the response.
            request.response.statusCode = HttpStatus.notFound;
            if (notFoundResponse != null) {
              request.response.write(notFoundResponse);
            }
            await request.response.close();
            continue;
          }
        }

        // Read the form_post body BEFORE answering, and fold it into the query
        // string. Downstream parses one Uri and does not care which transport
        // carried each parameter.
        var res = request.uri;
        if (request.method == 'POST') {
          final posted = await _readFormBody(request);
          if (posted.isNotEmpty) {
            res = res.replace(
              queryParameters: {...res.queryParameters, ...posted},
            );
          }
        }

        // Fragment recovery: the browser has already dropped the fragment on
        // the way in, so the first request cannot carry it. Answer with the
        // relay page and keep listening; the script re-requests with the
        // fragment promoted to the query string and tagged with the marker.
        //
        // GET only. A fragment can only ride a GET navigation -- a form POST's
        // response is in its BODY, already folded into `res` above, and the
        // relay page's re-request carries location.search/hash but never a
        // request body. Relaying a POST therefore destroys the very response
        // it is trying to recover: observed live as every form_post
        // hybrid/implicit module failing with "Couldn't resolve the response
        // mode" because `state` arrived in the POST body and was dropped.
        if (captureFragment &&
            request.method == 'GET' &&
            !res.queryParameters.containsKey(kOidcFragmentRelayMarker)) {
          request.response.write(oidcFragmentRelayHtmlPage);
          await request.response.close();
          continue;
        }
        if (res.queryParameters.containsKey(kOidcFragmentRelayMarker)) {
          // Strip the transport marker; it is not part of the OIDC response.
          res = res.replace(
            queryParameters: {...res.queryParameters}
              ..remove(kOidcFragmentRelayMarker),
          );
        }

        request.response.write(successfulPageResponse ?? oidcDefaultHtmlPage);

        await request.response.close();
        await server.close();
        return res;
      }
    } catch (e) {
      // Genuine IO error: preserve the historical return-null behavior. A
      // timeout is signalled separately below via `timedOut` (the stream ends
      // cleanly when the server is force-closed, so it is not caught here).
    } finally {
      // ALWAYS release the bound listening socket, on every exit path.
      timeoutTimer?.cancel();
      await server.close(force: true);
    }
    // The `await for` ended without a successful match.
    if (timedOut) {
      throw TimeoutException('Loopback listener timed out', timeout);
    }
    return null;
  }
}

/// Reads an `application/x-www-form-urlencoded` request body.
///
/// Returns an empty map for any other content type, so a POST that is not a
/// form_post response degrades to "no extra parameters" rather than throwing.
Future<Map<String, String>> _readFormBody(HttpRequest request) async {
  final contentType = request.headers.contentType;
  if (contentType?.mimeType != 'application/x-www-form-urlencoded') {
    return const {};
  }
  // The charset the OP declared, defaulting to the form-urlencoded default.
  final encoding = Encoding.getByName(contentType?.charset) ?? utf8;
  final body = await encoding.decodeStream(request);
  if (body.isEmpty) {
    return const {};
  }
  return Uri.splitQueryString(body);
}

bool _listsAreEqual(List<String> list1, List<String> list2) {
  if (list1.length != list2.length) {
    return false;
  }
  for (var i = 0; i < list1.length; i++) {
    final p1 = list1[i];
    final p2 = list2[i];
    if (p1 != p2) {
      return false;
    }
  }
  return true;
}

/// Query key marking a request as the second hop of the fragment relay.
///
/// Named with a leading underscore so it cannot collide with an OAuth or OIDC
/// response parameter, and stripped before the Uri is returned.
const kOidcFragmentRelayMarker = '_oidc_fragment_relay';

/// Page served on the first hit when `captureFragment` is on.
///
/// The browser has already discarded the fragment by the time the request
/// arrives, so the only place it still exists is the address bar of the page
/// being served right now. The script promotes `location.hash` into the query
/// string and re-requests, which is the one way a server can observe it.
///
/// `location.replace` is used rather than an assignment so the relay does not
/// add a history entry the user can go "back" into.
const oidcFragmentRelayHtmlPage =
    '''
<html>

<head>
  <meta charset="utf-8">
  <title>Flutter Oidc Redirect</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>

<body>
Completing sign-in&hellip;
<script>
(function () {
  var hash = window.location.hash ? window.location.hash.substring(1) : '';
  var search = window.location.search ? window.location.search.substring(1) : '';
  var parts = [];
  if (search) { parts.push(search); }
  if (hash) { parts.push(hash); }
  parts.push('$kOidcFragmentRelayMarker=1');
  window.location.replace(window.location.pathname + '?' + parts.join('&'));
})();
</script>
</body>

</html>
''';

/// The default html page to display to the user.
const oidcDefaultHtmlPage = '''
<html>

<head>
  <meta charset="utf-8">
  <title>Flutter Oidc Redirect</title>
  <meta http-equiv='refresh' content='10;url=https://google.com'>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">  
</head>

<body>Please return to the app.</body>

</html>
''';
