import 'package:clock/clock.dart';

/// Represents an arbitrary event.
abstract class OidcEvent {
  ///
  const OidcEvent({
    required this.at,
  });

  /// Creates an event whose [at] is now.
  OidcEvent.now() : at = clock.now();

  /// when the event occurred.
  final DateTime at;
}
