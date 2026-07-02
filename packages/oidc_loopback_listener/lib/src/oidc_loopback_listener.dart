import 'dart:async';
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
  });

  /// What to return if a URI is matched
  final String? successfulPageResponse;

  /// What to return if a method other than `GET` is requested.
  final String? methodMismatchResponse;

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
        if (request.method != 'GET') {
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
        final res = request.uri;
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
