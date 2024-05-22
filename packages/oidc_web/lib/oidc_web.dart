// ignore_for_file: cascade_invocations, avoid_redundant_argument_values

import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:oidc_platform_interface/oidc_platform_interface.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as html;

final _logger = Logger('Oidc.OidcWeb');

/// The Web implementation of [OidcPlatform].
class OidcWeb extends OidcPlatform {
  /// Registers this class as the default instance of [OidcPlatform]
  static void registerWith([Object? registrar]) {
    OidcPlatform.instance = OidcWeb();
  }

  String _calculatePopupOptions(OidcPlatformSpecificOptions_Web web) {
    final h = web.popupHeight;
    final w = web.popupWidth;

    final top = (html.window.outerHeight - h) / 2 + (html.window.screenTop);
    final left = (html.window.outerWidth - w) / 2 + (html.window.screenLeft);

    final windowOpts =
        'width=$w,height=$h,toolbar=no,location=no,directories=no,status=no,menubar=no,copyhistory=no&top=$top,left=$left';
    return windowOpts;
  }

  html.HTMLBodyElement _getBody() =>
      html.window.document.getElementsByTagName('body').item(0)!
          as html.HTMLBodyElement;

  html.HTMLIFrameElement _createHiddenIframe({
    required String iframeId,
    bool appendToDocument = true,
  }) {
    final prev = html.window.document.getElementById(iframeId);
    if (prev != null) {
      prev.remove();
    }
    final res =
        (html.window.document.createElement('iframe') as html.HTMLIFrameElement)
          ..id = iframeId
          ..width = '0'
          ..height = '0'
          ..hidden = true.toJS
          ..style.visibility = 'hidden'
          ..style.position = 'fixed'
          ..style.left = '-1000px'
          ..style.top = '0';
    if (appendToDocument) {
      final body = _getBody();
      body.append(res);
    }
    return res;
  }

  Future<Uri?> _getResponseUri({
    required OidcPlatformSpecificOptions_Web options,
    required Uri uri,
    required String? state,
  }) async {
    final channel = html.BroadcastChannel(options.broadcastChannel);
    final c = Completer<Uri>();

    final eventFunc = (html.MessageEvent event) {
      final data = event.data;

      if (data == null || data is! String) {
        return;
      }
      final parsed = Uri.tryParse(data as String);
      if (parsed == null) {
        return;
      }

      if (state != null) {
        final (:parameters, responseMode: _) =
            OidcEndpoints.resolveAuthorizeResponseParameters(
          responseUri: parsed,
          resolveResponseModeByKey: OidcConstants_AuthParameters.state,
        );
        final incomingState = parameters[OidcConstants_AuthParameters.state];
        //if we give it a state, we expect it to be returned.
        if (incomingState != state) {
          //check for state mismatch.
          return;
        }
      }
      c.complete(parsed);
    }.toJS;

    channel.addEventListener('message', eventFunc);

    try {
      //first prepare
      switch (options.navigationMode) {
        case OidcPlatformSpecificOptions_Web_NavigationMode.samePage:
          //
          await launchUrl(
            uri,
            webOnlyWindowName: '_self',
          );
          // return null, since this mode can't be awaited.
          return null;
        case OidcPlatformSpecificOptions_Web_NavigationMode.newPage:
          //
          await launchUrl(
            uri,
            webOnlyWindowName: '_blank',
          );
          //listen to response uri.
          return await c.future;
        case OidcPlatformSpecificOptions_Web_NavigationMode.popup:
          final windowOpts = _calculatePopupOptions(options);
          html.window.open(
            uri.toString(),
            'oidc_auth_popup',
            windowOpts,
          );
          return await c.future;
        case OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame:
          const iframeId = 'oidc-session-management-iframe';
          final iframe = _createHiddenIframe(
            iframeId: iframeId,
            appendToDocument: true,
          );
          iframe.src = uri.toString();
          final emptyUri = Uri();
          final res = await c.future.timeout(
            options.hiddenIframeTimeout,
            onTimeout: () => emptyUri,
          );
          iframe.remove();
          if (res == emptyUri) {
            return null;
          }
          return res;
      }
    } finally {
      channel.removeEventListener('message', eventFunc);
    }
  }

