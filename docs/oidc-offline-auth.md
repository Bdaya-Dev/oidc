# Offline Authentication Guide

## Overview

Offline authentication allows your application to keep users authenticated even when the device cannot reach the authentication server. This is particularly useful for:

- Mobile applications with unreliable network connectivity
- Applications that need to work in areas with poor internet
- Providing a better user experience during temporary network outages
- Desktop applications that may lose network connectivity

## Enabling Offline Authentication

Offline authentication is **disabled by default** for security reasons. To enable it, set `supportOfflineAuth` to `true` in your `OidcUserManagerSettings`:

```dart
final manager = OidcUserManager.lazy(
  discoveryDocumentUri: OidcUtils.getOpenIdConfigWellKnownUri(
    Uri.parse('https://your-auth-server.com'),
  ),
  clientCredentials: const OidcClientAuthentication.none(
    clientId: 'your-client-id',
  ),
  store: OidcDefaultStore(),
  settings: OidcUserManagerSettings(
    redirectUri: Uri.parse('your-redirect-uri'),
    scope: ['openid', 'profile', 'email', 'offline_access'],
    supportOfflineAuth: true, // Enable offline authentication
  ),
);
```

### Tuning Refresh Timing

Two callbacks help you control when the manager refreshes tokens:

- `refreshBefore` decides how early to refresh **before** a token expires.
- `offlineRefreshRetryDelay` decides how long to wait **between retry attempts** while offline.

Both callbacks provide sensible defaults (refresh 1 minute before expiry and exponential backoff retries: 30s → 1m → 2m → 4m → 5m). Override them to match your UX:

```dart
settings: OidcUserManagerSettings(
  supportOfflineAuth: true,
  refreshBefore: (token) {
    // Refresh five minutes before expiry during normal operation
    return const Duration(minutes: 5);
  },
  offlineRefreshRetryDelay: (consecutiveFailures) {
    // Retry aggressively while offline: 15s, 30s, 45s, then cap at 1 minute
    final delay = Duration(seconds: 15 * consecutiveFailures);
    return delay > const Duration(minutes: 1)
        ? const Duration(minutes: 1)
        : delay;
  },
),
```

Shorter retry windows make the UI respond faster when connectivity returns; longer windows reduce battery and server load. Pick values that balance responsiveness and resource usage for your app.

## How Offline Authentication Works

### 1. Normal Authentication Flow

When network is available:

1. User authenticates with the identity provider
2. Tokens (ID token, access token, refresh token) are stored securely
3. Token metadata and userinfo are cached
4. Discovery document is cached for offline use

### 2. Offline Mode

When the server is unreachable:

1. The app attempts token refresh
2. If refresh fails due to network/server errors, offline mode activates
3. Cached tokens are used even if expired
4. User remains authenticated with cached data
5. An `OidcOfflineModeEnteredEvent` is emitted

### 3. Network Recovery

When connectivity is restored:

1. The app automatically attempts to refresh tokens
2. Tokens are validated with the server
3. User data is updated
4. An `OidcOfflineModeExitedEvent` is emitted

## Monitoring Offline Mode

### Listening to Events

Subscribe to offline mode events to update your UI:

```dart
manager.events().listen((event) {
  if (event is OidcOfflineModeEnteredEvent) {
    // Show offline indicator in UI
    print('Entered offline mode: ${event.reason}');
    print('Using cached token: ${event.currentToken != null}');
    
    // Show last sync time
    if (event.lastSuccessfulServerContact != null) {
      final timeSinceSync = DateTime.now().difference(event.lastSuccessfulServerContact!);
      print('Last synced: ${timeSinceSync.inMinutes} minutes ago');
    }
  } else if (event is OidcOfflineModeExitedEvent) {
    // Hide offline indicator
    print('Exited offline mode, network restored: ${event.networkRestored}');
    print('Synced at: ${event.lastSuccessfulServerContact}');
  } else if (event is OidcOfflineAuthWarningEvent) {
    // Show warning to user
    print('Offline auth warning: ${event.message}');
  }
});

// You can also check the last successful server contact at any time:
final lastSync = manager.lastSuccessfulServerContact;
if (lastSync != null) {
  print('Last successful server contact: $lastSync');
}
```

