# oidc_cli

A small provider-agnostic CLI for authenticating against an OpenID Connect (OIDC) provider using the Authorization Code flow with a local loopback redirect.

This is primarily intended for local development and scripting.

## Install / activate

From the repo root:

- Activate locally via Melos:
	- `dart run melos run oidc:activate`
- Or activate directly:
	- `dart pub global activate --source path packages/oidc_cli`

After activation, the executable is available as:

- `oidc`

To see all commands:

- `oidc --help`

## Global options

These options apply to all commands.

- `--version`: Print the current CLI version.
- `--[no-]verbose`: Enable verbose logging (includes shell commands executed).

- `--store <path>`: Override the path to the local JSON store file.
	- Useful if you want multiple isolated sessions/configs.
	- Example: `oidc --store ./my-store.json status`

Environment fallback:

- `OIDC_CLI_STORE`: If set (and `--store` is not provided), the CLI uses this path for the JSON store.
	- Precedence: `--store` > `OIDC_CLI_STORE` > default (`~/.oidc_cli/store.json`).
	- Example (PowerShell): `$env:OIDC_CLI_STORE = "$PWD\oidc-store.json"; oidc status`

## Quickstart

1) Log in:

```bash
oidc login interactive \
	--issuer https://issuer.example.com \
	--client-id your-client-id \
	--scopes "openid profile email offline_access" \
	--redirect-port 3000
```

If you want to use a custom store location:

```bash
oidc --store ./oidc-store.json login interactive \
	--issuer https://issuer.example.com \
	--client-id your-client-id
```

2) Check status:

```bash
oidc status
```

3) Print the access token (auto-refresh if expiring soon):

```bash
oidc token get
```

4) Log out (revokes tokens when possible and clears the local session):

```bash
oidc logout
```

## Commands

### `login`

Log in to an OIDC provider.

```bash
oidc login interactive --issuer <issuer> --client-id <clientId> [options]
```

Options:

- `--issuer`, `-i` (required): Issuer URI.
- `--client-id`, `-c` (required): Client ID.
- `--client-secret`, `-s` (optional): Client secret.
- `--scopes`, `-S` (optional, default: `openid profile email offline_access`): Space-separated scopes.
- `--redirect-port`, `-p` (optional, default: `3000`): Local port for the loopback redirect.
- `--[no-]auto-refresh` (optional, default: enabled): If enabled, refreshes the token after login when it is expired/expiring soon.
- `--add-to-dart-pub <hostedUrl>` (optional): After login, runs `dart pub token add <hostedUrl>` and pipes the access token to it.

Notes:

- The CLI starts a local HTTP listener and prints an authorization URL.
- It attempts to open your default browser (`rundll32` on Windows, `open` on macOS, `xdg-open` on Linux). If that fails, copy/paste the printed URL manually.
- The redirect URI used is `http://localhost:<port>`.
	- If you pass `--redirect-port 0`, the OS will choose a free port. Some providers require exact redirect URI registration; verify what your provider allows.
- On success, `login` prints `Access Token: ...` to stdout.
- If the token is already expired (or expiring soon), the CLI attempts a refresh before printing/using it (unless `--no-auto-refresh` is set).

### `login password`

Log in using the Resource Owner Password Credentials grant.

```bash
oidc login password \
	--issuer <issuer> \
	--client-id <clientId> \
	--username <username> \
	--password <password>
```

### `login device`

Request an access token using the OAuth 2.0 Device Authorization Grant.

```bash
oidc login device \
	--issuer <issuer> \
	--client-id <clientId>
```

### `token`

Token-related commands.

```bash
oidc token <subcommand>
```

### `token get`

Print the current access token, refreshing it if needed.

```bash
oidc token get [--no-auto-refresh]
```

Options:

- `--[no-]auto-refresh` (optional, default: enabled): If enabled, refreshes the token automatically when it is expired/expiring soon.

Output:

- Prints the raw access token to stdout.

### `token refresh`

Force a token refresh and print the refreshed access token.

```bash
oidc token refresh
```

## Pub proxy commands

These commands forward to `dart pub ...` / `flutter pub ...` and (when a `hostedUrl` is available) ensure `dart pub token add <hostedUrl>` is up-to-date.

By default, the proxy uses the current stored OIDC session token (same one used by `oidc token get`).

Examples:

```bash
oidc dart pub get
```

```bash
oidc flutter pub get
```

### Passing OIDC parameters to the proxy

The proxy reads configuration from the CLI store (`config.issuer`, `config.clientId`, `config.clientSecret`, `config.scopes`, `config.hostedUrl`).

- To use a different store/session: use the global `--store <path>` option (or `OIDC_CLI_STORE`).
- To override the hosted URL without changing your saved config: use `--hosted-url <url>`.

### `status`

Show current login status.

```bash
oidc status
```

Output:

- Prints whether you are logged in.
- If available, prints `email` (otherwise `sub`) and token expiry time.

### `logout`

Log out and clear the stored session.

```bash
oidc logout
```

Behavior:

- Attempts token revocation (refresh token then access token).
- Clears local OIDC session/token data.
- Keeps your saved CLI configuration (so you can log in again without re-typing issuer/client-id).

If remote logout/revocation fails (for example, the provider does not support the relevant endpoints), the command prints a warning and still clears the local session.

### `store-path`

Print the absolute path to the local JSON store file.

```bash
oidc store-path
```

### `discovery`

Fetch and print the OIDC discovery document (provider metadata).

```bash
oidc discovery --issuer <issuer>
```

You can also pass the full well-known URL:

```bash
oidc discovery --well-known <url>
```

## Token storage (JSON)

The CLI uses a plaintext JSON file on disk.

Default location:

- macOS/Linux: `~/.oidc_cli/store.json`
- Windows: `%USERPROFILE%\.oidc_cli\store.json`

If neither `HOME` nor `USERPROFILE` are set, the CLI falls back to the current working directory (`./.oidc_cli/store.json`).

You can always check the resolved path via:

```bash
oidc store-path
```

### Schema

The file is a single JSON object.

- `config` (object): persisted configuration saved by `login`.
	- `issuer`: string
	- `clientId`: string
	- `clientSecret`: string|null
	- `scopes`: array of strings
	- `port`: number
	- `hostedUrl`: string (only if `--add-to-dart-pub` was provided)

All OIDC runtime/session entries are stored as additional top-level keys with a `<namespace>/<key>` format.

Token-related keys are typically under the `secureTokens` namespace, for example:

- `secureTokens/currentToken`: a JSON *string* containing the token payload
- `secureTokens/userInfo`: a JSON *string* containing user info claims
- `secureTokens/userAttributes`: a JSON *string* containing additional user attributes

### Security notes

- Tokens are stored in plaintext on disk. Treat the store file as sensitive.
- `login` prints the access token to stdout; avoid running it where logs/terminal history are collected.

## Troubleshooting

- Browser doesn’t open: copy the printed URL and open it manually.
- Port already in use: change `--redirect-port`.
- Redirect URI mismatch errors: ensure `http://localhost:<port>` is registered/allowed by your provider.
- `No active session`: run `oidc login` first (or verify your store config exists).