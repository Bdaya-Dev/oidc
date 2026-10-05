import 'package:oidc_core/oidc_core.dart';

/// An event raised once per RP-initiated logout, after the manager has asked
/// the OP's `check_session_iframe` (OpenID Connect Session Management 1.0
/// §3.1) whether the session the RP just ended is still the OP's current
/// session.
///
/// ## When it is emitted
///
/// Only when ALL of these hold, so an app that never opted into Session
/// Management sees no change at all:
///
/// * [OidcSessionManagementSettings.enabled] is `true`,
/// * the OP's discovery document advertises a `check_session_iframe`, and
/// * the ended session had a `session_state` (the OP returned one in the
///   authorization response, Session Management 1.0 §2).
///
/// The probe starts when [OidcUserManagerBase.logout] (or a resumed web
/// `samePage` end-session redirect) receives the OP's end-session response,
/// and runs in the background: [OidcUserManagerBase.forgetUser] and the
/// `null` emission on [OidcUserManagerBase.userChanges] do NOT wait for it.
/// This event therefore usually arrives AFTER the user has already been
/// forgotten locally. On a resumed web `samePage` logout it is emitted during
/// [OidcUserManagerBase.init], so subscribe to
/// [OidcUserManagerBase.events] before calling `init()` to see it.
///
/// It is not emitted on platforms whose `monitorSessionStatus` never answers
/// (every non-web platform returns an empty stream), nor when the manager is
/// disposed, or a new session starts being monitored, before the probe
/// settles.
///
/// ## What each [outcome] means
///
/// RP-Initiated Logout 1.0 §2 lets the OP ask the End-User whether to log out
/// of the OP as well ("the OP SHOULD ask the End-User whether to log out of
/// the OP as well"), and the post-logout redirect alone does not tell the RP
/// which answer was given. The OP iframe is the only signal the RP has: per
/// Session Management 1.0 §3.2 it answers `changed` when the `session_state`
/// it is given no longer matches the OP's current one, and `unchanged` when
/// it still does.
///
/// Only `unchanged` is a reliable signal. `changed` is what a successful
/// logout produces, but it is produced in other cases too:
///
/// * §5.1: when the browser blocks third-party cookies or storage (Safari and
///   Firefox block or partition the OP iframe's cookies by default), "Cookie
///   based implementations might then return changed for every single call".
/// * §3.2: `changed` "might also occur as a result of changes to other
///   sessions between the User Agent and the OP. RPs need to be prepared for
///   either eventuality, silently handling any false positives".
/// * An End-User who already signed in again at the OP also reads as
///   `changed`: it means "different", not "no session".
///
/// Hence:
///
/// * [OidcEndSessionConfirmationOutcome.changed]: the expected answer after
///   a successful logout, but not proof of it.
/// * [OidcEndSessionConfirmationOutcome.unchanged]: the OP still considers
///   the ended session live, so the OP-side logout did not take -- e.g. the
///   End-User declined to log out of the OP. The RP's local logout still
///   happened.
/// * [OidcEndSessionConfirmationOutcome.error]: the OP iframe answered
///   `error` (or something outside the spec's three values), or the probe
///   itself failed.
/// * [OidcEndSessionConfirmationOutcome.timedOut]: no answer arrived within
///   [OidcSessionManagementSettings.endSessionConfirmationTimeout].
///
/// ## Why the manager does not react to it
///
/// Session Management 1.0 §3.1 says that "upon receipt of changed, the RP
/// MUST perform re-authentication with prompt=none to obtain the current
/// session state at the OP". That rule serves an RP that wants to keep an
/// active session in sync with the OP. After an RP-initiated logout the RP
/// has deliberately ended its session; a `prompt=none` request here would
/// silently sign the End-User back in if they still (or again) have an OP
/// session -- the opposite of what logout asked for. §3.1 itself treats this
/// case as done: "If the original End-User is already logged out at the RP
/// when the state changes indicate that End-User should be logged out, the
/// logout is considered to have succeeded." The manager therefore only
/// reports the outcome and leaves any follow-up (for example telling the
/// End-User they are still signed in at the OP on
/// [OidcEndSessionConfirmationOutcome.unchanged]) to the app.
///
/// ```dart
/// manager.events()
///     .whereType<OidcEndSessionConfirmationEvent>()
///     .listen((event) {
///   if (event.outcome == OidcEndSessionConfirmationOutcome.unchanged) {
///     // Signed out of this app, but still signed in at the OP.
///   }
/// });
/// ```
class OidcEndSessionConfirmationEvent extends OidcEvent {
  ///
  const OidcEndSessionConfirmationEvent({
    required this.outcome,
    required this.sessionState,
    required super.at,
    this.result,
    this.error,
    this.stackTrace,
    super.additionalInfo,
  });

  ///
  OidcEndSessionConfirmationEvent.now({
    required this.outcome,
    required this.sessionState,
    this.result,
    this.error,
    this.stackTrace,
    super.additionalInfo,
  }) : super.now();

  /// What the OP's `check_session_iframe` reported for [sessionState].
  final OidcEndSessionConfirmationOutcome outcome;

  /// The `session_state` of the session that was ended, i.e. the value the
  /// probe sent to the OP iframe.
  final String sessionState;

  /// The raw result the probe received, when one arrived (`null` for
  /// [OidcEndSessionConfirmationOutcome.timedOut] and for a failed probe).
  final OidcMonitorSessionResult? result;

  /// The error that made the probe fail, when
  /// [outcome] is [OidcEndSessionConfirmationOutcome.error] because of a
  /// thrown error rather than an OP `error` answer.
  final Object? error;

  /// The stack trace captured with [error], if any.
  final StackTrace? stackTrace;
}

/// The outcome reported by an [OidcEndSessionConfirmationEvent].
enum OidcEndSessionConfirmationOutcome {
  /// The OP iframe answered `changed`: the ended session is no longer the
  /// OP's current session as far as the iframe can tell. This is the
  /// expected answer after a successful logout, but not proof of it: a
  /// browser that blocks third-party cookies can make the iframe answer
  /// `changed` for every call (Session Management 1.0 §5.1), and changes to
  /// unrelated sessions can cause false positives (§3.2).
  changed,

  /// The OP iframe answered `unchanged`: the OP session is still alive, so
  /// the OP-side logout did not take effect (for example the End-User
  /// declined it, RP-Initiated Logout 1.0 §2). Unlike [changed], this is a
  /// reliable signal.
  unchanged,

  /// The OP iframe answered `error` or an unrecognized value, or the probe
  /// failed before an answer arrived.
  error,

  /// No answer arrived within
  /// [OidcSessionManagementSettings.endSessionConfirmationTimeout].
  timedOut,
}
