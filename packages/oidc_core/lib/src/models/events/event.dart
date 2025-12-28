import 'package:clock/clock.dart';

/// Represents an arbitrary event.
abstract class OidcEvent {
  ///
  const OidcEvent({
    required this.at,
    this.additionalInfo,
  });

  /// Creates an event whose [at] is now.
  OidcEvent.now({Map<String, dynamic>? additionalInfo})
    : at = clock.now(),
      additionalInfo = additionalInfo ?? {};

  /// when the event occurred.
  final DateTime at;

  final Map<String, dynamic>? additionalInfo;
}
