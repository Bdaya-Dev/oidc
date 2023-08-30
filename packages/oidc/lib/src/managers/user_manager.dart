import 'dart:async';

import 'package:oidc_core/oidc_core.dart';

/// This class manages a single user's authentication status.
///
/// It's preferred to maintain only a single instance of this class.
class UserManager {
  /// Create a new UserManager.
  UserManager({
    required this.discoveryDocumentUri,
    required this.client,
  });

  final _userStatusStreamController = StreamController<Object>.broadcast();

  /// The discovery document containing openid configuration.
  final Uri discoveryDocumentUri;

  /// The client authentication information.
  final OidcClientAuthentication client;

  ///Initializes the user manager
  Future<void> init() async {
    //
  }

  /// Disposes the resources used by this class.
  Future<void> dispose() async {
    await _userStatusStreamController.close();
  }
}
