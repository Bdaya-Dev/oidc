//cspell: disable
import 'dart:async';
import 'dart:js_interop';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web/web.dart';

/// {@template oidc_web_core}
/// Core web package for oidc
/// {@endtemplate}
class OidcWebCore {
  /// {@macro oidc_web_core}
  const OidcWebCore();

  String _calculatePopupOptions(OidcPlatformSpecificOptions_Web options) {
    final h = options.popupHeight;
    final w = options.popupWidth;
    //  html.window.screen.available.top;
    final top = (window.outerHeight - h) / 2 + (window.screenTop);
    final left = (window.outerWidth - w) / 2 + (window.screenLeft);

    final windowOpts =
        'width=$w,height=$h,toolbar=no,location=no,directories=no,status=no,menubar=no,copyhistory=no&top=$top,left=$left';
    return windowOpts;
  }

  static const _webWindowKey = 'web_window';

  HTMLElement _getBody() => window.document.body!;

  HTMLIFrameElement _createHiddenIframe({
    required String iframeId,
    bool appendToDocument = true,
  }) {
    final prev = window.document.getElementById(iframeId);
    if (prev != null) {
      prev.remove();
    }
    final res = (window.document.createElement('iframe') as HTMLIFrameElement)
      ..id = iframeId
      ..width = '0'
      ..height = '0'
      ..hidden = true.toJS
      ..style.visibility = 'hidden'
      ..style.position = 'fixed'
      ..style.left = '-1000px'
      ..style.top = '0';
    if (appendToDocument) {
      _getBody().append(res);
    }
    return res;
  }

