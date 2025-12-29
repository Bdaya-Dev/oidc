# package:oidc_cli

`oidc_cli` is a small, provider-agnostic command-line tool for authenticating against an OpenID Connect (OIDC) provider.

It is primarily intended for **local development** and **scripting**, and it uses a local loopback redirect for interactive login.

## Where to find it

- Package docs and usage: `packages/oidc_cli/README.md`
- Source: `packages/oidc_cli/`

## Common commands

- Show help: `oidc --help`
- Interactive login: `oidc login interactive --issuer <issuer> --client-id <clientId> [options]`
- Show status: `oidc status`
- Print access token: `oidc token get`
- Refresh token: `oidc token refresh`
- Logout / clear session: `oidc logout`

## Pub proxy

`oidc_cli` also includes proxy commands to run `dart pub ...` / `flutter pub ...` while ensuring a hosted pub token is configured:

- `oidc dart pub get`
- `oidc flutter pub get`

## Store location

The CLI persists config/session state in a JSON store file.

- Override per-invocation: `oidc --store <path> ...`
- Or via env var: `OIDC_CLI_STORE`
