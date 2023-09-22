// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:html';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:oidc_core/oidc_core.dart';

/// This class represents an iframe that listens to session status changes.
class OidcCheckSessionIFrame {
  ///
  OidcCheckSessionIFrame({
    required this.url,
    required this.clientId,
    required this.interval,
  }) {
    //source: https://github.com/authts/oidc-client-ts/blob/main/src/CheckSessionIFrame.ts#L9
  }

  IFrameElement? _iframe;

  /// The logger
  @visibleForTesting
  static final logger = Logger('Oidc.OidcCheckSessionIFrame');

  /// the check_session_iframe url.
  final Uri url;

  /// the client id.
  final String clientId;

  /// the polling interval.
  final Duration interval;

  Timer? _timer;

  String? _sessionState;

  late final _sc = StreamController<OidcMonitorSessionResult>(
    onListen: _load,
    onCancel: _unload,
    onPause: _pause,
    onResume: _resume,
  );

  /// A stream of session results.
  ///
  /// listening to this stream loads the iframe, and starts listening to user status.
  /// this stream supports only a single subscriber.
  ///
  /// if you want multiple subscribers, consider calling .asBroadcastStream()
  Stream<OidcMonitorSessionResult> changedStream() => _sc.stream;

  void _load() {
    final res =
        _iframe = (window.document.createElement('iframe') as IFrameElement)
          ..width = '0'
          ..height = '0'
          ..src = url.toString()
          ..style.visibility = 'hidden'
          ..style.position = 'fixed'
          ..style.left = '-1000px'
          ..style.top = '0';
    final onLoadFuture = res.onLoad.first;
    final body = window.document.getElementsByTagName('body').first;
    body.append(res);
    window.addEventListener('message', _messageReceived, false);
    onLoadFuture.then((value) {});
  }

  void _unload() async {
    _iframe?.remove();
    _iframe = null;
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  void _resume() {}

  void _messageReceived(Event event) {
    if (event is! MessageEvent) {
      return;
    }
    final data = event.data;
    if (data is! String) {
      return;
    }

    if (event.origin == url.origin && event.source == _iframe?.contentWindow) {
      if (event.data == 'error') {
        logger.severe('error message from check session op iframe');
        _sc.add(const OidcErrorMonitorSessionResult());
      } else if (event.data == 'changed') {
        logger.fine('changed message from check session op iframe');
        _sc.add(const OidcValidMonitorSessionResult(changed: true));
      } else if (event.data == 'unchanged') {
        logger.fine('unchanged message from check session op iframe');
        _sc.add(const OidcValidMonitorSessionResult(changed: false));
      } else {
        logger.fine('message from check session op iframe: $data');
        _sc.add(OidcUnknownMonitorSessionResult(data: data));
      }
    }
  }

  // source: https://github.com/authts/oidc-client-ts/blob/da45d0829f947aec1a88be53bf188a993dc15797/src/CheckSessionIFrame.ts#L81-L93
  /// Sets the current session_state to a new value.
  void setSessionState(String sessionState) {
    //
    if (_sessionState == sessionState) {
      return;
    }

    logger.info('called setSessionState with state $sessionState');

    void send() {
      final iframeContentWindow = _iframe?.contentWindow;
      final sessionState = _sessionState;
      if (iframeContentWindow == null || sessionState == null) {
        return;
      }
      const space = ' ';
      iframeContentWindow.postMessage(
        clientId + space + sessionState,
        url.origin,
      );
    }

    // trigger now
    send();
    _timer = Timer.periodic(interval, (_) => send());
  }
}