  @override
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions options,
  ) async {
    final endpoint = metadata.authorizationEndpoint;
    if (endpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide '${OidcConstants_ProviderMetadata.authorizationEndpoint}'",
      );
    }
    final isNonePrompt =
        request.prompt?.contains(OidcConstants_AuthorizeRequest_Prompt.none) ??
            false;
    if (options.web.navigationMode ==
            OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame &&
        !isNonePrompt) {
      throw const OidcException(
        'hidden iframe can only be used with "none" prompt, '
        'since it prohibits user interaction',
      );
    }
    final respUri = await _getResponseUri(
      options: options.web,
      uri: request.generateUri(endpoint),
      state: request.state,
    );
    if (respUri == null) {
      return null;
    }
    return OidcEndpoints.parseAuthorizeResponse(
      responseUri: respUri,
      responseMode: request.responseMode,
    );
  }

  @override
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions options,
  ) async {
    final endpoint = metadata.endSessionEndpoint;
    if (endpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide '${OidcConstants_ProviderMetadata.endSessionEndpoint}'.",
      );
    }

    final respUri = await _getResponseUri(
      options: options.web,
      uri: request.generateUri(endpoint),
      state: request.state,
    );
    if (respUri == null) {
      return null;
    }
    return OidcEndSessionResponse.fromJson(respUri.queryParameters);
  }

  @override
  Stream<OidcFrontChannelLogoutIncomingRequest>
      listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions options,
  ) {
    final logger = Logger('Oidc.OidcWeb.listenToFrontChannelLogoutRequests');
    final channel = html.BroadcastChannel(options.web.broadcastChannel);

    StreamController<OidcFrontChannelLogoutIncomingRequest>? sc;

    final messageEvent = (html.MessageEvent event) {
      final streamController = sc;
      if (streamController == null) {
        _logger.warning(
          'ignoring received message; '
          'streamController is null ? ${streamController == null}; ',
        );
        return;
      }

      final data = event.data;
      if (data == null || data is! String) {
        logger.finer('Received data: $data');
        return null;
      }
      final uri = Uri.tryParse(data as String);
      if (uri == null) {
        logger.finer('Parsed Received data: $uri');
        return null;
      }
      //listening on empty path, will listen on all paths.
      if (listenOn.pathSegments.isNotEmpty) {
        logger.finer(
          'listenOn has a path segment (${listenOn.path}), checking if it matches the input data.',
        );
        if (!listEquals(uri.pathSegments, listenOn.pathSegments)) {
          logger.finer(
            'listenOn has a different path segment (${listenOn.path}), than data (${uri.path}), '
            'skipping the event.',
          );
          // the paths don't match
          return null;
        }
      }
      if (listenOn.hasQuery) {
        logger.finer(
          'listenOn has a query segment (${listenOn.query}), checking if it matches the input data.',
        );
        // check if every queryParameter in listenOn is the same in uri
        if (!listenOn.queryParameters.entries.every(
          (element) => uri.queryParameters[element.key] == element.value,
        )) {
          logger.finer(
            'listenOn has a different query segment (${listenOn.query}), than data (${uri.query}), '
            'skipping the event.',
          );
          return null;
        }
      } else {
        logger.finer(
          'listenOn has NO query segment, checking if data contains requestType=front-channel-logout by default.',
        );
        //by default, if no query parameter exists, check that
        // requestType=front-channel-logout
        if (uri.queryParameters[OidcConstants_Store.requestType] !=
            OidcConstants_Store.frontChannelLogout) {
          logger.finer(
            'data has no requestType=front-channel-logout in its query segment (${uri.query}), '
            'skipping the event.',
          );
          return null;
        }
      }
      logger.fine('successfully matched data ($uri)');
      final result = OidcFrontChannelLogoutIncomingRequest.fromJson(
        uri.queryParameters,
      );
      streamController.add(result);
    }.toJS;

    sc = StreamController<OidcFrontChannelLogoutIncomingRequest>(
      onListen: () {
        channel.addEventListener('message', messageEvent);
      },
      onCancel: () {
        channel.removeEventListener('message', messageEvent);
      },
    );

    return sc.stream;
  }

  @override
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) {
    StreamController<OidcMonitorSessionResult>? sc;
    StreamSubscription<int>? timerSub;
    StreamSubscription<html.MessageEvent>? messageSub;
    // Timer? timer;

    const iframeId = 'oidc-session-management-iframe';
    void onMessageReceived(html.Event event) {
      if (event is! html.MessageEvent) {
        return;
      }
      final streamController = sc;
      final iframe =
          html.document.getElementById(iframeId) as html.HTMLIFrameElement?;
      final eventOrigin = event.origin;
      if (iframe == null ||
          streamController == null ||
          eventOrigin != checkSessionIframe.origin) {
        _logger.warning(
          'ignoring received message; '
          'iframe is null ? ${iframe == null}; '
          'streamController is null ? ${streamController == null}; '
          'eventOrigin is: ($eventOrigin), should be equal to: (${checkSessionIframe.origin}).',
        );
        return;
      }
      final eventData = event.data;
      if (eventData is! String) {
        _logger.warning('Received iframe message was not a string: $eventData');
        return;
      }
      switch (eventData) {
        case 'error':
          _logger.warning('Received error iframe message');
          streamController.add(const OidcErrorMonitorSessionResult());
        case 'changed':
          _logger.fine('Received changed iframe message');
          streamController
              .add(const OidcValidMonitorSessionResult(changed: true));
        case 'unchanged':
          _logger.fine('Received unchanged iframe message');
          streamController
              .add(const OidcValidMonitorSessionResult(changed: false));
        default:
          _logger.warning('Received unknown iframe message: $eventData');
          streamController
              .add(OidcUnknownMonitorSessionResult(data: eventData.toString()));
      }
    }

    sc = StreamController<OidcMonitorSessionResult>(
      onListen: () async {
        final iframe =
            _createHiddenIframe(appendToDocument: false, iframeId: iframeId)
              ..id = iframeId
              ..src = checkSessionIframe.toString();
        final onloadFuture = iframe.onLoad.first;
        final body = _getBody();
        body.append(iframe);
        await onloadFuture;
        //start the session iframe
        messageSub = html.window.onMessage.listen(onMessageReceived);

        //send message to iframe
        await timerSub?.cancel();
        _logger.info('Starting periodic stream!');
        timerSub = Stream.periodic(
          request.interval,
          (computationCount) => computationCount,
        ).startWith(-1).listen((event) {
          final iframe = html.document.getElementById(iframeId);
          if (iframe is! html.HTMLIFrameElement) {
            return;
          }
          try {
            final cw = iframe.contentWindow;
            if (cw == null) {
              return;
            }
            const space = ' ';
            cw.postMessage(
              '${request.clientId}$space${request.sessionState}'.toJS,
              checkSessionIframe.origin.toJS,
            );
          } catch (e, st) {
            timerSub?.cancel();
            _logger.severe("Failed to send postMessage to OP's iframe", e, st);
          }
        });
      },
      onCancel: () {
        //stop the session iframe
        timerSub?.cancel();
        messageSub?.cancel();
        html.document.getElementById(iframeId)?.remove();
      },
      onPause: () {
        timerSub?.pause();
      },
      onResume: () {
        timerSub?.resume();
      },
    );
    return sc.stream;
  }
}
