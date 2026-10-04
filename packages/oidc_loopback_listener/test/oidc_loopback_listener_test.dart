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
      // PUT is not a way an authorization response is ever delivered, so it
      // still gets the 405. POST is -- see the form_post group below. This
      // test used to assert POST was rejected, which encoded the very
      // limitation that made response_mode=form_post impossible to support.
      final listener = OidcLoopbackListener(methodMismatchResponse: 'hello');
      final serverCompleter = Completer<HttpServer>();

      unawaited(
        listener.listenForSingleResponse(serverCompleter: serverCompleter),
      );
      final server = await serverCompleter.future;
      final targetUri = getTargetUriFromPort(port: server.port);
      final resp = await http.put(targetUri, body: 'hello');
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

  // OAuth 2.0 Form Post Response Mode: the OP returns the authorization
  // response as an `application/x-www-form-urlencoded` POST body rather than in
  // the URI. The listener answered 405 to every non-GET, so the response could
  // never be captured on desktop -- and that 405 was asserted by a passing
  // test, which is why nothing ever flagged it.
  group('form_post response mode', () {
    test('a form POST body is captured as query parameters', () async {
      final listener = OidcLoopbackListener(successfulPageResponse: 'good');
      final serverCompleter = Completer<HttpServer>();
      final receivedUriFuture = listener.listenForSingleResponse(
        serverCompleter: serverCompleter,
      );
      final server = await serverCompleter.future;

      final resp = await http.post(
        getTargetUriFromPort(port: server.port),
        body: {'code': '123456', 'state': 'abc'},
      );
      expect(resp.statusCode, HttpStatus.ok);
      expect(resp.body, 'good');

      final receivedUri = await receivedUriFuture;
      expect(receivedUri, isNotNull);
      expect(receivedUri!.queryParameters['code'], '123456');
      expect(receivedUri.queryParameters['state'], 'abc');
    });

    test(
      'a POST body merges with query parameters already on the URI',
      () async {
        // An OP may put `iss` on the URI while form-posting the rest.
        final listener = OidcLoopbackListener(successfulPageResponse: 'good');
        final serverCompleter = Completer<HttpServer>();
        final receivedUriFuture = listener.listenForSingleResponse(
          serverCompleter: serverCompleter,
        );
        final server = await serverCompleter.future;

        await http.post(
          getTargetUriFromPort(
            port: server.port,
            queryParameters: {'iss': 'https://op.test'},
          ),
          body: {'code': '123456'},
        );

        final receivedUri = await receivedUriFuture;
        expect(receivedUri!.queryParameters['iss'], 'https://op.test');
        expect(receivedUri.queryParameters['code'], '123456');
      },
    );

    test('a POST to the wrong path still 404s', () async {
      final listener = OidcLoopbackListener(
        path: 'secret',
        notFoundResponse: 'not found',
      );
      final serverCompleter = Completer<HttpServer>();
      unawaited(
        listener.listenForSingleResponse(serverCompleter: serverCompleter),
      );
      final server = await serverCompleter.future;

      final resp = await http.post(
        getTargetUriFromPort(port: server.port, path: 'wrong'),
        body: {'code': '123456'},
      );
      expect(resp.statusCode, HttpStatus.notFound);
      expect(resp.body, 'not found');
    });
  });

  // A fragment is never sent to a server -- the browser strips it before the
  // request goes out. `code id_token` (hybrid) and `id_token` (implicit)
  // default to response_mode=fragment, so a plain loopback listener observes an
  // empty query and the tokens are simply gone. The fix is the trick CLI OAuth
  // tools use: serve a page whose script reads location.hash and re-requests
  // with it promoted to the query string.
  group('fragment capture', () {
    test('is off by default: the first request completes as before', () async {
      final listener = OidcLoopbackListener(successfulPageResponse: 'good');
      final serverCompleter = Completer<HttpServer>();
      final receivedUriFuture = listener.listenForSingleResponse(
        serverCompleter: serverCompleter,
      );
      final server = await serverCompleter.future;
      await http.get(
        getTargetUriFromPort(port: server.port, queryParameters: {'code': '1'}),
      );
      final receivedUri = await receivedUriFuture;
      expect(receivedUri!.queryParameters['code'], '1');
    });

    test(
      'serves a relay page rather than completing on the first hit',
      () async {
        final listener = OidcLoopbackListener(captureFragment: true);
        final serverCompleter = Completer<HttpServer>();
        final responseUriFuture = listener.listenForSingleResponse(
          serverCompleter: serverCompleter,
          timeout: const Duration(milliseconds: 500),
        );
        final server = await serverCompleter.future;

        final resp = await http.get(getTargetUriFromPort(port: server.port));
        expect(resp.statusCode, HttpStatus.ok);
        // The page must carry the script that performs the relay, and the
        // marker it uses to tag the follow-up request.
        expect(resp.body, contains('location.hash'));
        expect(resp.body, contains(kOidcFragmentRelayMarker));

        // No relayed second request ever arrives, so the listener must time
        // out rather than complete -- which IS the "did not complete on the
        // first hit" assertion. Awaited, not fire-and-forget: the first
        // version left this future unawaited with a 5s timer, and the
        // TimeoutException landed as an unhandled error AFTER the test ended.
        // Locally the process exited before the timer fired, so the suite was
        // green; on a slower CI runner it was still alive, and the error was
        // attributed to the completed test ("failed after test completion").
        await expectLater(responseUriFuture, throwsA(isA<TimeoutException>()));
      },
    );

    test('completes on the relayed request, marker stripped', () async {
      final listener = OidcLoopbackListener(captureFragment: true);
      final serverCompleter = Completer<HttpServer>();
      final receivedUriFuture = listener.listenForSingleResponse(
        serverCompleter: serverCompleter,
        timeout: const Duration(seconds: 5),
      );
      final server = await serverCompleter.future;

      // First hit: the browser has stripped the fragment, query is empty.
      await http.get(getTargetUriFromPort(port: server.port));
      // What the relay script then does: fragment promoted to query.
      await http.get(
        getTargetUriFromPort(
          port: server.port,
          queryParameters: {
            'id_token': 'eyJ.a.b',
            'state': 'xyz',
            kOidcFragmentRelayMarker: '1',
          },
        ),
      );

      final receivedUri = await receivedUriFuture;
      expect(receivedUri, isNotNull);
      expect(receivedUri!.queryParameters['id_token'], 'eyJ.a.b');
      expect(receivedUri.queryParameters['state'], 'xyz');
      // The marker is transport plumbing and must not leak into the response
      // the manager parses.
      expect(
        receivedUri.queryParameters,
        isNot(contains(kOidcFragmentRelayMarker)),
      );
    });

    test(
      'a form POST completes immediately even with captureFragment on',
      () async {
        // Observed live (oidc PR #447): for form_post hybrid/implicit the
        // client did not explicitly request response_mode=form_post, so the
        // desktop wiring armed the relay -- and the relay branch DISCARDED the
        // folded POST body and served the relay page, whose re-request carries
        // only location.search/hash, never a request body. Every module died
        // with "Couldn't resolve the response mode, make sure the key (state)
        // exists in the Uri". A fragment can only ride a GET navigation, so a
        // POST must never take the relay hop: its body IS the response.
        final listener = OidcLoopbackListener(
          captureFragment: true,
          successfulPageResponse: 'good',
        );
        final serverCompleter = Completer<HttpServer>();
        final receivedUriFuture = listener.listenForSingleResponse(
          serverCompleter: serverCompleter,
          timeout: const Duration(seconds: 5),
        );
        final server = await serverCompleter.future;

        final resp = await http.post(
          getTargetUriFromPort(port: server.port),
          body: {'code': 'abc', 'id_token': 'eyJ.a.b', 'state': 'xyz'},
        );
        expect(resp.statusCode, HttpStatus.ok);
        expect(resp.body, 'good');

        final receivedUri = await receivedUriFuture;
        expect(receivedUri!.queryParameters['state'], 'xyz');
        expect(receivedUri.queryParameters['id_token'], 'eyJ.a.b');
      },
    );
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
