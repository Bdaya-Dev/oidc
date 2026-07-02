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
        listener.listenForSingleResponse(serverCompleter: serverCompleter),
      );
      final server = await serverCompleter.future;
      final targetUri = getTargetUriFromPort(port: server.port);
      final resp = await http.post(targetUri, body: 'hello');
      expect(resp.statusCode, HttpStatus.methodNotAllowed);
      expect(resp.body, 'hello');
    });

    test('not found', () async {
      final listener = OidcLoopbackListener(
        path: 'secret',
        notFoundResponse: 'not found',
      );
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

      final receivedUriFuture = listener.listenForSingleResponse(
        serverCompleter: serverCompleter,
      );
      final server = await serverCompleter.future;
      final targetUri = getTargetUriFromPort(
        port: server.port,
        path: 'secret',
        queryParameters: {'code': '123456'},
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

      final receivedUriFuture = listener.listenForSingleResponse(
        serverCompleter: serverCompleter,
      );
      final server = await serverCompleter.future;
      final targetUri = getTargetUriFromPort(
        port: server.port,
        path: 'anything',
        queryParameters: {'code': '123456'},
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

  group('timeout & socket cleanup', () {
    test('throws TimeoutException when no request arrives in time', () async {
      final listener = OidcLoopbackListener();
      await expectLater(
        listener.listenForSingleResponse(
          timeout: const Duration(milliseconds: 200),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test(
      'releases the listening socket on timeout (port re-bindable)',
      () async {
        final listener = OidcLoopbackListener();
        final serverCompleter = Completer<HttpServer>();
        final future = listener.listenForSingleResponse(
          serverCompleter: serverCompleter,
          timeout: const Duration(milliseconds: 200),
        );
        final port = (await serverCompleter.future).port;
        await expectLater(future, throwsA(isA<TimeoutException>()));
        // The `finally` closed the bound socket, so the port re-binds.
        final rebound = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        await rebound.close(force: true);
      },
    );

    test(
      'releases the listening socket on success (port re-bindable)',
      () async {
        final listener = OidcLoopbackListener(successfulPageResponse: 'good');
        final serverCompleter = Completer<HttpServer>();
        final future = listener.listenForSingleResponse(
          serverCompleter: serverCompleter,
        );
        final port = (await serverCompleter.future).port;
        final targetUri = getTargetUriFromPort(
          port: port,
          queryParameters: {'code': '123456'},
        );
        final resp = await http.get(targetUri);
        expect(resp.statusCode, HttpStatus.ok);
        final receivedUri = await future;
        expect(receivedUri, isNotNull);
        // Re-bind the same port to prove the finally released the socket on the
        // happy path, not just on timeout.
        final rebound = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        await rebound.close(force: true);
      },
    );

    test(
      'a valid GET before a generous timeout returns the Uri (no throw)',
      () async {
        final listener = OidcLoopbackListener(successfulPageResponse: 'good');
        final serverCompleter = Completer<HttpServer>();
        final future = listener.listenForSingleResponse(
          serverCompleter: serverCompleter,
          timeout: const Duration(seconds: 5),
        );
        final server = await serverCompleter.future;
        final targetUri = getTargetUriFromPort(
          port: server.port,
          queryParameters: {'code': '123456'},
        );
        final resp = await http.get(targetUri);
        expect(resp.statusCode, HttpStatus.ok);
        final receivedUri = await future;
        expect(receivedUri, isNotNull);
        expect(receivedUri!.queryParameters, targetUri.queryParameters);
      },
    );

    test(
      'cancels the pending timeout after success (no late TimeoutException)',
      () async {
        final listener = OidcLoopbackListener(successfulPageResponse: 'good');
        final serverCompleter = Completer<HttpServer>();
        final future = listener.listenForSingleResponse(
          serverCompleter: serverCompleter,
          timeout: const Duration(milliseconds: 400),
        );
        final server = await serverCompleter.future;
        final targetUri = getTargetUriFromPort(
          port: server.port,
          queryParameters: {'code': '123456'},
        );
        await http.get(targetUri);
        final receivedUri = await future;
        expect(receivedUri, isNotNull);
        // Wait past the original deadline; the cancelled timer must not fire
        // a late TimeoutException.
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
    );
  });
}
