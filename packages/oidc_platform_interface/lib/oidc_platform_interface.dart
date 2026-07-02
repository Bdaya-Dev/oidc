export 'src/native_channel_constants.dart';
export 'src/native_events.dart';
// The Pigeon-generated native transport (host APIs + event stream). This is the
// compiler-enforced channel contract the native plugins implement; exported so
// the federated implementations (oidc_android / oidc_darwin) and
// consumers have visibility into the native layer.
export 'src/oidc_native.g.dart'
    show OidcAndroidHostApi, OidcAppleHostApi, streamNativeEvents;
export 'src/platform.dart';
