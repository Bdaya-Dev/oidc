This is a federated plugin split into the following main packages:

- [oidc](oidc-getting-started.md): Ready to use flutter plugin that conforms to the OIDC spec. ([pub.dev](https://pub.dev/packages/oidc))
- [oidc_core](oidc_core.md): Pure dart package that contains models and helpers for implementing the OIDC spec. ([pub.dev](https://pub.dev/packages/oidc_core))
- [oidc_web_core](oidc_web_core.md): Pure dart package based on [package:web](https://pub.dev/packages/web) which allows. ([pub.dev](https://pub.dev/packages/oidc_web_core))
- [oidc_default_store](oidc_default_store.md): An implementation of `OidcStore` that uses [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) and [shared_preferences](https://pub.dev/packages/shared_preferences). ([pub.dev](https://pub.dev/packages/oidc_default_store))
- [oidc_loopback_listener](oidc_loopback_listener.md): A pure dart package that creates a simple http server. ([pub.dev](https://pub.dev/packages/oidc_loopback_listener))

And the following internal packages:

- [oidc_platform_interface](https://pub.dev/packages/oidc_platform_interface): common interface that needs to be implemented in a platform.

- [oidc_android](https://pub.dev/packages/oidc_android): Android  implementation.
- [oidc_ios](https://pub.dev/packages/oidc_ios): ios implementation.
- [oidc_macos](https://pub.dev/packages/oidc_macos): macos implementation.
- [oidc_flutter_appauth](https://pub.dev/packages/oidc_flutter_appauth): Base Implementation connecting packages with [flutter_appauth](https://pub.dev/packages/flutter_appauth), to use the [AppAuth SDK](https://appauth.io/), used in android, ios, macos.

- [oidc_web](https://pub.dev/packages/oidc_web): Web implementation.

- [oidc_windows](https://pub.dev/packages/oidc_windows): windows implementation.
- [oidc_linux](https://pub.dev/packages/oidc_linux): Linux implementation.

- [oidc_desktop](https://pub.dev/packages/oidc_desktop): base package for desktop implementation, used by windows and linux, this relies on `oidc_loopback_listener` to host a server on a random port, and receive redirect responses via the server.