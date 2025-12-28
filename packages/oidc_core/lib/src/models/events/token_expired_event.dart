import 'package:oidc_core/oidc_core.dart';

/// An event that gets raised after a token expired.
class OidcTokenExpiredEvent extends OidcEvent {
  ///
  const OidcTokenExpiredEvent({
    required this.currentToken,
    required super.at,
    super.additionalInfo,
  });

  ///
  OidcTokenExpiredEvent.now({
    required this.currentToken,
    super.additionalInfo,
  }) : super.now();

  /// The current token that is expired.
  final OidcToken currentToken;
}
