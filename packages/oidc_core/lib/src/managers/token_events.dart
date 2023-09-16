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
    final expiringNotificationTime = getExpiringNotificationTime?.call(token);
    if (expiringNotificationTime == null) {
      logger.finest(
        'expiringNotificationTime is null, no timer will be started.',
      );
      return;
    }
    if (expiresInFromNow < expiringNotificationTime) {
      //going to expire.
      logger.finest(
        'loaded token was already expiring, raised expiring event.',
      );
      _expiringController.add(token);
    } else {
      final timeUntilExpiring = expiresInFromNow - expiringNotificationTime;
      logger.finest(
        'started a timer that will raise the expiring event '
        'after: $timeUntilExpiring',
      );
      //start a timer that will fire the expiring controller.
      _expiringTimer = Timer(timeUntilExpiring, () {
        logger.finest('raising expiring event.');
        _expiringController.add(token);
      });
    }
    if (expiresInFromNow.isNegative) {
      //already expired.
      //there is no need to run a timer for a token that's already expired.
      logger.finest('loaded token has already expired, raised expired event.');
      _expiredController.add(token);
    } else {
      logger.finest(
        'started a timer that will raise the expired event '
        'after: $expiresInFromNow',
      );
      _expiredTimer = Timer(expiresInFromNow, () {
        logger.finest('raising expired event.');
        _expiredController.add(token);
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
