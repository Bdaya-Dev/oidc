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
  Future<Uri?> listenForSingleResponse({
    Completer<HttpServer>? serverCompleter,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    if (serverCompleter != null) {
      serverCompleter.complete(server);
    }
    final targetUri = path == null ? null : Uri(path: path);
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
      await server.close();
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
