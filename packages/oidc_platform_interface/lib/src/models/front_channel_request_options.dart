// ignore_for_file: camel_case_types

///
class OidcFrontChannelRequestListeningOptions {
  ///
  const OidcFrontChannelRequestListeningOptions({
    this.web = const OidcFrontChannelRequestListeningOptions_Web(),
  });

  /// web options
  final OidcFrontChannelRequestListeningOptions_Web web;
}

///
class OidcFrontChannelRequestListeningOptions_Web {
  ///
  const OidcFrontChannelRequestListeningOptions_Web({
    this.broadcastChannel = defaultBroadcastChannel,
  });

  /// `oidc_flutter_web/request`
  static const defaultBroadcastChannel = 'oidc_flutter_web/request';

  /// The broadcast channel to use when receiving messages from the browser.
  ///
  /// defaults to [defaultBroadcastChannel].
  final String broadcastChannel;
}
