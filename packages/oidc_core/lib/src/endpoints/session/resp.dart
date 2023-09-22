final class OidcMonitorSessionResult {
  const OidcMonitorSessionResult();

  bool isError() => this is OidcErrorMonitorSessionResult;

  bool isValidResult() => this is OidcValidMonitorSessionResult;

  bool isChanged() =>
      isValidResult() && (this as OidcValidMonitorSessionResult).changed;

  String? getUnknownResult() {
    final t = this;
    return t is OidcUnknownMonitorSessionResult ? t.data : null;
  }
}

final class OidcErrorMonitorSessionResult extends OidcMonitorSessionResult {
  const OidcErrorMonitorSessionResult();
}

final class OidcValidMonitorSessionResult extends OidcMonitorSessionResult {
  const OidcValidMonitorSessionResult({
    required this.changed,
  });

  final bool changed;
}

final class OidcUnknownMonitorSessionResult extends OidcMonitorSessionResult {
  const OidcUnknownMonitorSessionResult({
    required this.data,
  });

  final String data;
}
