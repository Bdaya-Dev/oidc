
# [![package:oidc_cli][package_image]][package_link]

`oidc_cli` is a small provider-agnostic CLI for authenticating against an OpenID Connect (OIDC) provider.

It’s meant for local development and scripting.

## Install

From pub.dev:

```bash title="Install from pub.dev"
dart pub global activate oidc_cli
```

From this repo:

```bash title="Activate from this repo"
dart run melos run oidc:activate
```

```bash title="Activate directly (path)"
dart pub global activate --source path packages/oidc_cli
```

The executable is:

- `oidc`

## Quickstart

```bash title="Login → status → token → logout"
oidc login interactive --issuer https://issuer.example.com --client-id your-client-id
oidc status
oidc token get
oidc logout
```

## Configuration

### Global options

| Option | Meaning |
| --- | --- |
| `--version`, `-v` | Print version and exit. |
| `--[no-]verbose` | Verbose logging. |
| `--store <path>` | Use a specific store file. |

### Store override

| Mechanism | Notes |
| --- | --- |
| `--store <path>` | Highest priority. |
| `OIDC_CLI_STORE` | Used when `--store` isn’t set. |
| default | `~/.oidc_cli/store.json` |

## Commands

### `login`

Logs in and persists provider configuration (issuer/client/scopes/etc.) to the store.

#### `login interactive`

Authorization Code flow with a local loopback redirect.

```bash title="Interactive login"
oidc login interactive --issuer <issuer> --client-id <clientId> [options]
```

| Option | Required | Default | Notes |
| --- | --- | --- | --- |
| `--issuer`, `-i` | yes |  | Issuer URL. |
| `--client-id`, `-c` | yes |  | Client ID. |
| `--client-secret`, `-s` | no |  | Client secret. |
| `--scopes`, `-S` | no | `openid profile email offline_access` | Space-separated scopes. |
| `--redirect-port`, `-p` | no | `3000` | Loopback listener port. |
| `--[no-]auto-refresh` | no | enabled | Refresh if expiring soon. |
| `--add-to-dart-pub <hostedUrl>` | no |  | Runs `dart pub token add` after login. |

??? tip "If the browser doesn’t open"
  The CLI prints a URL; copy/paste it into a browser.

#### `login password`

Resource Owner Password Credentials grant.

```bash title="Password login"
oidc login password --username <username> --password <password> [options]
```

!!! warning "Provider support varies"
  Many providers disable this grant. Prefer `login interactive` or `login device`.

| Option | Required | Default | Notes |
| --- | --- | --- | --- |
| `--username`, `-u` | yes |  | Username. |
| `--password` | yes |  | Password. |
| `--issuer`, `-i` | no | (saved) | Falls back to `config.issuer`. |
| `--client-id`, `-c` | no | (saved) | Falls back to `config.clientId`. |
| `--client-secret`, `-s` | no | (saved) | Falls back to `config.clientSecret`. |
| `--scopes`, `-S` | no | `openid profile email offline_access` | Space-separated scopes. |
| `--redirect-port`, `-p` | no | `3000` | Saved for future interactive logins; not used here. |
| `--[no-]auto-refresh` | no | enabled | Refresh if expiring soon. |
| `--add-to-dart-pub <hostedUrl>` | no |  | Runs `dart pub token add` after login. |

#### `login device`

Device Authorization Grant (`device_code`).

```bash title="Device login"
oidc login device [options]
```

| Option | Required | Default | Notes |
| --- | --- | --- | --- |
| `--issuer`, `-i` | no | (saved) | Falls back to `config.issuer`. |
| `--client-id`, `-c` | no | (saved) | Falls back to `config.clientId`. |
| `--client-secret`, `-s` | no |  | Client secret. |
| `--scopes`, `-S` | no | `openid profile email offline_access` | Space-separated scopes. |
| `--add-to-dart-pub <hostedUrl>` | no |  | Runs `dart pub token add` after login. |

### `token`

#### `token get`

Print the access token (refreshes if expiring soon).

```bash title="Get token"
oidc token get [--no-auto-refresh]
```

| Option | Default | Notes |
| --- | --- | --- |
| `--[no-]auto-refresh` | enabled | Refresh if expiring soon. |

#### `token refresh`

Force a refresh and print the new access token.

```bash title="Refresh token"
oidc token refresh
```

### `status`

```bash title="Show current status"
oidc status
```

### `logout`

```bash title="Logout"
oidc logout
```

??? note "What logout does"
  It attempts token revocation when possible, then clears the local session.

### `dart` / `flutter` (pub proxy)

Proxy `dart pub ...` / `flutter pub ...` while keeping a hosted pub token up-to-date.

```bash title="Proxy pub commands"
oidc dart pub <args...>
oidc flutter pub <args...>
```

| Option | Default | Notes |
| --- | --- | --- |
| `--hosted-url <url>` | (saved) | Overrides saved `config.hostedUrl`. |
| `--[no-]auto-refresh` | enabled | Refresh token before using it for pub. |

??? note "No surprises"
  If the proxied args are explicitly `pub token add`, the proxy won’t inject a token.

???+ note "Less common commands"
  **`discovery`** (print discovery JSON)

  ```bash
  oidc discovery [--issuer <issuer> | --well-known <uri>]
  ```

  **`store-path`** (print resolved store path)

  ```bash
  oidc store-path
  ```

  **`update`** (update the CLI)

  ```bash
  oidc update
  ```

  **`completion`** (shell completion)

  ```bash
  oidc completion --help
  ```

## Output (for scripts)

??? info "Token output"
  - `oidc token get`, `oidc token refresh`, and `oidc login device` print the raw token.
  - `oidc login interactive` and `oidc login password` print `Access Token: ...`.

## Store & security

!!! warning "Treat the store like a password"
  The store is a plain JSON file and may contain refresh tokens.

## Troubleshooting

!!! tip "Common fixes"
  - Browser didn’t open automatically: copy/paste the printed URL.
  - Redirect rejected: ensure `http://localhost:<port>` is allowed/registered by your provider.
  - “No active session”: make sure you’re using the same store (`--store` / `OIDC_CLI_STORE`).

---

[package_link]: https://pub.dev/packages/oidc_cli
[package_image]: https://img.shields.io/badge/package-oidc__cli-0175C2?logo=dart&logoColor=white
