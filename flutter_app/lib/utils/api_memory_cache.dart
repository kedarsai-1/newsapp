/// Short-lived in-memory cache for idempotent GET responses (per app session).
class ApiMemoryCache {
  ApiMemoryCache._();

  static final Map<String, _Entry> _store = {};

  static T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  static void set<T>(String key, T value, Duration ttl) {
    _store[key] = _Entry(value, DateTime.now().add(ttl));
  }

  static void invalidatePrefix(String prefix) {
    final keys = _store.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      _store.remove(k);
    }
  }

  static void clear() => _store.clear();
}

class _Entry {
  _Entry(this.value, this.expiresAt);
  final Object? value;
  final DateTime expiresAt;
}
