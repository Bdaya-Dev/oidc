import 'dart:async';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:oidc_core/oidc_core.dart';

class OidcTokenEventsManager {
  OidcTokenEventsManager({
    this.getExpiringNotificationTime,
  });

  @visibleForTesting
  static final logger = Logger('Oidc.TokenEventsManager');

  Timer? _expiringTimer;
  Timer? _expiredTimer;

  final Duration? Function(OidcToken token)? getExpiringNotificationTime;

  final _expiringController = StreamController<OidcToken>.broadcast();
  final _expiredController = StreamController<OidcToken>.broadcast();

  Stream<OidcToken> get expiring => _expiringController.stream;
  Stream<OidcToken> get expired => _expiredController.stream;

  void load(OidcToken token) {
    //first, remove any previous timers.
    unload();
    logger.finest('Loading token started');
    //calculate a new expires_in based on the current time.
    final expiresInFromNow = token.calculateExpiresInFromNow();
    if (expiresInFromNow == null) {
      logger.finest('expiresInFromNow is null, no timer will be started.');
      // there is no way to determine when will it expire.
      return;
    }

    // Schedule expiring notification if enabled.
    final expiringNotificationTime = getExpiringNotificationTime?.call(token);
    if (expiringNotificationTime == null) {
      logger.finest(
        'expiringNotificationTime is null, expiring notifications are disabled.',
      );
    } else {
      // #123: clamp the effective notification lead to at most HALF the token's
      // total lifetime. A configured lead that is larger than (or close to) the
      // token lifetime would otherwise place the expiring instant at or before
      // "now" for a freshly-issued token, firing 'expiring' immediately →
      // refresh → new (equally short) token → immediate re-fire = a tight
      // infinite refresh loop. Clamping to half-life guarantees the timer is
      // strictly in the future for a live token, bounding refreshes to at most
      // once per half-life. The synchronous fire path is removed entirely: the
      // event is always delivered from a timer, never during load().
      final totalLifetime = token.expiresIn;
      var effectiveNotificationTime = expiringNotificationTime;
      if (totalLifetime != null) {
        final halfLifetime = totalLifetime ~/ 2;
        if (halfLifetime < effectiveNotificationTime) {
          effectiveNotificationTime = halfLifetime;
        }
      }
      final timeUntilExpiring = expiresInFromNow - effectiveNotificationTime;
      // Never fire synchronously during load. If the (clamped) instant is
      // already in the past — e.g. a cached token loaded near expiry — schedule
      // at zero delay so it is delivered on the next event-loop turn instead.
      final expiringDelay = timeUntilExpiring.isNegative
          ? Duration.zero
          : timeUntilExpiring;
      logger.finest(
        'started a timer that will raise the expiring event '
        'after: $expiringDelay',
      );
      _expiringTimer = Timer(expiringDelay, () {
        logger.finest('raising expiring event.');
        if (!_expiringController.isClosed) {
          _expiringController.add(token);
        }
      });
    }

    if (expiresInFromNow.isNegative) {
      //already expired.
      //there is no need to run a timer for a token that's already expired.
      logger.finest('loaded token has already expired, raised expired event.');
      if (!_expiredController.isClosed) {
        _expiredController.add(token);
      }
    } else {
      logger.finest(
        'started a timer that will raise the expired event '
        'after: $expiresInFromNow',
      );
      _expiredTimer = Timer(expiresInFromNow, () {
        logger.finest('raising expired event.');
        if (!_expiredController.isClosed) {
          _expiredController.add(token);
        }
      });
    }
  }

  void unload() {
    logger.finest('Unloading timers.');
    _expiredTimer?.cancel();
    _expiringTimer?.cancel();
    _expiredTimer = null;
    _expiringTimer = null;
  }

  Future<void> dispose() async {
    unload();
    await Future.wait([
      _expiredController.close(),
      _expiringController.close(),
    ]);
  }
}
