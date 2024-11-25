import 'package:oidc_core/oidc_core.dart';

/// An event that gets raised before a token expires.
class OidcTokenExpiringEvent extends OidcEvent {
  ///
  const OidcTokenExpiringEvent({
    required this.currentToken,
    required super.at,
  });

  ///
  OidcTokenExpiringEvent.now({
    required this.currentToken,
  }) : super.now();

  /// The current token that is expiring.
  final OidcToken currentToken;
}