  Future<Uri?> _getResponseUri({
    required OidcPlatformSpecificOptions_Web options,
    required Uri uri,
    required String? state,
    required Map<String, dynamic> preparationResult,
  }) async {
    final channel = BroadcastChannel(options.broadcastChannel);
    final c = Completer<Uri>();

    void eventFunction(MessageEvent event) {
      final data = event.data;
      if (data is! JSString) {
        return;
      }
      final parsed = Uri.tryParse(data.toDart);
      if (parsed == null) {
        return;
      }

      if (state != null) {
        final (
          :parameters,
          responseMode: _,
        ) = OidcEndpoints.resolveAuthorizeResponseParameters(
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
    }

    channel.onmessage = eventFunction.toJS;
    final preparedWindow = preparationResult[_webWindowKey] as Window?;
    try {
      //first prepare
      switch (options.navigationMode) {
        case OidcPlatformSpecificOptions_Web_NavigationMode.samePage:
          //
          window.location.assign(uri.toString());
          // return null, since this mode can't be awaited.
          return null;
        case OidcPlatformSpecificOptions_Web_NavigationMode.newPage:
        case OidcPlatformSpecificOptions_Web_NavigationMode.popup:
          //
          if (preparedWindow == null) {
            throw const OidcException(
              'please prepare the window in $_webWindowKey parameter first.',
            );
          }
          preparedWindow.location.replace(uri.toString());
          //listen to response uri.
          final res = await c.future;
          if (!preparedWindow.closed) {
            preparedWindow.close();
          }
          return res;

        case OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame:
          const iframeId = 'oidc-redirect-iframe';
          final iframe = _createHiddenIframe(iframeId: iframeId);
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
      channel.close();
    }
  }

  Window? _prepareWindow(OidcPlatformSpecificOptions_Web options) {
    return switch (options.navigationMode) {
      OidcPlatformSpecificOptions_Web_NavigationMode.newPage => window.open(
        '',
        '_blank',
      ),
      OidcPlatformSpecificOptions_Web_NavigationMode.popup => window.open(
        '',
        'oidc_auth_popup',
        _calculatePopupOptions(options),
      ),
      _ => null,
    };
  }

  /// prepares the window for the given navigation mode
  Map<String, dynamic> prepareForRedirectFlow(
    OidcPlatformSpecificOptions_Web options,
  ) {
    final prepared = _prepareWindow(options);
    return {if (prepared != null) _webWindowKey: prepared};
  }

  /// Returns the authorization response.
  /// may throw an [OidcException].
  Future<OidcAuthorizeResponse?> getAuthorizationResponse(
    OidcProviderMetadata metadata,
    OidcAuthorizeRequest request,
    OidcPlatformSpecificOptions_Web options,
    Map<String, dynamic> preparationResult,
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
    if (options.navigationMode ==
            OidcPlatformSpecificOptions_Web_NavigationMode.hiddenIFrame &&
        !isNonePrompt) {
      throw const OidcException(
        'hidden iframe can only be used with "none" prompt, '
        'since it prohibits user interaction',
      );
    }
    final respUri = await _getResponseUri(
      options: options,
      uri: request.generateUri(endpoint),
      state: request.state,
      preparationResult: preparationResult,
    );
    if (respUri == null) {
      return null;
    }
    return OidcEndpoints.parseAuthorizeResponse(
      responseUri: respUri,
      responseMode: request.responseMode,
    );
  }

  /// Returns the end session response for an RP initiated logout request.
  /// may throw an [OidcException].
  Future<OidcEndSessionResponse?> getEndSessionResponse(
    OidcProviderMetadata metadata,
    OidcEndSessionRequest request,
    OidcPlatformSpecificOptions_Web options,
    Map<String, dynamic> preparationResult,
  ) async {
    final endpoint = metadata.endSessionEndpoint;
    if (endpoint == null) {
      throw const OidcException(
        "The OpenId Provider doesn't provide '${OidcConstants_ProviderMetadata.endSessionEndpoint}'.",
      );
    }

    final respUri = await _getResponseUri(
      options: options,
      uri: request.generateUri(endpoint),
      state: request.state,
      preparationResult: preparationResult,
    );
    if (respUri == null) {
      return null;
    }
    return OidcEndSessionResponse.fromJson(respUri.queryParameters);
  }

  /// Listens to incoming front channel logout requests.
  /// returns an empty stream on non-supported platforms.
  Stream<OidcFrontChannelLogoutIncomingRequest>
  listenToFrontChannelLogoutRequests(
    Uri listenOn,
    OidcFrontChannelRequestListeningOptions_Web options,
  ) {
    final logger = Logger(
      'Oidc.OidcWebCore.listenToFrontChannelLogoutRequests',
    );
    final channel = BroadcastChannel(options.broadcastChannel);
    StreamController<OidcFrontChannelLogoutIncomingRequest>? streamController;

    void eventHandler(MessageEvent event) {
      final sc = streamController;
      if (sc == null) {
        //ignore received messages if the user hasn't started listening yet.
        return;
      }

      final dataJs = event.data;
      if (dataJs is! JSString) {
        logger.finer('Received non-string data: $dataJs');
        return;
      }

      final data = dataJs.toDart;
      final uri = Uri.tryParse(data);
      if (uri == null) {
        logger.finer('Failed to parse data into uri: $data');
        return;
      }

      if (listenOn.pathSegments.isNotEmpty) {
        logger.finer(
          'listenOn has a path segment (${listenOn.path}), checking if it matches the input data.',
        );
        const eq = IterableEquality<String>();

        if (!eq.equals(uri.pathSegments, listenOn.pathSegments)) {
          logger.finer(
            'listenOn has a different path segment (${listenOn.path}), than data (${uri.path}), '
            'skipping the event.',
          );
          // the paths don't match
          return;
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
          return;
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
          return;
        }
      }
      logger.fine('successfully matched data ($uri)');
      sc.add(
        OidcFrontChannelLogoutIncomingRequest.fromJson(uri.queryParameters),
      );
    }

    streamController = StreamController<OidcFrontChannelLogoutIncomingRequest>(
      onListen: () {
        channel.onmessage = eventHandler.toJS;
      },
      onCancel: () {
        channel.close();
      },
    );

    return streamController.stream;
  }

  /// starts monitoring the session status.
  Stream<OidcMonitorSessionResult> monitorSessionStatus({
    required Uri checkSessionIframe,
    required OidcMonitorSessionStatusRequest request,
  }) {
    final logger = Logger('Oidc.OidcWebCore.monitorSessionStatus');

    StreamController<OidcMonitorSessionResult>? sc;
    StreamSubscription<int>? timerSub;
    StreamSubscription<MessageEvent>? messageSub;
    // Timer? timer;

    const iframeId = 'oidc-session-management-iframe';
    void onMessageReceived(MessageEvent event) {
      final streamController = sc;
      final iframe = document.getElementById(iframeId) as HTMLIFrameElement?;
      final eventOrigin = event.origin;
      if (iframe == null ||
          streamController == null ||
          eventOrigin != checkSessionIframe.origin) {
        logger.warning(
          'ignoring received message; '
          'iframe is null ? ${iframe == null}; '
          'streamController is null ? ${streamController == null}; '
          'eventOrigin is: ($eventOrigin), should be equal to: (${checkSessionIframe.origin}).',
        );
        return;
      }
      final eventDataJs = event.data;
      if (eventDataJs is! JSString) {
        logger.warning(
          'Received iframe message was not a string: $eventDataJs',
        );
        return;
      }
      final eventData = eventDataJs.toDart;
      switch (eventData) {
        case 'error':
          logger.warning('Received error iframe message');
          streamController.add(const OidcErrorMonitorSessionResult());
        case 'changed':
          logger.fine('Received changed iframe message');
          streamController.add(
            const OidcValidMonitorSessionResult(changed: true),
          );
        case 'unchanged':
          logger.fine('Received unchanged iframe message');
          streamController.add(
            const OidcValidMonitorSessionResult(changed: false),
          );
        default:
          logger.warning('Received unknown iframe message: $eventData');
          streamController.add(
            OidcUnknownMonitorSessionResult(data: eventData),
          );
      }
    }

    sc = StreamController<OidcMonitorSessionResult>(
      onListen: () async {
        final iframe =
            _createHiddenIframe(appendToDocument: false, iframeId: iframeId)
              ..id = iframeId
              ..src = checkSessionIframe.toString();
        final onloadFuture = iframe.onLoad.first;
        _getBody().append(iframe);
        await onloadFuture;
        //start the session iframe
        messageSub = window.onMessage.listen(onMessageReceived);

        //send message to iframe
        await timerSub?.cancel();
        logger.info('Starting periodic stream!');
        timerSub =
            Stream.periodic(
              request.interval,
              (computationCount) => computationCount,
            ).startWith(-1).listen((_) {
              final iframe = document.getElementById(iframeId);
              if (iframe is! HTMLIFrameElement) {
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
                logger.severe(
                  "Failed to send postMessage to OP's iframe",
                  e,
                  st,
                );
              }
            });
      },
      onCancel: () {
        //stop the session iframe
        timerSub?.cancel();
        messageSub?.cancel();
        document.getElementById(iframeId)?.remove();
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
