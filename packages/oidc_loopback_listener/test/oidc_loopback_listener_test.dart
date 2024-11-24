@TestOn('vm')
library;

// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:oidc_loopback_listener/oidc_loopback_listener.dart';
import 'package:test/test.dart';

Uri getTargetUriFromPort({
  required int port,
  String? path,
  Map<String, dynamic>? queryParameters,
}) {
  return Uri(
    host: InternetAddress.loopbackIPv4.host,
    scheme: 'http',
    port: port,
    path: path,
    queryParameters: queryParameters,
  );
}

void main() {
  group('OidcLoopbackListener', () {
    test('method mismatch', () async {
      final listener = OidcLoopbackListener(methodMismatchResponse: 'hello');
      final serverCompleter = Completer<HttpServer>();

      unawaited(
        listener.listenForSingleResponse(
          serverCompleter: serverCompleter,
        ),
      );
      final server = await serverCompleter.future;
      final targetUri = getTargetUriFromPort(port: server.port);
      final resp = await http.post(targetUri, body: 'hello');
      expect(resp.statusCode, HttpStatus.methodNotAllowed);
      expect(resp.body, 'hello');
    });

    test('not found', () async {
      final listener =
          OidcLoopbackListener(path: 'secret', notFoundResponse: 'not found');
      final serverCompleter = Completer<HttpServer>();

      unawaited(
        listener.listenForSingleResponse(serverCompleter: serverCompleter),
      );
      final server = await serverCompleter.future;
      final targetUri = getTargetUriFromPort(port: server.port, path: 'wrong');
      final resp = await http.get(targetUri);
      expect(resp.statusCode, HttpStatus.notFound);
      expect(resp.body, 'not found');
    });

    test('Correct with path', () async {
      final listener = OidcLoopbackListener(
        path: 'secret',
        successfulPageResponse: 'good',
      );
      final serverCompleter = Completer<HttpServer>();

      final receivedUriFuture =
          listener.listenForSingleResponse(serverCompleter: serverCompleter);
      final server = await serverCompleter.future;
      final targetUri = getTargetUriFromPort(
        port: server.port,
        path: 'secret',
        queryParameters: {
          'code': '123456',
        },
      );
      final resp = await http.get(targetUri);
      expect(resp.statusCode, HttpStatus.ok);
      expect(resp.body, 'good');

      final receivedUri = await receivedUriFuture;
      expect(receivedUri, isNotNull);
      expect(receivedUri!.path, targetUri.path);
      expect(receivedUri.queryParameters, targetUri.queryParameters);
    });

    test('Correct with no path', () async {
      final listener = OidcLoopbackListener(successfulPageResponse: 'good');
      final serverCompleter = Completer<HttpServer>();

      final receivedUriFuture =
          listener.listenForSingleResponse(serverCompleter: serverCompleter);
      final server = await serverCompleter.future;
      final targetUri = getTargetUriFromPort(
        port: server.port,
        path: 'anything',
        queryParameters: {
          'code': '123456',
        },
      );
      final resp = await http.get(targetUri);
      expect(resp.statusCode, HttpStatus.ok);
      expect(resp.body, 'good');

      final receivedUri = await receivedUriFuture;
      expect(receivedUri, isNotNull);
      expect(receivedUri!.path, targetUri.path);
      expect(receivedUri.queryParameters, targetUri.queryParameters);
    });
  });
}
