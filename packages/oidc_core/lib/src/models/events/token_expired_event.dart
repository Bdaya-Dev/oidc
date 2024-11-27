import 'package:oidc_core/oidc_core.dart';

/// An event that gets raised after a token expired.
class OidcTokenExpiredEvent extends OidcEvent {
  ///
  const OidcTokenExpiredEvent({
    required this.currentToken,
    required super.at,
  });

  ///
  OidcTokenExpiredEvent.now({
    required this.currentToken,
  }) : super.now();

  /// The current token that is expired.
  final OidcToken currentToken;
}
