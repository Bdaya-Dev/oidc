/// Initializes web-only shims on non-web platforms.
///
/// This is a no-op stub used by conditional imports.
void initWeb() {}

/// In-memory storage used as a stub for Web Storage APIs.
class Storage {
  final Map<String, String> _storage = <String, String>{};

  /// Reads a value by key.
  String? getItem(String key) => _storage[key];

  /// Writes a value by key.
  void setItem(String key, String value) {
    _storage[key] = value;
  }

  /// Removes a value by key.
  void removeItem(String key) {
    _storage.remove(key);
  }
}

/// Stub window object exposing local/session storage.
class Window {
  /// Creates a stub window with local and session storage.
  Window()
      : localStorage = Storage(),
        sessionStorage = Storage();

  /// Stub local storage.
  final Storage localStorage;

  /// Stub session storage.
  final Storage sessionStorage;
}

/// Stub window instance for non-web platforms.
final window = Window();
