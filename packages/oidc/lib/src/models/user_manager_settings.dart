///
class UserManagerSettings {
  ///
  const UserManagerSettings({
    required this.redirectUri,
  });

  /// The `redirect_uri` to use in the authorization code flow.
  final Uri redirectUri;
}
