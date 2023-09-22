class OidcMonitorSessionStatusRequest {
  const OidcMonitorSessionStatusRequest({
    required this.clientId,
    required this.sessionState,
    required this.interval,
  });

  final String clientId;
  final String sessionState;
  final Duration interval;
}