### Offline Mode Reasons

The `OfflineModeReason` enum indicates why offline mode was activated:

- `networkUnavailable` - Device has no internet connection
- `serverUnavailable` - Authentication server is down or unreachable
- `tokenRefreshFailed` - Token refresh failed due to network/server errors
- `discoveryDocumentUnavailable` - Cannot fetch discovery document
- `userInfoUnavailable` - UserInfo endpoint is offline

### Warning Types

The `OfflineAuthWarningType` enum provides security warnings:

- `usingExpiredToken` - App is using an expired token
- `extendedOfflineDuration` - User has been offline for an extended period
- `tokenValidationSkipped` - Cannot validate token with server
- `staleUserInfo` - User information may be outdated
- `repeatRefreshFailure` - Multiple refresh attempts have failed

## Error Handling

### Network vs Authentication Errors

The offline auth system distinguishes between different error types:

**Continue in Offline Mode (keepUser logged in):**
- Network unavailable (SocketException)
- Connection timeouts
- Server errors (5xx HTTP status codes)
- SSL/TLS errors

**Force Logout (authenticationErrors):**
- Invalid credentials (401, 403)
- Invalid grant or token
- Access denied
- Client errors (4xx HTTP status codes)

### Example Error Handling

```dart
try {
  await manager.loginAuthorizationCodeFlow();
} on OidcException catch (e) {
  if (e.errorResponse != null) {
    // Authentication error - user needs to re-authenticate
    print('Auth error: ${e.errorResponse!.error}');
  } else {
    // Network or other error - user may stay logged in with offline auth
    print('Error: ${e.message}');
  }
}
```

## Security Considerations

### ⚠️ Important Security Notes

1. **Token Expiration**: Expired tokens are accepted in offline mode, which could be a security risk
2. **No Server Validation**: Tokens cannot be validated with the identity provider
3. **Stale Data**: User information and permissions may be outdated
4. **Attack Vectors**: Offline mode may open unexpected security vulnerabilities

### Best Practices

#### 1. Implement Maximum Offline Duration

```dart
// Track when offline mode started
DateTime? offlineModeStart;

manager.events().listen((event) {
  if (event is OidcOfflineModeEnteredEvent) {
    offlineModeStart = event.at;
  } else if (event is OidcOfflineModeExitedEvent) {
    offlineModeStart = null;
  }
});

// Check offline duration periodically
Timer.periodic(Duration(hours: 1), (timer) {
  if (offlineModeStart != null) {
    final offlineDuration = DateTime.now().difference(offlineModeStart!);
    if (offlineDuration > Duration(days: 7)) {
      // Force re-authentication after 7 days offline
      await manager.forgetUser();
      // Navigate to login screen
    }
  }
});
```

#### 2. Show Clear Offline Indicators

Always inform users when they're using cached authentication:

```dart
Widget buildAuthStatus() {
  return StreamBuilder<OidcEvent>(
    stream: manager.events(),
    builder: (context, snapshot) {
      if (snapshot.data is OidcOfflineModeEnteredEvent) {
        return Banner(
          message: 'OFFLINE MODE',
          location: BannerLocation.topEnd,
          child: YourApp(),
        );
      }
      return YourApp();
    },
  );
}
```

#### 3. Limit Sensitive Operations

Restrict certain actions when in offline mode:

```dart
Future<void> performSensitiveOperation() async {
  final user = manager.currentUser;
  if (user == null) {
    throw Exception('Not authenticated');
  }

  // Check if token is expired
  if (user.token.isIdTokenExpired()) {
    // Try to refresh
    try {
      await manager.refreshToken();
    } catch (e) {
      // If refresh fails and we're using cached data, deny operation
      throw Exception('Cannot perform this operation while offline');
    }
  }

  // Proceed with operation
}
```

#### 4. Validate Tokens on Network Recovery

```dart
manager.events().listen((event) async {
  if (event is OidcOfflineModeExitedEvent) {
    // Network restored - validate token
    try {
      // This will refresh if needed
      await manager.refreshToken();
    } catch (e) {
      // Token is no longer valid - force re-authentication
      await manager.forgetUser();
    }
  }
});
```

#### 5. Use Refresh Tokens

