class Storage {
  final Map<String, String> _storage = <String, String>{};

  String? getItem(String key) => _storage[key];

  void setItem(String key, String value) {
    _storage[key] = value;
  }

  void removeItem(String key) {
    _storage.remove(key);
  }
}

class Window {
  Window()
      : localStorage = Storage(),
        sessionStorage = Storage();

  final Storage localStorage;
  final Storage sessionStorage;
}

final window = Window();