Always request `offline_access` scope to get refresh tokens:

```dart
settings: OidcUserManagerSettings(
  scope: ['openid', 'profile', 'email', 'offline_access'],
  supportOfflineAuth: true,
),
```

## Testing Offline Scenarios

### Simulating Network Failures

For testing, you can simulate network failures:

```dart
// 1. Using mock HTTP client
final mockClient = MockClient((request) async {
  // Simulate network failure
  throw SocketException('Network unreachable');
});

final manager = OidcUserManager.lazy(
  httpClient: mockClient,
  // ... other settings
);

// 2. Disconnecting device
// - Enable airplane mode on device
// - Disable WiFi and mobile data
// - Use network link conditioner tools

// 3. Mocking server failures
final mockClient = MockClient((request) async {
  // Simulate server error
  return http.Response('Server Error', 503);
});
```

### Testing with Example App

The example app includes offline mode testing:

1. Enable offline auth in settings
2. Authenticate normally
3. Toggle "Simulate Offline Mode" switch
4. Observe offline behavior and events

## Troubleshooting

### User Gets Logged Out Despite Offline Auth Being Enabled

**Causes:**
- Authentication error (401, 403, invalid_grant) occurred
- Token was removed due to another error
- supportOfflineAuth was false when error occurred

**Solution:**
- Check error logs to identify the error type
- Ensure supportOfflineAuth is true before errors occur
- Handle authentication errors separately

### Offline Mode Not Activating

**Causes:**
- supportOfflineAuth is set to false
- Error is not network-related (e.g., 401)
- Discovery document was never cached

**Solution:**
- Verify supportOfflineAuth setting
- Ensure user successfully authenticated at least once
- Check network error types in logs

### Token Refresh Loops

**Causes:**
- Refresh token is expired
- Server repeatedly returns errors
- Network is unstable

**Solution:**
- Implement exponential backoff for refresh attempts
- Check refresh token expiration
- Monitor network stability

### Stale User Data

**Causes:**
- Extended offline duration
- UserInfo not being refreshed

**Solution:**
- Force re-authentication after extended offline period
- Update UI to show data staleness
- Attempt userinfo refresh when network returns

## API Reference

### Settings

```dart
class OidcUserManagerSettings {
  /// Whether to support offline authentication.
  /// When enabled, expired tokens will NOT be removed if the
  /// server can't be contacted.
  /// This parameter is disabled by default due to security concerns.
  final bool supportOfflineAuth;

  /// Controls the retry delay when automatic refresh attempts fail offline.
  /// Receives the number of consecutive failures and returns the
  /// delay before the next attempt. Defaults to exponential backoff.
  final OidcOfflineRefreshRetryDelayCallback offlineRefreshRetryDelay;
}
```

### Events

```dart
/// Emitted when entering offline mode
class OidcOfflineModeEnteredEvent extends OidcEvent {
  final OfflineModeReason reason;
  final OidcToken? currentToken;
  final DateTime? lastSuccessfulServerContact;
}

/// Emitted when exiting offline mode
class OidcOfflineModeExitedEvent extends OidcEvent {
  final bool networkRestored;
  final OidcToken? newToken;
  final DateTime? lastSuccessfulServerContact;
}

/// Emitted for security warnings
class OidcOfflineAuthWarningEvent extends OidcEvent {
  final OfflineAuthWarningType warningType;
  final String message;
  final Duration? tokenExpiredSince;
}
```

### Public API

```dart
class OidcUserManagerBase {
  /// Gets the last time the manager successfully communicated with the server.
  /// This can be useful for displaying "Last synced" information in the UI.
  /// Returns null if no successful server contact has been made yet.
  DateTime? get lastSuccessfulServerContact;
}
```

### Utility Methods

```dart
/// Check if error should allow offline mode
bool shouldContinueInOfflineMode({
  required Object error,
  required bool supportOfflineAuth,
});

/// Categorize error type
OfflineAuthErrorType categorizeError(Object error);
```

## Related Documentation

- [Authentication Flow](./oidc-usage.md)
- [Token Management](./oidc-usage-accesstoken.md)
- [Getting Started](./oidc-getting-started.md)
- [OidcUserManager API](./oidc_core.md)
